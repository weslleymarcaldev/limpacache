import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radar_politico/data/database.dart';
import 'package:radar_politico/data/seed_service.dart';
import 'package:radar_politico/repositories/conteudo_repository.dart';
import 'package:radar_politico/repositories/teste_repository.dart';
import 'package:radar_politico/repositories/usuario_repository.dart';
import 'package:radar_politico/services/scoring_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ArquivoBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  sqfliteFfiInit();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase();
    await db.usar(await databaseFactoryFfi.openDatabase(inMemoryDatabasePath));
    await SeedService(db, bundle: _ArquivoBundle()).carregar();
  });

  tearDown(() async => (await db.db).close());

  test('seed popula todas as tabelas de conteúdo', () async {
    final d = await db.db;
    Future<int> n(String t) async => (await d.rawQuery('SELECT COUNT(*) c FROM $t')).first['c'] as int;
    expect(await n('testes'), 7);
    expect(await n('eixos'), 8);
    expect(await n('perguntas'), greaterThan(70));
    expect(await n('alternativas'), greaterThan(280));
    expect(await n('perguntas_quiz'), greaterThanOrEqualTo(100));
    expect(await n('candidatos'), greaterThanOrEqualTo(10));
    expect(await n('posicionamentos_candidatos'), greaterThan(50));
    expect(await n('promessas') + await n('acoes_governamentais'), greaterThanOrEqualTo(30));
    expect(await n('fontes'), greaterThan(10));
    expect(await n('status_correcoes'), 6);
  });

  test('fluxo: rascunho -> resultado -> migração visitante para conta', () async {
    final repo = TesteRepository(db);
    final t = (await repo.testes()).firstWhere((t) => t.rapido);
    for (final p in t.perguntas) {
      await repo.salvarResposta('visitante', t.id, p.id, 'B');
    }
    final rasc = await repo.rascunho('visitante', t.id);
    expect(rasc.length, t.perguntas.length);
    final r = const ScoringService().calcular(t, rasc, await repo.eixos());
    await repo.salvarResultado('visitante', r);
    await repo.descartarRascunho('visitante', t.id);
    expect(await repo.rascunho('visitante', t.id), isEmpty);
    final lidos = await repo.resultados('visitante');
    expect(lidos.single.eixos.keys, containsAll(r.eixos.keys));
    expect(lidos.single.indiceGeral, closeTo(r.indiceGeral!, 1e-9));

    await UsuarioRepository(db).migrarDadosVisitante('google:123');
    expect(await repo.resultados('visitante'), isEmpty);
    expect((await repo.resultados('google:123')).length, 1);
  });

  test('repositório de conteúdo monta candidatos e governo', () async {
    final c = ConteudoRepository(db);
    final cs = await c.candidatos();
    expect(cs.first.eixos.length, 8);
    expect(cs.first.itens['posicao'], isNotEmpty);
    final g = await c.governo();
    expect(g.where((i) => i.categoria == 'promessa'), isNotEmpty);
    expect(g.every((i) => i.fonte.isNotEmpty), isTrue);
    expect((await c.perguntasQuiz(nivel: 'dificil')).length, greaterThan(20));
  });
}
