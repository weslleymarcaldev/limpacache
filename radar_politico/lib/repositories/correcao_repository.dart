import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/database.dart';
import '../models/conteudo.dart';

class CorrecaoRepository {
  final AppDatabase database;
  CorrecaoRepository(this.database);

  Future<int> criar(String usuarioId, Correcao c) async {
    final db = await database.db;
    final agora = DateTime.now().toIso8601String();
    return db.insert('correcoes', {
      'usuario_id': usuarioId, 'conteudo_tipo': c.conteudoTipo, 'conteudo_id': c.conteudoId,
      'conteudo_trecho': c.trecho, 'motivo': c.motivo, 'fonte_usuario': c.fonteUsuario, 'status_id': c.status,
      'criado_em': agora, 'atualizado_em': agora,
    });
  }

  Future<void> atualizarAnalise(int id, {
    required String status,
    required String classificacao,
    required String resposta,
    required String justificativa,
    required Map<String, dynamic> analise,
    required bool viaIa,
  }) async {
    final db = await database.db;
    await db.update('correcoes', {
      'status_id': status, 'classificacao': classificacao, 'resposta_ia': resposta, 'justificativa': justificativa,
      'analise_json': jsonEncode(analise), 'via_ia': viaIa ? 1 : 0, 'atualizado_em': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Correcao>> listar(String usuarioId) async {
    final db = await database.db;
    final rows = await db.query('correcoes', where: 'usuario_id = ?', whereArgs: [usuarioId], orderBy: 'criado_em DESC');
    return rows.map(Correcao.fromDb).toList();
  }

  Future<void> sinalizar(String tipo, String id, String nota, {int? correcaoId}) async {
    final db = await database.db;
    final agora = DateTime.now().toIso8601String();
    await db.insert('conteudo_revisao', {'conteudo_tipo': tipo, 'conteudo_id': id, 'nota': nota, 'criado_em': agora},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('historico_alteracoes', {
      'conteudo_tipo': tipo, 'conteudo_id': id, 'descricao': nota, 'correcao_id': correcaoId, 'criado_em': agora,
    });
  }

  Future<Map<String, String>> sinalizacoes() async {
    final db = await database.db;
    final rows = await db.query('conteudo_revisao');
    return {for (final r in rows) '${r['conteudo_tipo']}:${r['conteudo_id']}': r['nota'] as String};
  }

  Future<List<Map<String, Object?>>> historico({int limite = 50}) async {
    final db = await database.db;
    return db.query('historico_alteracoes', orderBy: 'criado_em DESC', limit: limite);
  }
}
