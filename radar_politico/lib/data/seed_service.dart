import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import 'database.dart';

/// Carrega o conteúdo de assets/data/*.json no banco local.
/// Executa na primeira abertura e sempre que [AppInfo.versaoConteudo] mudar.
/// Apenas tabelas de conteúdo são recriadas; dados do usuário permanecem.
class SeedService {
  final AppDatabase database;
  final AssetBundle bundle;
  SeedService(this.database, {AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  Future<Map<String, dynamic>> _json(String nome) async =>
      jsonDecode(await bundle.loadString('assets/data/$nome.json')) as Map<String, dynamic>;

  Future<bool> precisaCarregar() async {
    final db = await database.db;
    final r = await db.query('meta', where: 'chave = ?', whereArgs: ['versao_conteudo']);
    return r.isEmpty || r.first['valor'] != '${AppInfo.versaoConteudo}';
  }

  Future<void> carregarSeNecessario() async {
    if (await precisaCarregar()) await carregar();
  }

  Future<void> carregar() async {
    final db = await database.db;
    final eixos = await _json('eixos');
    final testes = await _json('testes');
    final quiz = await _json('quiz');
    final cands = await _json('candidatos');
    final gov = await _json('governo');

    await db.transaction((txn) async {
      for (final t in const [
        'alternativas', 'perguntas', 'testes', 'eixos', 'perguntas_quiz', 'quizzes',
        'candidato_fontes', 'candidato_eixos', 'posicionamentos_candidatos', 'candidatos',
        'promessas', 'acoes_governamentais', 'fontes', 'status_correcoes'
      ]) {
        await txn.delete(t);
      }

      for (final e in eixos['eixos'] as List) {
        await txn.insert('eixos', {
          'id': e['id'], 'nome': e['nome'], 'polo_a': e['poloA'], 'polo_b': e['poloB'],
          'descricao': e['descricao'], 'esquerda_direita': e['esquerdaDireita'],
        });
      }

      var ordem = 0;
      for (final t in testes['testes'] as List) {
        await txn.insert('testes', {
          'id': t['id'], 'titulo': t['titulo'], 'descricao': t['descricao'], 'explicacao': t['explicacao'],
          'icone': t['icone'], 'tempo_min': t['tempoMin'], 'rapido': t['rapido'] == true ? 1 : 0, 'ordem': ordem++,
        });
        var po = 0;
        for (final p in t['perguntas'] as List) {
          await txn.insert('perguntas', {'id': p['id'], 'teste_id': t['id'], 'ordem': po++, 'texto': p['texto'], 'tema': p['tema']});
          var ao = 0;
          for (final a in p['alternativas'] as List) {
            await txn.insert('alternativas', {
              'pergunta_id': p['id'], 'letra': a['letra'], 'texto': a['texto'], 'ordem': ao++,
              'pontuacao_json': jsonEncode(a['pontuacao']),
            });
          }
        }
      }

      for (final q in quiz['quizzes'] as List) {
        await txn.insert('quizzes', {'id': q['id'], 'titulo': q['titulo']});
      }
      for (final q in quiz['perguntas'] as List) {
        await txn.insert('perguntas_quiz', {
          'id': q['id'], 'quiz_id': q['tema'], 'nivel': q['nivel'], 'pergunta': q['pergunta'],
          'alternativas_json': jsonEncode(q['alternativas']), 'correta': q['correta'],
          'explicacao': q['explicacao'], 'fonte': q['fonte'],
        });
      }

      Future<int> fonte(String titulo, String? url) async {
        final ex = await txn.query('fontes', where: 'titulo = ? AND url IS ?', whereArgs: [titulo, url]);
        if (ex.isNotEmpty) return ex.first['id'] as int;
        return txn.insert('fontes', {'titulo': titulo, 'url': url});
      }

      var co = 0;
      const tipos = {
        'posicoes': 'posicao', 'propostas': 'proposta', 'votos': 'voto', 'projetos': 'projeto',
        'declaracoes': 'declaracao', 'promessas': 'promessa', 'acoes': 'acao',
      };
      for (final c in cands['candidatos'] as List) {
        await txn.insert('candidatos', {
          'id': c['id'], 'nome': c['nome'], 'cargo': c['cargo'], 'partido': c['partido'], 'uf': c['uf'],
          'resumo': c['resumo'], 'base_eixos': c['baseEixos'], 'aviso': c['aviso'],
          'atualizado_em': c['atualizadoEm'], 'ordem': co++,
        });
        for (final entry in tipos.entries) {
          var o = 0;
          for (final it in (c[entry.key] as List? ?? [])) {
            await txn.insert('posicionamentos_candidatos', {
              'candidato_id': c['id'], 'tipo': entry.value, 'texto': it['texto'], 'fonte': it['fonte'],
              'data': it['data'], 'em_revisao': it['emRevisao'] == true ? 1 : 0, 'ordem': o++,
            });
          }
        }
        for (final e in (c['eixos'] as Map).entries) {
          await txn.insert('candidato_eixos', {'candidato_id': c['id'], 'eixo_id': e.key, 'valor': e.value});
        }
        for (final f in (c['fontes'] as List? ?? [])) {
          final fid = await fonte(f['texto'], f['fonte']);
          await txn.insert('candidato_fontes', {'candidato_id': c['id'], 'fonte_id': fid},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      var go = 0;
      for (final g in gov['itens'] as List) {
        final fid = await fonte(g['fonte'], g['url']);
        final base = {
          'id': g['id'], 'tema': g['tema'], 'status': g['status'], 'titulo': g['titulo'], 'descricao': g['descricao'],
          'fonte_id': fid, 'data': g['data'], 'impacto': g['impacto'], 'em_revisao': g['emRevisao'] == true ? 1 : 0,
          'ordem': go++,
        };
        if (g['categoria'] == 'promessa') {
          await txn.insert('promessas', base);
        } else {
          await txn.insert('acoes_governamentais', {...base, 'categoria': g['categoria']});
        }
      }

      for (final s in ClassificacaoCorrecao.rotulos.entries) {
        await txn.insert('status_correcoes', {'id': s.key, 'nome': s.value});
      }

      await txn.insert('meta', {'chave': 'versao_conteudo', 'valor': '${AppInfo.versaoConteudo}'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('meta', {'chave': 'aviso_candidatos', 'valor': cands['avisoGeral']},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('meta', {'chave': 'aviso_governo', 'valor': gov['aviso']},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('meta', {'chave': 'titulo_governo', 'valor': gov['governo']},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
