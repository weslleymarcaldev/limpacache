import 'dart:convert';

class PontoEixo {
  final double pontos;
  final double peso;
  const PontoEixo(this.pontos, this.peso);
}

class Alternativa {
  final String letra;
  final String texto;
  /// eixoId -> pontos (1 a 4) e peso.
  final Map<String, PontoEixo> pontuacao;
  const Alternativa({required this.letra, required this.texto, required this.pontuacao});

  factory Alternativa.fromJson(Map<String, dynamic> j) => Alternativa(
        letra: j['letra'],
        texto: j['texto'],
        pontuacao: _parsePontuacao(j['pontuacao']),
      );

  static Map<String, PontoEixo> _parsePontuacao(dynamic raw) {
    final m = raw is String ? jsonDecode(raw) as Map<String, dynamic> : raw as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(
        k, PontoEixo((v['pontos'] as num).toDouble(), (v['peso'] as num? ?? 1).toDouble())));
  }

  String pontuacaoJson() => jsonEncode(pontuacao.map((k, v) => MapEntry(k, {'pontos': v.pontos, 'peso': v.peso})));
}

class Pergunta {
  final String id;
  final String texto;
  final String? tema;
  final List<Alternativa> alternativas;
  const Pergunta({required this.id, required this.texto, this.tema, required this.alternativas});

  factory Pergunta.fromJson(Map<String, dynamic> j) => Pergunta(
        id: j['id'],
        texto: j['texto'],
        tema: j['tema'],
        alternativas: (j['alternativas'] as List).map((a) => Alternativa.fromJson(a)).toList(),
      );

  Alternativa? alternativa(String? letra) {
    for (final a in alternativas) {
      if (a.letra == letra) return a;
    }
    return null;
  }
}

class TesteModel {
  final String id;
  final String titulo;
  final String descricao;
  final String explicacao;
  final String icone;
  final int tempoMin;
  final bool rapido;
  final List<Pergunta> perguntas;

  const TesteModel({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.explicacao,
    required this.icone,
    required this.tempoMin,
    required this.rapido,
    required this.perguntas,
  });

  factory TesteModel.fromJson(Map<String, dynamic> j) => TesteModel(
        id: j['id'],
        titulo: j['titulo'],
        descricao: j['descricao'],
        explicacao: j['explicacao'],
        icone: j['icone'] ?? 'quiz',
        tempoMin: j['tempoMin'] ?? 5,
        rapido: j['rapido'] == true,
        perguntas: (j['perguntas'] as List).map((p) => Pergunta.fromJson(p)).toList(),
      );
}
