import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:radar_politico/core/neutralidade.dart';

/// Testes editoriais: quantidade mínima de conteúdo e regras de imparcialidade.
void main() {
  Map<String, dynamic> j(String n) => jsonDecode(File('assets/data/$n.json').readAsStringSync()) as Map<String, dynamic>;
  final quiz = j('quiz');
  final cands = j('candidatos');
  final gov = j('governo');
  final testes = j('testes');

  test('quiz: ao menos 100 perguntas, 4 alternativas, 1 correta, 3 níveis, explicação e fonte', () {
    final ps = quiz['perguntas'] as List;
    expect(ps.length, greaterThanOrEqualTo(100));
    final niveis = <String>{};
    final ids = <String>{};
    for (final p in ps) {
      expect((p['alternativas'] as List).length, 4, reason: p['id']);
      expect((p['alternativas'] as List).toSet().length, 4, reason: 'alternativas repetidas em ${p['id']}');
      expect(p['correta'], inInclusiveRange(0, 3));
      expect((p['explicacao'] as String).isNotEmpty, isTrue);
      expect((p['fonte'] as String).isNotEmpty, isTrue);
      niveis.add(p['nivel']);
      expect(ids.add(p['id']), isTrue);
    }
    expect(niveis, {'facil', 'medio', 'dificil'});
  });

  test('candidatos: ao menos 10, com estrutura completa e eixos 0-100', () {
    final cs = cands['candidatos'] as List;
    expect(cs.length, greaterThanOrEqualTo(10));
    for (final c in cs) {
      for (final k in ['nome', 'cargo', 'partido', 'resumo', 'baseEixos']) {
        expect((c[k] as String).isNotEmpty, isTrue, reason: '${c['id']}.$k');
      }
      expect((c['posicoes'] as List).isNotEmpty, isTrue, reason: c['id']);
      expect((c['eixos'] as Map).length, 8, reason: c['id']);
      for (final v in (c['eixos'] as Map).values) {
        expect(v, inInclusiveRange(0, 100));
      }
    }
  });

  test('governo: ao menos 30 itens, com fonte, data e todos os status', () {
    final it = gov['itens'] as List;
    expect(it.length, greaterThanOrEqualTo(30));
    final status = it.map((i) => i['status']).toSet();
    expect(status, containsAll(['cumprida', 'parcialmente_cumprida', 'em_andamento', 'nao_cumprida']));
    for (final i in it) {
      for (final k in ['titulo', 'descricao', 'fonte', 'data', 'impacto', 'tema', 'categoria']) {
        expect((i[k] as String).isNotEmpty, isTrue, reason: '${i['id']}.$k');
      }
    }
  });

  test('nenhum conteúdo usa rótulos pejorativos, recomendação de voto ou adjetivos valorativos', () {
    final tudo = [jsonEncode(quiz), jsonEncode(cands), jsonEncode(gov), jsonEncode(testes)].join('\n');
    expect(Neutralidade.encontrarTermos(tudo, Neutralidade.termosProibidos), isEmpty);
    expect(Neutralidade.encontrarTermos(tudo, Neutralidade.recomendacoesProibidas), isEmpty);
    expect(Neutralidade.encontrarTermos(tudo, Neutralidade.adjetivosValorativos), isEmpty);
  });

  test('o código-fonte das telas não contém expressões proibidas', () {
    final src = Directory('lib/screens').listSync().whereType<File>().map((f) => f.readAsStringSync()).join('\n');
    expect(Neutralidade.encontrarTermos(src, Neutralidade.recomendacoesProibidas), isEmpty);
    expect(Neutralidade.encontrarTermos(src, Neutralidade.termosProibidos), isEmpty);
  });
}
