import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/neutralidade.dart';

/// Resultado da análise de uma correção reportada.
class AnaliseCorrecao {
  final String classificacao; // ver ClassificacaoCorrecao
  final String tipoProblema; // erro_factual | desatualizacao | ambiguidade | vies | nenhum
  final bool viesNaSugestao;
  final double confianca;
  final String justificativa;
  final String respostaUsuario;
  final String sugestaoTexto;
  final bool viaIa;

  const AnaliseCorrecao({
    required this.classificacao,
    required this.tipoProblema,
    required this.viesNaSugestao,
    required this.confianca,
    required this.justificativa,
    required this.respostaUsuario,
    required this.sugestaoTexto,
    required this.viaIa,
  });

  Map<String, dynamic> toJson() => {
        'classificacao': classificacao,
        'tipo_problema': tipoProblema,
        'vies_partidario_na_sugestao': viesNaSugestao,
        'confianca': confianca,
        'justificativa': justificativa,
        'resposta_ao_usuario': respostaUsuario,
        'sugestao_texto': sugestaoTexto,
        'via_ia': viaIa,
      };

  factory AnaliseCorrecao.fromJson(Map<String, dynamic> j, {required bool viaIa}) {
    final c = j['classificacao'] as String? ?? ClassificacaoCorrecao.maisInfo;
    return AnaliseCorrecao(
      classificacao: ClassificacaoCorrecao.todas.contains(c) ? c : ClassificacaoCorrecao.maisInfo,
      tipoProblema: j['tipo_problema'] as String? ?? 'nenhum',
      viesNaSugestao: j['vies_partidario_na_sugestao'] == true,
      confianca: (j['confianca'] as num?)?.toDouble() ?? 0,
      justificativa: j['justificativa'] as String? ?? '',
      respostaUsuario: j['resposta_ao_usuario'] as String? ?? '',
      sugestaoTexto: j['sugestao_texto'] as String? ?? '',
      viaIa: viaIa,
    );
  }

  AnaliseCorrecao copiar({String? classificacao, String? respostaUsuario, String? justificativa}) => AnaliseCorrecao(
        classificacao: classificacao ?? this.classificacao,
        tipoProblema: tipoProblema,
        viesNaSugestao: viesNaSugestao,
        confianca: confianca,
        justificativa: justificativa ?? this.justificativa,
        respostaUsuario: respostaUsuario ?? this.respostaUsuario,
        sugestaoTexto: sugestaoTexto,
        viaIa: viaIa,
      );
}

class PedidoCorrecao {
  final String conteudoTipo;
  final String conteudoId;
  final String trecho;
  final String motivo;
  final String fonte;
  const PedidoCorrecao({
    required this.conteudoTipo,
    required this.conteudoId,
    required this.trecho,
    required this.motivo,
    required this.fonte,
  });
}

/// Analisa correções com a API do Claude (Messages API via HTTP — Dart não possui SDK oficial).
/// Sem chave configurada ou sem conexão, usa uma triagem local conservadora que nunca valida
/// correções sozinha: apenas encaminha para revisão humana.
class AiCorrectionService {
  final http.Client _client;
  AiCorrectionService({http.Client? client}) : _client = client ?? http.Client();

  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  static const systemPrompt = '''
Você é o revisor editorial do aplicativo "Radar Político", uma ferramenta educativa, neutra e apartidária.
Usuários reportam possíveis erros em conteúdos do app (perguntas, dados de políticos, análise do governo, quiz).

Sua tarefa:
1. Ler o trecho do conteúdo, o motivo e a fonte informados pelo usuário.
2. Avaliar se há indício de erro factual, desatualização, ambiguidade ou viés no CONTEÚDO DO APP.
3. Verificar com base em fontes oficiais e confiáveis (Planalto, Congresso, TSE, IBGE, Banco Central, ministérios,
   tribunais, imprensa de referência). Se não puder confirmar com segurança, NÃO classifique como correção válida.
4. Classificar como exatamente uma das opções:
   - correcao_valida: o conteúdo tem erro/desatualização verificável e a correção proposta é factual.
   - precisa_mais_informacoes: pode haver problema, mas faltam fonte ou detalhes para confirmar.
   - duvida: o usuário está perguntando algo, não apontando erro.
   - opiniao: a observação expressa preferência, juízo de valor ou avaliação política, não um fato.
   - conteudo_improprio: ofensas, ataques pessoais, discurso de ódio ou spam.
5. Escrever resposta educada, transparente e respeitosa ao usuário, em português do Brasil, sem desqualificá-lo.

Regras invioláveis:
- Nunca proponha texto que favoreça ou prejudique partido, candidato, governo ou ideologia.
- Use linguagem factual ("a lei foi sancionada", "o indicador caiu"); proíba adjetivos valorativos.
- Nunca recomende voto.
- Se a sugestão do usuário inserir juízo de valor, marque vies_partidario_na_sugestao = true e não a valide.
- Em sugestao_texto, proponha a redação corrigida (neutra) somente se a correção for válida; caso contrário, string vazia.
- Responda apenas com o JSON pedido.''';

  static const _schema = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'classificacao', 'tipo_problema', 'vies_partidario_na_sugestao', 'confianca',
      'justificativa', 'resposta_ao_usuario', 'sugestao_texto'
    ],
    'properties': {
      'classificacao': {
        'type': 'string',
        'enum': ['correcao_valida', 'precisa_mais_informacoes', 'duvida', 'opiniao', 'conteudo_improprio']
      },
      'tipo_problema': {
        'type': 'string',
        'enum': ['erro_factual', 'desatualizacao', 'ambiguidade', 'vies', 'nenhum']
      },
      'vies_partidario_na_sugestao': {'type': 'boolean'},
      'confianca': {'type': 'number'},
      'justificativa': {'type': 'string'},
      'resposta_ao_usuario': {'type': 'string'},
      'sugestao_texto': {'type': 'string'},
    },
  };

  String _mensagemUsuario(PedidoCorrecao p) => '''
Tipo de conteúdo: ${p.conteudoTipo}
ID do conteúdo: ${p.conteudoId}

<conteudo_do_app>
${p.trecho}
</conteudo_do_app>

<observacao_do_usuario>
${p.motivo}
</observacao_do_usuario>

<fonte_informada_pelo_usuario>
${p.fonte.isEmpty ? '(nenhuma)' : p.fonte}
</fonte_informada_pelo_usuario>

Analise e responda no formato JSON definido (campos: classificacao, tipo_problema, vies_partidario_na_sugestao,
confianca de 0 a 1, justificativa, resposta_ao_usuario, sugestao_texto).''';

  Future<AnaliseCorrecao> analisar(PedidoCorrecao p, {required String apiKey, required String modelo}) async {
    // Filtros locais que dispensam IA.
    if (Neutralidade.contemOfensa('${p.motivo} ${p.fonte}')) {
      return triagemLocal(p);
    }
    if (apiKey.isEmpty) return triagemLocal(p);
    try {
      final a = await _chamarClaude(p, apiKey: apiKey, modelo: modelo);
      return aplicarSalvaguardas(p, a);
    } catch (_) {
      final local = triagemLocal(p);
      return local.copiar(
          respostaUsuario: '${local.respostaUsuario}\n\n(A análise automática por IA não estava disponível; '
              'sua contribuição foi registrada para revisão.)');
    }
  }

  Future<AnaliseCorrecao> _chamarClaude(PedidoCorrecao p, {required String apiKey, required String modelo}) async {
    Map<String, dynamic> corpo({required bool recursosAvancados}) => {
          'model': modelo,
          'max_tokens': 4000,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': _mensagemUsuario(p)}
          ],
          if (recursosAvancados) ...{
            'output_config': {
              'effort': 'low',
              'format': {'type': 'json_schema', 'schema': _schema},
            },
            'fallbacks': 'default',
          },
        };

    Future<http.Response> enviar(bool avancado) => _client
        .post(Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              if (avancado) 'anthropic-beta': 'server-side-fallback-2026-07-01',
            },
            body: jsonEncode(corpo(recursosAvancados: avancado)))
        .timeout(const Duration(seconds: 90));

    var resp = await enviar(true);
    if (resp.statusCode == 400) {
      // Modelo/conta sem suporte a algum recurso opcional: tenta a forma básica.
      resp = await enviar(false);
    }
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if (body['stop_reason'] == 'refusal') {
      throw Exception('refusal');
    }
    final texto = (body['content'] as List)
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();
    return AnaliseCorrecao.fromJson(extrairJson(texto), viaIa: true);
  }

  /// Extrai o primeiro objeto JSON de um texto (tolera cercas de código).
  static Map<String, dynamic> extrairJson(String texto) {
    final ini = texto.indexOf('{');
    final fim = texto.lastIndexOf('}');
    if (ini < 0 || fim <= ini) throw const FormatException('JSON ausente');
    return jsonDecode(texto.substring(ini, fim + 1)) as Map<String, dynamic>;
  }

  /// Regras que valem independentemente da IA: nenhuma correção com viés, ofensa
  /// ou recomendação de voto é aceita.
  AnaliseCorrecao aplicarSalvaguardas(PedidoCorrecao p, AnaliseCorrecao a) {
    if (a.classificacao != ClassificacaoCorrecao.valida) return a;
    final textoSugerido = '${a.sugestaoTexto} ${p.motivo}';
    final termos = [
      ...Neutralidade.encontrarTermos(textoSugerido, Neutralidade.termosProibidos),
      ...Neutralidade.encontrarTermos(a.sugestaoTexto, Neutralidade.recomendacoesProibidas),
      ...Neutralidade.encontrarTermos(a.sugestaoTexto, Neutralidade.adjetivosValorativos),
    ];
    if (a.viesNaSugestao || termos.isNotEmpty) {
      return a.copiar(
        classificacao: ClassificacaoCorrecao.maisInfo,
        justificativa: '${a.justificativa} [Salvaguarda: a sugestão continha linguagem valorativa ou partidária e não foi aplicada.]',
        respostaUsuario:
            'Obrigado pela contribuição. A observação foi registrada, mas a alteração sugerida inclui avaliações que não seguem a linguagem factual do app. '
            'Se puder, envie a informação objetiva e a fonte oficial correspondente.',
      );
    }
    if (a.confianca < 0.6) {
      return a.copiar(
        classificacao: ClassificacaoCorrecao.maisInfo,
        respostaUsuario:
            'Obrigado pela contribuição. Há indícios de que sua observação pode proceder, mas não foi possível confirmá-la com segurança. '
            'O conteúdo foi sinalizado para revisão. Se tiver um link de fonte oficial, ele ajuda a acelerar a verificação.',
      );
    }
    return a;
  }

  /// Triagem offline conservadora.
  AnaliseCorrecao triagemLocal(PedidoCorrecao p) {
    final texto = '${p.motivo} ${p.fonte}';
    if (Neutralidade.contemOfensa(texto)) {
      return const AnaliseCorrecao(
        classificacao: ClassificacaoCorrecao.impropria,
        tipoProblema: 'nenhum',
        viesNaSugestao: false,
        confianca: 0.9,
        justificativa: 'Texto contém termos ofensivos.',
        respostaUsuario:
            'Recebemos sua mensagem, mas ela contém termos ofensivos e não pôde ser analisada. Você pode reenviar a observação de forma objetiva, indicando o trecho e a fonte.',
        sugestaoTexto: '',
        viaIa: false,
      );
    }
    final pergunta = p.motivo.trim().endsWith('?');
    if (pergunta && !Neutralidade.contemLink(texto)) {
      return const AnaliseCorrecao(
        classificacao: ClassificacaoCorrecao.duvida,
        tipoProblema: 'nenhum',
        viesNaSugestao: false,
        confianca: 0.6,
        justificativa: 'A mensagem tem formato de pergunta.',
        respostaUsuario:
            'Obrigado pela pergunta. A seção "Como avaliamos" explica fontes e critérios. Se identificar um erro específico, descreva o trecho e indique a fonte.',
        sugestaoTexto: '',
        viaIa: false,
      );
    }
    if (Neutralidade.pareceOpiniao(texto) && !Neutralidade.contemLink(texto)) {
      return const AnaliseCorrecao(
        classificacao: ClassificacaoCorrecao.opiniao,
        tipoProblema: 'nenhum',
        viesNaSugestao: false,
        confianca: 0.6,
        justificativa: 'A observação expressa avaliação pessoal sem fonte factual.',
        respostaUsuario:
            'Obrigado pela contribuição. Sua observação parece expressar uma avaliação pessoal, o que é legítimo, mas o app registra apenas informações verificáveis. '
            'Se houver um dado incorreto, indique o trecho e uma fonte oficial.',
        sugestaoTexto: '',
        viaIa: false,
      );
    }
    if (!Neutralidade.contemLink(texto) && p.fonte.trim().length < 10) {
      return const AnaliseCorrecao(
        classificacao: ClassificacaoCorrecao.maisInfo,
        tipoProblema: 'nenhum',
        viesNaSugestao: false,
        confianca: 0.5,
        justificativa: 'Sem fonte informada.',
        respostaUsuario:
            'Obrigado pela contribuição. Para verificar a observação, precisamos de uma fonte (link oficial, número da lei, data da publicação ou reportagem). '
            'Sua mensagem foi registrada e você pode complementá-la enviando um novo reporte.',
        sugestaoTexto: '',
        viaIa: false,
      );
    }
    return const AnaliseCorrecao(
      classificacao: ClassificacaoCorrecao.pendente,
      tipoProblema: 'nenhum',
      viesNaSugestao: false,
      confianca: 0.5,
      justificativa: 'Reporte com fonte; encaminhado para revisão humana.',
      respostaUsuario:
          'Obrigado pela contribuição. Sua observação inclui uma fonte e foi encaminhada para revisão. O conteúdo foi sinalizado como "em revisão" até a verificação.',
      sugestaoTexto: '',
      viaIa: false,
    );
  }
}
