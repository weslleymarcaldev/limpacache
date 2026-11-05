import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radar_politico/core/constants.dart';
import 'package:radar_politico/services/ai_correction_service.dart';

void main() {
  const pedido = PedidoCorrecao(
    conteudoTipo: 'governo_item', conteudoId: 'gov001', trecho: 'A lei X foi sancionada em 2023.',
    motivo: '[Erro factual] A data correta da sanção é 19/06/2023.', fonte: 'https://www.planalto.gov.br/ccivil_03/x.htm');

  AiCorrectionService comResposta(Map<String, dynamic> analise, {int status = 200, List<http.Request>? log}) =>
      AiCorrectionService(client: MockClient((req) async {
        log?.add(req);
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'text', 'text': jsonEncode(analise)}
              ]
            })),
            status,
            headers: {'content-type': 'application/json'});
      }));

  Map<String, dynamic> analise({String c = 'correcao_valida', bool vies = false, double conf = .9, String sug = 'A lei foi sancionada em 19/06/2023.'}) => {
        'classificacao': c, 'tipo_problema': 'erro_factual', 'vies_partidario_na_sugestao': vies, 'confianca': conf,
        'justificativa': 'Data conferida no Planalto.', 'resposta_ao_usuario': 'Obrigado.', 'sugestao_texto': sug,
      };

  test('envia cabeçalhos e modelo corretos e aceita correção válida', () async {
    final log = <http.Request>[];
    final svc = comResposta(analise(), log: log);
    final r = await svc.analisar(pedido, apiKey: 'k', modelo: AppInfo.modeloIaPadrao);
    expect(r.classificacao, ClassificacaoCorrecao.valida);
    expect(r.viaIa, isTrue);
    expect(log.single.headers['x-api-key'], 'k');
    expect(log.single.headers['anthropic-version'], '2023-06-01');
    final body = jsonDecode(log.single.body);
    expect(body['model'], 'claude-opus-5-5');
    expect(body['system'], contains('apartidária'));
  });

  test('salvaguarda bloqueia sugestão com viés', () async {
    final r = await comResposta(analise(vies: true)).analisar(pedido, apiKey: 'k', modelo: 'm');
    expect(r.classificacao, ClassificacaoCorrecao.maisInfo);
  });

  test('salvaguarda bloqueia termos valorativos mesmo sem a IA marcar viés', () async {
    final r = await comResposta(analise(sug: 'Foi um ótimo governo nesse tema.')).analisar(pedido, apiKey: 'k', modelo: 'm');
    expect(r.classificacao, ClassificacaoCorrecao.maisInfo);
  });

  test('baixa confiança não valida', () async {
    final r = await comResposta(analise(conf: .3)).analisar(pedido, apiKey: 'k', modelo: 'm');
    expect(r.classificacao, ClassificacaoCorrecao.maisInfo);
  });

  test('falha de rede cai para triagem local', () async {
    final svc = AiCorrectionService(client: MockClient((_) async => http.Response('erro', 500)));
    final r = await svc.analisar(pedido, apiKey: 'k', modelo: 'm');
    expect(r.viaIa, isFalse);
    expect(r.classificacao, ClassificacaoCorrecao.pendente);
  });

  group('triagem local', () {
    final svc = AiCorrectionService(client: MockClient((_) async => http.Response('', 500)));
    PedidoCorrecao p(String motivo, [String fonte = '']) =>
        PedidoCorrecao(conteudoTipo: 't', conteudoId: '1', trecho: 'x', motivo: motivo, fonte: fonte);
    test('ofensa com acento', () => expect(svc.triagemLocal(p('esse ladrão mentiu')).classificacao, ClassificacaoCorrecao.impropria));
    test('ofensa', () => expect(svc.triagemLocal(p('isso é um lixo, seu idiota')).classificacao, ClassificacaoCorrecao.impropria));
    test('opinião', () => expect(svc.triagemLocal(p('Na minha opinião esse governo é péssimo')).classificacao, ClassificacaoCorrecao.opiniao));
    test('dúvida', () => expect(svc.triagemLocal(p('Qual é a fonte desse dado?')).classificacao, ClassificacaoCorrecao.duvida));
    test('sem fonte', () => expect(svc.triagemLocal(p('O número de ministérios está errado')).classificacao, ClassificacaoCorrecao.maisInfo));
    test('com fonte nunca é validada sozinha',
        () => expect(svc.triagemLocal(p('O número está errado', 'https://www.gov.br/x')).classificacao, ClassificacaoCorrecao.pendente));
  });

  test('extrai JSON cercado por texto', () {
    expect(AiCorrectionService.extrairJson('```json\n{"a":1}\n```')['a'], 1);
  });
}
