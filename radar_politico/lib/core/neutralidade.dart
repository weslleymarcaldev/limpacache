/// Verificações automáticas de linguagem usadas em testes de conteúdo e
/// no filtro de correções. Não substituem revisão humana.
class Neutralidade {
  /// Rótulos pejorativos ou partidários que não podem aparecer no conteúdo.
  static const termosProibidos = [
    'esquerdista', 'direitista', 'esquerdopata', 'bolsonarista', 'petista',
    'fascista', 'comunista', 'mortadela', 'coxinha', 'gado', 'lacrador',
    'isentão', 'bolsominion', 'petralha',
  ];

  /// Expressões de recomendação de voto proibidas pela regra editorial.
  static const recomendacoesProibidas = [
    'melhor candidato', 'candidato ideal', 'você deveria votar', 'vote em',
    'candidato certo', 'ranking dos melhores',
  ];

  /// Adjetivos valorativos proibidos na análise do governo.
  static const adjetivosValorativos = [
    'ótimo governo', 'desastre', 'desastroso', 'mentiroso', 'herói', 'vilão',
    'péssimo', 'excelente governo',
  ];

  static const _ini = r'(?<![\p{L}\p{N}])';
  static const _fim = r'(?![\p{L}\p{N}])';

  static final _ofensas = RegExp(
      '$_ini(idiota|imbecil|burro|lixo|canalha|vagabund\\p{L}*|ladr(ão|oes|ões)|corrupto\\p{L}*|safad\\p{L}*|merda|porra|caralho)$_fim',
      caseSensitive: false, unicode: true);

  static List<String> encontrarTermos(String texto, List<String> lista) {
    final t = texto.toLowerCase();
    // Fronteira de palavra compatível com acentos (\\b do Dart só considera ASCII).
    return lista
        .where((p) => RegExp('(?<![\\p{L}\\p{N}])${RegExp.escape(p)}', caseSensitive: false, unicode: true).hasMatch(t))
        .toList();
  }

  static bool contemOfensa(String texto) => _ofensas.hasMatch(texto);

  /// Marcadores de opinião pessoal (heurística offline).
  static final _opiniao = RegExp(
      '$_ini(acho que|na minha opini[aã]o|eu acho|pra mim|para mim|governo (bom|ruim|p[eé]ssimo)|todo mundo sabe|[oó]bvio que)$_fim',
      caseSensitive: false, unicode: true);

  static bool pareceOpiniao(String texto) => _opiniao.hasMatch(texto);

  static bool contemLink(String texto) =>
      RegExp(r'https?://|www\.|\.gov\.br|\.leg\.br|\.jus\.br', caseSensitive: false).hasMatch(texto);
}
