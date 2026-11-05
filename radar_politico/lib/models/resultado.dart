import 'dart:convert';

/// Pontuação consolidada de um eixo.
class EixoScore {
  final String eixoId;
  final double bruto;
  final double minimo;
  final double maximo;
  /// Pontos individuais (1 a 4) recebidos neste eixo, usados para detectar divergências.
  final List<double> valores;

  const EixoScore({
    required this.eixoId,
    required this.bruto,
    required this.minimo,
    required this.maximo,
    this.valores = const [],
  });

  /// 0 = polo A, 100 = polo B.
  double get pct => maximo <= minimo ? 50 : ((bruto - minimo) / (maximo - minimo) * 100).clamp(0, 100);

  /// Quantidade aproximada de perguntas (soma de pesos) que alimentam o eixo.
  double get peso => (maximo - minimo) / 3;

  Map<String, dynamic> toJson() => {
        'eixo': eixoId,
        'bruto': bruto,
        'min': minimo,
        'max': maximo,
        'valores': valores,
      };

  factory EixoScore.fromJson(Map<String, dynamic> j) => EixoScore(
        eixoId: j['eixo'],
        bruto: (j['bruto'] as num).toDouble(),
        minimo: (j['min'] as num).toDouble(),
        maximo: (j['max'] as num).toDouble(),
        valores: ((j['valores'] as List?) ?? []).map((e) => (e as num).toDouble()).toList(),
      );

  EixoScore somar(EixoScore o) => EixoScore(
        eixoId: eixoId,
        bruto: bruto + o.bruto,
        minimo: minimo + o.minimo,
        maximo: maximo + o.maximo,
        valores: [...valores, ...o.valores],
      );
}

class ResultadoTeste {
  final int? id;
  final String testeId;
  final DateTime criadoEm;
  final double pontuacaoTotal;
  final double pontuacaoMin;
  final double pontuacaoMax;
  final double? indiceGeral;
  final String classificacao;
  final String rotuloDescritivo;
  final Map<String, EixoScore> eixos;
  final Map<String, String> respostas;
  final bool salvo;

  const ResultadoTeste({
    this.id,
    required this.testeId,
    required this.criadoEm,
    required this.pontuacaoTotal,
    required this.pontuacaoMin,
    required this.pontuacaoMax,
    required this.indiceGeral,
    required this.classificacao,
    required this.rotuloDescritivo,
    required this.eixos,
    required this.respostas,
    this.salvo = false,
  });

  Map<String, Object?> toDb(String usuarioId) => {
        if (id != null) 'id': id,
        'usuario_id': usuarioId,
        'teste_id': testeId,
        'criado_em': criadoEm.toIso8601String(),
        'pontuacao_total': pontuacaoTotal,
        'pontuacao_min': pontuacaoMin,
        'pontuacao_max': pontuacaoMax,
        'indice_geral': indiceGeral,
        'classificacao': classificacao,
        'rotulo': rotuloDescritivo,
        'eixos_json': jsonEncode(eixos.values.map((e) => e.toJson()).toList()),
        'respostas_json': jsonEncode(respostas),
      };

  factory ResultadoTeste.fromDb(Map<String, Object?> r) => ResultadoTeste(
        id: r['id'] as int?,
        testeId: r['teste_id'] as String,
        criadoEm: DateTime.parse(r['criado_em'] as String),
        pontuacaoTotal: (r['pontuacao_total'] as num).toDouble(),
        pontuacaoMin: (r['pontuacao_min'] as num).toDouble(),
        pontuacaoMax: (r['pontuacao_max'] as num).toDouble(),
        indiceGeral: (r['indice_geral'] as num?)?.toDouble(),
        classificacao: r['classificacao'] as String,
        rotuloDescritivo: (r['rotulo'] as String?) ?? '',
        eixos: {
          for (final e in (jsonDecode(r['eixos_json'] as String) as List))
            e['eixo'] as String: EixoScore.fromJson(e as Map<String, dynamic>)
        },
        respostas: Map<String, String>.from(jsonDecode(r['respostas_json'] as String) as Map),
        salvo: true,
      );
}
