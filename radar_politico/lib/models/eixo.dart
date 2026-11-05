class Eixo {
  final String id;
  final String nome;
  final String poloA;
  final String poloB;
  final String descricao;

  /// 'A' quando o polo A corresponde, por convenção, ao campo da esquerda.
  /// null para eixos que não entram no índice esquerda–direita.
  final String? esquerdaDireita;

  const Eixo({
    required this.id,
    required this.nome,
    required this.poloA,
    required this.poloB,
    required this.descricao,
    this.esquerdaDireita,
  });

  bool get entraNoIndiceGeral => esquerdaDireita != null;

  factory Eixo.fromJson(Map<String, dynamic> j) => Eixo(
        id: j['id'],
        nome: j['nome'],
        poloA: j['poloA'] ?? j['polo_a'],
        poloB: j['poloB'] ?? j['polo_b'],
        descricao: j['descricao'],
        esquerdaDireita: j['esquerdaDireita'] ?? j['esquerda_direita'],
      );

  Map<String, Object?> toDb() => {
        'id': id,
        'nome': nome,
        'polo_a': poloA,
        'polo_b': poloB,
        'descricao': descricao,
        'esquerda_direita': esquerdaDireita,
      };
}
