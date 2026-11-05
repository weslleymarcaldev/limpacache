import '../models/eixo.dart';
import '../models/resultado.dart';
import '../models/teste.dart';

/// Faixa de classificação de um eixo (0–100).
class FaixaEixo {
  final String rotulo;
  final String explicacao;
  const FaixaEixo(this.rotulo, this.explicacao);
}

class AnaliseResultado {
  final List<String> pontosFortes;
  final List<String> divergencias;
  final List<String> aproximaA; // temas que aproximam do polo "esquerda" (convenção)
  final List<String> aproximaB; // temas que aproximam do polo "direita" (convenção)
  final String explicacao;
  const AnaliseResultado({
    required this.pontosFortes,
    required this.divergencias,
    required this.aproximaA,
    required this.aproximaB,
    required this.explicacao,
  });
}

/// Cálculo de pontuação por eixo. Funções puras, sem acesso a banco, para facilitar testes.
///
/// Cada alternativa vale de 1 (polo A) a 4 (polo B) em um ou mais eixos, com peso.
/// Percentual do eixo = (bruto − mínimo) / (máximo − mínimo) × 100.
class ScoringService {
  const ScoringService();

  static const classesGerais = ['Esquerda', 'Centro-esquerda', 'Centro', 'Centro-direita', 'Direita'];

  Map<String, EixoScore> pontuarEixos(TesteModel teste, Map<String, String> respostas) {
    final out = <String, EixoScore>{};
    for (final p in teste.perguntas) {
      final alt = p.alternativa(respostas[p.id]);
      if (alt == null) continue;
      alt.pontuacao.forEach((eixo, pe) {
        final s = EixoScore(
          eixoId: eixo,
          bruto: pe.pontos * pe.peso,
          minimo: 1 * pe.peso,
          maximo: 4 * pe.peso,
          valores: [pe.pontos],
        );
        out[eixo] = out.containsKey(eixo) ? out[eixo]!.somar(s) : s;
      });
    }
    return out;
  }

  /// Índice geral esquerda–direita (0 a 100), média ponderada dos eixos que entram no índice.
  double? indiceGeral(Map<String, EixoScore> eixos, Map<String, Eixo> defs) {
    double soma = 0, pesos = 0;
    eixos.forEach((id, s) {
      final d = defs[id];
      if (d == null || !d.entraNoIndiceGeral) return;
      final pct = d.esquerdaDireita == 'A' ? s.pct : 100 - s.pct;
      soma += pct * s.peso;
      pesos += s.peso;
    });
    return pesos == 0 ? null : soma / pesos;
  }

  String classeGeral(double? indice) {
    if (indice == null) return 'Sem posição geral (eixos fora da escala esquerda–direita)';
    if (indice < 20) return classesGerais[0];
    if (indice < 40) return classesGerais[1];
    if (indice <= 60) return classesGerais[2];
    if (indice <= 80) return classesGerais[3];
    return classesGerais[4];
  }

  FaixaEixo faixaEixo(double pct, Eixo e) {
    if (pct < 20) return FaixaEixo('Forte tendência: ${e.poloA.toLowerCase()}', 'Suas respostas se concentram no polo "${e.poloA}".');
    if (pct < 40) return FaixaEixo('Tendência: ${e.poloA.toLowerCase()}', 'Suas respostas pendem para "${e.poloA}", com algumas ressalvas.');
    if (pct <= 60) return FaixaEixo('Posição intermediária', 'Suas respostas combinam elementos dos dois polos.');
    if (pct <= 80) return FaixaEixo('Tendência: ${e.poloB.toLowerCase()}', 'Suas respostas pendem para "${e.poloB}", com algumas ressalvas.');
    return FaixaEixo('Forte tendência: ${e.poloB.toLowerCase()}', 'Suas respostas se concentram no polo "${e.poloB}".');
  }

  double? _media(Map<String, EixoScore> eixos, List<String> ids) {
    double soma = 0, pesos = 0;
    for (final id in ids) {
      final s = eixos[id];
      if (s == null) continue;
      soma += s.pct * s.peso;
      pesos += s.peso;
    }
    return pesos == 0 ? null : soma / pesos;
  }

  /// Rótulo descritivo combinando dimensão econômica e social,
  /// p.ex. "Centro-esquerda — liberal econômico e progressista social".
  String rotuloDescritivo(Map<String, EixoScore> eixos, Map<String, Eixo> defs) {
    final indice = indiceGeral(eixos, defs);
    final eco = _media(eixos, ['economia', 'papel_estado']);
    final soc = _media(eixos, ['direitos_civis', 'religiao_estado', 'seguranca']);
    final partes = <String>[];
    if (eco != null) {
      partes.add(eco < 40 ? 'Estado ativo na economia' : eco <= 60 ? 'moderado econômico' : 'liberal econômico');
    }
    if (soc != null) {
      partes.add(soc < 40 ? 'progressista social' : soc <= 60 ? 'moderado social' : 'conservador social');
    }
    String? sintese;
    if (eco != null && soc != null) {
      if (eco > 60 && soc < 40) sintese = 'Liberal-progressista';
      if (eco > 60 && soc > 60) sintese = 'Conservador liberal';
      if (eco < 40 && soc < 40) sintese = 'Progressista com Estado ativo';
      if (eco < 40 && soc > 60) sintese = 'Conservador com Estado ativo';
      if (eco >= 40 && eco <= 60 && soc >= 40 && soc <= 60) sintese = 'Centrista';
    }
    final la = eixos['liberdade_autoridade'];
    if (la != null && la.peso >= 2) {
      if (la.pct < 35) partes.add('com ênfase em liberdades individuais');
      if (la.pct > 65) partes.add('com ênfase em ordem e autoridade');
    }
    final base = indice != null ? classeGeral(indice) : null;
    final desc = partes.isEmpty ? '' : _juntar(partes);
    if (base == null) return desc.isEmpty ? 'Perfil institucional' : _capitalizar(desc);
    if (desc.isEmpty) return base;
    return sintese != null ? '$base — $sintese ($desc)' : '$base — $desc';
  }

  String _juntar(List<String> p) {
    if (p.length == 1) return p.first;
    final ultimos = p.last.startsWith('com ') ? p.removeLast() : null;
    final base = p.length == 1 ? p.first : '${p.sublist(0, p.length - 1).join(', ')} e ${p.last}';
    return ultimos == null ? base : '$base, $ultimos';
  }

  String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  ResultadoTeste calcular(TesteModel teste, Map<String, String> respostas, Map<String, Eixo> defs) {
    final eixos = pontuarEixos(teste, respostas);
    double total = 0, min = 0, max = 0;
    for (final s in eixos.values) {
      total += s.bruto;
      min += s.minimo;
      max += s.maximo;
    }
    final indice = indiceGeral(eixos, defs);
    return ResultadoTeste(
      testeId: teste.id,
      criadoEm: DateTime.now(),
      pontuacaoTotal: total,
      pontuacaoMin: min,
      pontuacaoMax: max,
      indiceGeral: indice,
      classificacao: classeGeral(indice),
      rotuloDescritivo: rotuloDescritivo(eixos, defs),
      eixos: eixos,
      respostas: Map.of(respostas),
    );
  }

  /// Consolida os resultados mais recentes de cada teste (um por teste).
  Map<String, EixoScore> consolidar(Iterable<ResultadoTeste> ultimos) {
    final out = <String, EixoScore>{};
    for (final r in ultimos) {
      r.eixos.forEach((id, s) => out[id] = out.containsKey(id) ? out[id]!.somar(s) : s);
    }
    return out;
  }

  AnaliseResultado analisar(Map<String, EixoScore> eixos, Map<String, Eixo> defs, {TesteModel? teste, Map<String, String>? respostas}) {
    final fortes = <String>[];
    final diverg = <String>[];
    eixos.forEach((id, s) {
      final d = defs[id];
      if (d == null) return;
      final dist = (s.pct - 50).abs();
      if (dist >= 25 && s.peso >= 2) {
        fortes.add('${d.nome}: posição consistente, com tendência a "${s.pct < 50 ? d.poloA : d.poloB}" (${s.pct.round()}%).');
      }
      if (s.valores.length >= 3) {
        final hasA = s.valores.any((v) => v <= 1.5);
        final hasB = s.valores.any((v) => v >= 3.5);
        if (hasA && hasB) {
          diverg.add('${d.nome}: há respostas em direções opostas (algumas próximas de "${d.poloA}", outras de "${d.poloB}"). Isso é comum e indica uma visão que varia conforme o tema.');
        }
      }
    });
    final eco = _media(eixos, ['economia', 'papel_estado']);
    final soc = _media(eixos, ['direitos_civis', 'religiao_estado', 'seguranca']);
    if (eco != null && soc != null && (eco - soc).abs() >= 30) {
      diverg.add('Suas posições econômicas e sociais apontam para lados diferentes da escala tradicional. Por isso a classificação geral de esquerda–direita resume pouco o seu perfil; observe os eixos separadamente.');
    }
    if (fortes.isEmpty) fortes.add('Seu perfil é equilibrado: nenhum eixo concentra posições extremas.');

    final aproxA = <String>{};
    final aproxB = <String>{};
    if (teste != null && respostas != null) {
      for (final p in teste.perguntas) {
        final alt = p.alternativa(respostas[p.id]);
        if (alt == null) continue;
        alt.pontuacao.forEach((eixo, pe) {
          final d = defs[eixo];
          if (d == null || !d.entraNoIndiceGeral) return;
          final tema = p.tema ?? d.nome;
          if (pe.pontos <= 2) aproxA.add(tema);
          if (pe.pontos >= 3) aproxB.add(tema);
        });
      }
    }

    final indice = indiceGeral(eixos, defs);
    final classe = classeGeral(indice);
    final explic = indice == null
        ? 'Este teste mede eixos que não se encaixam na escala esquerda–direita. Veja abaixo sua posição em cada eixo.'
        : 'Com base nas suas respostas, sua posição estimada na escala geral é "$classe" '
            '(índice ${indice.round()} de 0 a 100, em que 0 representa o extremo associado à esquerda e 100 o associado à direita, '
            'segundo convenções usuais da ciência política). Essa classificação é uma simplificação: '
            'o mais informativo é observar cada eixo separadamente.';
    return AnaliseResultado(
      pontosFortes: fortes,
      divergencias: diverg,
      aproximaA: aproxA.toList(),
      aproximaB: aproxB.toList(),
      explicacao: explic,
    );
  }

  /// Texto neutro para compartilhamento.
  String textoCompartilhamento(String rotulo, {String? titulo}) =>
      'Meu resultado no Radar Político${titulo != null ? ' ($titulo)' : ''} foi: $rotulo. '
      'Este resultado é uma estimativa baseada em minhas respostas e não representa apoio a partidos ou candidatos.';
}
