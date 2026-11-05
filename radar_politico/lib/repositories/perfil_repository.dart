import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/database.dart';
import '../models/resultado.dart';

class PerfilSalvo {
  final DateTime atualizadoEm;
  final Map<String, EixoScore> eixos;
  final double? indiceGeral;
  final String classificacao;
  final String rotulo;
  const PerfilSalvo(this.atualizadoEm, this.eixos, this.indiceGeral, this.classificacao, this.rotulo);

  Map<String, double> get pcts => eixos.map((k, v) => MapEntry(k, v.pct));
}

class PerfilRepository {
  final AppDatabase database;
  PerfilRepository(this.database);

  Future<void> salvar(String usuarioId, Map<String, EixoScore> eixos, double? indice, String classe, String rotulo) async {
    final db = await database.db;
    await db.insert('perfil_politico', {
      'usuario_id': usuarioId,
      'atualizado_em': DateTime.now().toIso8601String(),
      'eixos_json': jsonEncode(eixos.values.map((e) => e.toJson()).toList()),
      'indice_geral': indice,
      'classificacao': classe,
      'rotulo': rotulo,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PerfilSalvo?> carregar(String usuarioId) async {
    final db = await database.db;
    final r = await db.query('perfil_politico', where: 'usuario_id = ?', whereArgs: [usuarioId]);
    if (r.isEmpty) return null;
    final row = r.first;
    return PerfilSalvo(
      DateTime.parse(row['atualizado_em'] as String),
      {
        for (final e in jsonDecode(row['eixos_json'] as String) as List)
          e['eixo'] as String: EixoScore.fromJson(e as Map<String, dynamic>)
      },
      (row['indice_geral'] as num?)?.toDouble(),
      (row['classificacao'] as String?) ?? '',
      (row['rotulo'] as String?) ?? '',
    );
  }

  Future<void> excluir(String usuarioId) async {
    final db = await database.db;
    await db.delete('perfil_politico', where: 'usuario_id = ?', whereArgs: [usuarioId]);
  }
}
