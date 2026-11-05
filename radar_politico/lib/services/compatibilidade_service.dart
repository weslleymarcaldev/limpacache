import '../models/conteudo.dart';
import '../models/eixo.dart';

class CompatEixo {
  final Eixo eixo;
  final double usuario;
  final double candidato;
  const CompatEixo(this.eixo, this.usuario, this.candidato);
  double get compatibilidade => (100 - (usuario - candidato).abs()).clamp(0, 100).toDouble();
}

class ResultadoCompat {
  final Candidato candidato;
  final List<CompatEixo> eixos;
  const ResultadoCompat(this.candidato, this.eixos);

  double get geral => eixos.isEmpty
      ? 0
      : eixos.map((e) => e.compatibilidade).reduce((a, b) => a + b) / eixos.length;

  List<CompatEixo> get convergencias => eixos.where((e) => e.compatibilidade >= 70).toList();
  List<CompatEixo> get divergencias => eixos.where((e) => e.compatibilidade <= 40).toList();
  List<CompatEixo> get intermediarios =>
      eixos.where((e) => e.compatibilidade > 40 && e.compatibilidade < 70).toList();

  String get frase => geral >= 70
      ? 'Com base nas respostas informadas, há maior compatibilidade com as posições públicas declaradas deste político.'
      : geral >= 50
          ? 'Com base nas respostas informadas, há compatibilidade parcial com as posições públicas declaradas deste político.'
          : 'Com base nas respostas informadas, há menor compatibilidade com as posições públicas declaradas deste político.';
}

/// Compatibilidade por eixo = 100 − |usuário − candidato| (escala 0–100).
/// Apenas eixos com dado do usuário e do candidato entram no cálculo.
class CompatibilidadeService {
  const CompatibilidadeService();

  ResultadoCompat comparar(Map<String, double> usuario, Candidato c, Map<String, Eixo> defs, {Set<String>? eixosSelecionados}) {
    final lista = <CompatEixo>[];
    for (final d in defs.values) {
      if (eixosSelecionados != null && !eixosSelecionados.contains(d.id)) continue;
      final u = usuario[d.id];
      final v = c.eixos[d.id];
      if (u == null || v == null) continue;
      lista.add(CompatEixo(d, u, v));
    }
    return ResultadoCompat(c, lista);
  }

  /// Ordena por compatibilidade (estimativa). Nunca deve ser apresentado como ranking de "melhores".
  List<ResultadoCompat> ordenar(Map<String, double> usuario, List<Candidato> cs, Map<String, Eixo> defs, {Set<String>? eixosSelecionados}) {
    final l = cs.map((c) => comparar(usuario, c, defs, eixosSelecionados: eixosSelecionados)).toList();
    l.sort((a, b) => b.geral.compareTo(a.geral));
    return l;
  }
}
