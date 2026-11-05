import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:radar_politico/models/eixo.dart';
import 'package:radar_politico/models/teste.dart';
import 'package:radar_politico/services/scoring_service.dart';

void main() {
  final eixosJson = jsonDecode(File('assets/data/eixos.json').readAsStringSync()) as Map<String, dynamic>;
  final testesJson = jsonDecode(File('assets/data/testes.json').readAsStringSync()) as Map<String, dynamic>;
  final defs = {for (final e in eixosJson['eixos'] as List) e['id'] as String: Eixo.fromJson(e)};
  final testes = (testesJson['testes'] as List).map((t) => TesteModel.fromJson(t)).toList();
  const sc = ScoringService();

  Map<String, String> todasLetra(TesteModel t, String l) => {for (final p in t.perguntas) p.id: l};

  /// Responde sempre na direção do polo indicado para o eixo principal da pergunta.
  Map<String, String> polo(TesteModel t, String alvo) => {
        for (final p in t.perguntas)
          p.id: p.alternativas
              .reduce((a, b) {
                final pa = a.pontuacao.values.first.pontos;
                final pb = b.pontuacao.values.first.pontos;
                return alvo == 'A' ? (pa <= pb ? a : b) : (pa >= pb ? a : b);
              })
              .letra
      };

  test('existem 7 testes, cada um com 10 a 20 perguntas de 4 alternativas', () {
    expect(testes.length, greaterThanOrEqualTo(7));
    for (final t in testes) {
      expect(t.perguntas.length, inInclusiveRange(10, 20), reason: t.id);
      for (final p in t.perguntas) {
        expect(p.alternativas.length, 4, reason: p.id);
        for (final a in p.alternativas) {
          expect(a.pontuacao, isNotEmpty);
          for (final e in a.pontuacao.keys) {
            expect(defs.containsKey(e), isTrue, reason: 'eixo $e em ${p.id}');
          }
          for (final v in a.pontuacao.values) {
            expect(v.pontos, inInclusiveRange(1, 4));
          }
        }
      }
    }
  });

  test('afirmações equilibradas: cada teste tem perguntas nas duas direções', () {
    for (final t in testes) {
      var a = 0, b = 0;
      for (final p in t.perguntas) {
        final first = p.alternativas.first.pontuacao.values.first.pontos;
        first == 1 ? a++ : b++;
      }
      expect(a, greaterThan(0), reason: t.id);
      expect(b, greaterThan(0), reason: t.id);
    }
  });

  test('respostas todas no polo A resultam em 0% e no polo B em 100%', () {
    final t = testes.firstWhere((t) => t.id == 'economico');
    final ra = sc.calcular(t, polo(t, 'A'), defs);
    final rb = sc.calcular(t, polo(t, 'B'), defs);
    expect(ra.eixos['economia']!.pct, closeTo(0, .01));
    expect(rb.eixos['economia']!.pct, closeTo(100, .01));
    expect(ra.classificacao, 'Esquerda');
    expect(rb.classificacao, 'Direita');
    expect(ra.pontuacaoTotal, ra.pontuacaoMin);
    expect(rb.pontuacaoTotal, rb.pontuacaoMax);
  });

  test('respostas intermediárias ficam no centro', () {
    final t = testes.firstWhere((t) => t.id == 'rapido');
    // Alternar "Concordo em parte" (B) e "Discordo em parte" (C) produz ~centro.
    final r = <String, String>{};
    for (var i = 0; i < t.perguntas.length; i++) {
      r[t.perguntas[i].id] = i.isEven ? 'B' : 'C';
    }
    final res = sc.calcular(t, r, defs);
    expect(res.indiceGeral, inInclusiveRange(30, 70));
  });

  test('perguntas sem resposta não contam', () {
    final t = testes.first;
    final r = sc.calcular(t, {t.perguntas.first.id: 'A'}, defs);
    expect(r.eixos.values.fold<double>(0, (a, e) => a + e.peso), closeTo(t.perguntas.first.alternativas.first.pontuacao.values.fold<double>(0, (a, p) => a + p.peso), .001));
  });

  test('teste de instituições não gera índice esquerda-direita', () {
    final t = testes.firstWhere((t) => t.id == 'instituicoes');
    final r = sc.calcular(t, todasLetra(t, 'A'), defs);
    expect(r.indiceGeral, isNull);
    expect(r.rotuloDescritivo, isNotEmpty);
  });

  test('consolidação soma eixos de testes diferentes', () {
    final t1 = testes.firstWhere((t) => t.id == 'economico');
    final t2 = testes.firstWhere((t) => t.id == 'social');
    final r1 = sc.calcular(t1, polo(t1, 'A'), defs);
    final r2 = sc.calcular(t2, polo(t2, 'B'), defs);
    final c = sc.consolidar([r1, r2]);
    expect(c.keys, containsAll(['economia', 'direitos_civis']));
    final rot = sc.rotuloDescritivo(c, defs);
    expect(rot, contains('Estado ativo'));
    expect(rot, contains('conservador social'));
    final an = sc.analisar(c, defs);
    expect(an.divergencias, isNotEmpty, reason: 'economia e costumes em lados opostos');
  });

  test('detecta divergência interna em um eixo', () {
    final t = testes.firstWhere((t) => t.id == 'economico');
    final r = <String, String>{};
    final alvoA = polo(t, 'A');
    final alvoB = polo(t, 'B');
    for (var i = 0; i < t.perguntas.length; i++) {
      final id = t.perguntas[i].id;
      r[id] = i.isEven ? alvoA[id]! : alvoB[id]!;
    }
    final res = sc.calcular(t, r, defs);
    final an = sc.analisar(res.eixos, defs, teste: t, respostas: r);
    expect(an.divergencias.any((d) => d.startsWith('Economia')), isTrue);
  });

  test('texto de compartilhamento é neutro', () {
    final txt = sc.textoCompartilhamento('Centro-esquerda');
    expect(txt, contains('não representa apoio a partidos ou candidatos'));
  });
}
