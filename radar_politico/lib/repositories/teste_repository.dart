import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../data/database.dart';
import '../models/eixo.dart';
import '../models/resultado.dart';
import '../models/teste.dart';

class TesteRepository {
  final AppDatabase database;
  TesteRepository(this.database);

  Map<String, Eixo>? _eixosCache;
  List<TesteModel>? _testesCache;

  void limparCache() {
    _eixosCache = null;
    _testesCache = null;
  }

  Future<Map<String, Eixo>> eixos() async {
    if (_eixosCache != null) return _eixosCache!;
    final db = await database.db;
    final rows = await db.query('eixos');
    return _eixosCache = {for (final r in rows) r['id'] as String: Eixo.fromJson(Map<String, dynamic>.from(r))};
  }

  Future<List<TesteModel>> testes() async {
    if (_testesCache != null) return _testesCache!;
    final db = await database.db;
    final ts = await db.query('testes', orderBy: 'ordem');
    final ps = await db.query('perguntas', orderBy: 'teste_id, ordem');
    final as = await db.query('alternativas', orderBy: 'pergunta_id, ordem');
    final altPorPergunta = <String, List<Alternativa>>{};
    for (final a in as) {
      altPorPergunta.putIfAbsent(a['pergunta_id'] as String, () => []).add(Alternativa(
            letra: a['letra'] as String,
            texto: a['texto'] as String,
            pontuacao: Alternativa.fromJson({'letra': '', 'texto': '', 'pontuacao': jsonDecode(a['pontuacao_json'] as String)}).pontuacao,
          ));
    }
    final pergPorTeste = <String, List<Pergunta>>{};
    for (final p in ps) {
      pergPorTeste.putIfAbsent(p['teste_id'] as String, () => []).add(Pergunta(
            id: p['id'] as String,
            texto: p['texto'] as String,
            tema: p['tema'] as String?,
            alternativas: altPorPergunta[p['id']] ?? [],
          ));
    }
    return _testesCache = ts
        .map((t) => TesteModel(
              id: t['id'] as String,
              titulo: t['titulo'] as String,
              descricao: t['descricao'] as String,
              explicacao: t['explicacao'] as String,
              icone: (t['icone'] as String?) ?? 'quiz',
              tempoMin: (t['tempo_min'] as int?) ?? 5,
              rapido: t['rapido'] == 1,
              perguntas: pergPorTeste[t['id']] ?? [],
            ))
        .toList();
  }

  Future<TesteModel?> teste(String id) async {
    for (final t in await testes()) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ---- salvamento automático de respostas
  Future<Map<String, String>> rascunho(String usuarioId, String testeId) async {
    final db = await database.db;
    final rows = await db.query('respostas', where: 'usuario_id = ? AND teste_id = ?', whereArgs: [usuarioId, testeId]);
    return {for (final r in rows) r['pergunta_id'] as String: r['letra'] as String};
  }

  Future<void> salvarResposta(String usuarioId, String testeId, String perguntaId, String letra) async {
    final db = await database.db;
    await db.insert('respostas', {
      'usuario_id': usuarioId, 'teste_id': testeId, 'pergunta_id': perguntaId, 'letra': letra,
      'atualizado_em': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> descartarRascunho(String usuarioId, String testeId) async {
    final db = await database.db;
    await db.delete('respostas', where: 'usuario_id = ? AND teste_id = ?', whereArgs: [usuarioId, testeId]);
  }

  Future<Set<String>> testesEmAndamento(String usuarioId) async {
    final db = await database.db;
    final rows = await db.rawQuery('SELECT DISTINCT teste_id FROM respostas WHERE usuario_id = ?', [usuarioId]);
    return rows.map((r) => r['teste_id'] as String).toSet();
  }

  // ---- resultados
  Future<int> salvarResultado(String usuarioId, ResultadoTeste r) async {
    final db = await database.db;
    return db.insert('resultados', r.toDb(usuarioId));
  }

  Future<List<ResultadoTeste>> resultados(String usuarioId, {String? testeId, int? limite}) async {
    final db = await database.db;
    final rows = await db.query('resultados',
        where: testeId == null ? 'usuario_id = ?' : 'usuario_id = ? AND teste_id = ?',
        whereArgs: testeId == null ? [usuarioId] : [usuarioId, testeId],
        orderBy: 'criado_em DESC',
        limit: limite);
    return rows.map(ResultadoTeste.fromDb).toList();
  }

  Future<Map<String, ResultadoTeste>> ultimosPorTeste(String usuarioId) async {
    final todos = await resultados(usuarioId);
    final out = <String, ResultadoTeste>{};
    for (final r in todos) {
      out.putIfAbsent(r.testeId, () => r);
    }
    return out;
  }

  Future<void> excluirResultado(int id) async {
    final db = await database.db;
    await db.delete('resultados', where: 'id = ?', whereArgs: [id]);
  }
}
