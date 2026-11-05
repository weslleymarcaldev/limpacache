import 'package:flutter_test/flutter_test.dart';
import 'package:radar_politico/models/conteudo.dart';
import 'package:radar_politico/models/eixo.dart';
import 'package:radar_politico/services/compatibilidade_service.dart';

void main() {
  const defs = {
    'economia': Eixo(id: 'economia', nome: 'Economia', poloA: 'Mais Estado', poloB: 'Mais mercado', descricao: '', esquerdaDireita: 'A'),
    'seguranca': Eixo(id: 'seguranca', nome: 'Segurança', poloA: 'Prevenção', poloB: 'Endurecimento', descricao: '', esquerdaDireita: 'A'),
    'federalismo': Eixo(id: 'federalismo', nome: 'Federalismo', poloA: 'Centralização', poloB: 'Descentralização', descricao: ''),
  };
  Candidato cand(String id, Map<String, double> e) => Candidato(
      id: id, nome: id, cargo: '', partido: '', uf: '', resumo: '', baseEixos: '', aviso: null, atualizadoEm: '',
      itens: const {}, eixos: e, fontes: const []);
  const svc = CompatibilidadeService();

  test('compatibilidade por eixo = 100 - distância', () {
    final r = svc.comparar({'economia': 20, 'seguranca': 80}, cand('x', {'economia': 30, 'seguranca': 20}), defs);
    expect(r.eixos.length, 2);
    expect(r.eixos.firstWhere((e) => e.eixo.id == 'economia').compatibilidade, 90);
    expect(r.eixos.firstWhere((e) => e.eixo.id == 'seguranca').compatibilidade, 40);
    expect(r.geral, 65);
    expect(r.convergencias.map((e) => e.eixo.id), ['economia']);
    expect(r.divergencias.map((e) => e.eixo.id), ['seguranca']);
  });

  test('ignora eixos sem dado do usuário ou do candidato', () {
    final r = svc.comparar({'economia': 50}, cand('x', {'economia': 50, 'federalismo': 10}), defs);
    expect(r.eixos.length, 1);
    expect(r.geral, 100);
  });

  test('filtro por temas selecionados', () {
    final r = svc.comparar({'economia': 0, 'seguranca': 0}, cand('x', {'economia': 0, 'seguranca': 100}), defs, eixosSelecionados: {'economia'});
    expect(r.geral, 100);
  });

  test('ordenação por compatibilidade e frases sem recomendação de voto', () {
    final l = svc.ordenar({'economia': 10}, [cand('a', {'economia': 90}), cand('b', {'economia': 15})], defs);
    expect(l.first.candidato.id, 'b');
    for (final r in l) {
      expect(r.frase.toLowerCase(), isNot(contains('vote')));
      expect(r.frase.toLowerCase(), isNot(contains('melhor')));
      expect(r.frase, contains('Com base nas respostas informadas'));
    }
  });
}
