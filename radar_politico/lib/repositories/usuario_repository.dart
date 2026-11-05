import 'package:sqflite/sqflite.dart';

import '../data/database.dart';
import '../models/conteudo.dart';

class UsuarioRepository {
  final AppDatabase database;
  UsuarioRepository(this.database);

  Future<void> salvar(Usuario u) async {
    final db = await database.db;
    await db.insert('usuarios', {
      'id': u.id, 'nome': u.nome, 'email': u.email, 'tipo': u.tipo, 'foto_url': u.fotoUrl,
      'criado_em': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.update('usuarios', {'nome': u.nome, 'email': u.email, 'foto_url': u.fotoUrl}, where: 'id = ?', whereArgs: [u.id]);
  }

  Future<Usuario?> buscar(String id) async {
    final db = await database.db;
    final r = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
    if (r.isEmpty) return null;
    final m = r.first;
    return Usuario(id: m['id'] as String, nome: m['nome'] as String, email: m['email'] as String?,
        tipo: m['tipo'] as String, fotoUrl: m['foto_url'] as String?);
  }

  Future<void> iniciarSessao(String usuarioId, String provedor) async {
    final db = await database.db;
    await db.insert('sessoes', {'usuario_id': usuarioId, 'provedor': provedor, 'inicio': DateTime.now().toIso8601String()});
  }

  Future<void> encerrarSessoes(String usuarioId) async {
    final db = await database.db;
    await db.update('sessoes', {'fim': DateTime.now().toIso8601String()},
        where: 'usuario_id = ? AND fim IS NULL', whereArgs: [usuarioId]);
  }

  /// Vincula ao usuário logado os dados criados como visitante.
  Future<int> migrarDadosVisitante(String paraId) async {
    final db = await database.db;
    var n = 0;
    await db.transaction((txn) async {
      for (final t in const ['respostas', 'resultados', 'respostas_quiz', 'pontuacoes', 'correcoes']) {
        n += await txn.rawUpdate('UPDATE OR IGNORE $t SET usuario_id = ? WHERE usuario_id = ?', [paraId, 'visitante']);
      }
      await txn.delete('perfil_politico', where: 'usuario_id = ?', whereArgs: ['visitante']);
    });
    return n;
  }

  Future<void> apagarDados(String usuarioId) async {
    final db = await database.db;
    await db.transaction((txn) async {
      for (final t in const ['respostas', 'resultados', 'respostas_quiz', 'pontuacoes', 'correcoes', 'perfil_politico', 'sessoes']) {
        await txn.delete(t, where: 'usuario_id = ?', whereArgs: [usuarioId]);
      }
    });
  }
}
