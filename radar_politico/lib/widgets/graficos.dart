import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/eixo.dart';

/// Barra de um eixo, do polo A (esquerda da barra) ao polo B (direita).
class EixoBarra extends StatelessWidget {
  final Eixo eixo;
  final double pct;
  final double? comparacao;
  final String? rotuloComparacao;
  final String? legenda;
  final Color? cor;
  const EixoBarra({super.key, required this.eixo, required this.pct, this.comparacao, this.rotuloComparacao, this.legenda, this.cor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final c = cor ?? cs.primary;
    final desc = '${eixo.nome}: ${pct.round()} de 100, onde 0 é "${eixo.poloA}" e 100 é "${eixo.poloB}"'
        '${comparacao != null ? '. ${rotuloComparacao ?? 'Comparação'}: ${comparacao!.round()}' : ''}';
    return Semantics(
      label: desc,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(eixo.nome, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
              Text('${pct.round()}%', style: t.labelLarge?.copyWith(color: c, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            LayoutBuilder(builder: (ctx, bc) {
              final w = bc.maxWidth;
              return SizedBox(
                height: 22,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    top: 7, bottom: 7,
                    child: Container(decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
                  ),
                  Positioned(left: w / 2 - 1, top: 3, bottom: 3, child: Container(width: 2, color: cs.outlineVariant)),
                  if (comparacao != null)
                    Positioned(
                      left: (w * comparacao! / 100).clamp(0, w) - 7, top: 4,
                      child: Icon(Icons.change_history, size: 14, color: cs.tertiary),
                    ),
                  Positioned(
                    left: (w * pct / 100).clamp(0, w) - 9, top: 2,
                    child: Container(width: 18, height: 18, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: cs.surface, width: 2))),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text(eixo.poloA, style: t.bodySmall)),
              Expanded(child: Text(eixo.poloB, textAlign: TextAlign.right, style: t.bodySmall)),
            ]),
            if (legenda != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(legenda!, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
          ]),
        ),
      ),
    );
  }
}

/// Gráfico de radar dos eixos (0–100). Valores ausentes são omitidos.
class RadarEixos extends StatelessWidget {
  final Map<String, Eixo> eixos;
  final Map<String, double> valores;
  final Map<String, double>? comparacao;
  const RadarEixos({super.key, required this.eixos, required this.valores, this.comparacao});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ids = eixos.keys.where((k) => valores.containsKey(k)).toList();
    if (ids.length < 3) {
      return const SizedBox.shrink();
    }
    RadarDataSet ds(Map<String, double> v, Color c) => RadarDataSet(
          dataEntries: ids.map((k) => RadarEntry(value: (v[k] ?? 50).clamp(0, 100))).toList(),
          fillColor: c.withValues(alpha: .18),
          borderColor: c,
          entryRadius: 3,
          borderWidth: 2,
        );
    final desc = ids.map((k) => '${eixos[k]!.nome} ${valores[k]!.round()}').join(', ');
    return Semantics(
      label: 'Gráfico de radar com os eixos: $desc',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1.1,
          child: RadarChart(RadarChartData(
            dataSets: [
              ds(valores, cs.primary),
              if (comparacao != null) ds(comparacao!, cs.tertiary),
              // conjunto invisível fixa a escala em 0–100
              RadarDataSet(
                dataEntries: ids.map((_) => const RadarEntry(value: 100)).toList(),
                fillColor: Colors.transparent, borderColor: Colors.transparent, entryRadius: 0, borderWidth: 0),
              RadarDataSet(
                dataEntries: ids.map((_) => const RadarEntry(value: 0)).toList(),
                fillColor: Colors.transparent, borderColor: Colors.transparent, entryRadius: 0, borderWidth: 0),
            ],
            radarShape: RadarShape.polygon,
            tickCount: 4,
            ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 8),
            tickBorderData: BorderSide(color: cs.outlineVariant),
            gridBorderData: BorderSide(color: cs.outlineVariant),
            radarBorderData: BorderSide(color: cs.outline),
            titlePositionPercentageOffset: .12,
            titleTextStyle: TextStyle(fontSize: 11, color: cs.onSurface),
            getTitle: (i, angle) => RadarChartTitle(text: _curto(eixos[ids[i]]!.nome)),
          )),
        ),
      ),
    );
  }

  static String _curto(String n) => switch (n) {
        'Direitos civis e costumes' => 'Costumes',
        'Liberdade × autoridade' => 'Liberdade × ordem',
        'Religião e Estado' => 'Religião/Estado',
        'Papel do Estado' => 'Papel do Estado',
        _ => n,
      };
}

/// Linha da evolução do índice geral (0–100) ao longo das tentativas.
class EvolucaoLinha extends StatelessWidget {
  final List<double> valores;
  final List<String> rotulos;
  const EvolucaoLinha({super.key, required this.valores, required this.rotulos});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (valores.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Faça mais tentativas para acompanhar sua evolução ao longo do tempo.', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return Semantics(
      label: 'Gráfico de linha da evolução do índice geral: ${valores.map((v) => v.round()).join(', ')}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            minY: 0, maxY: 100,
            gridData: FlGridData(show: true, horizontalInterval: 20, drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant, strokeWidth: .6)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 20,
                  getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 22,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= rotulos.length || v != i.toDouble()) return const SizedBox.shrink();
                    return Text(rotulos[i], style: const TextStyle(fontSize: 10));
                  })),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < valores.length; i++) FlSpot(i.toDouble(), valores[i])],
                isCurved: false, color: cs.primary, barWidth: 3, dotData: const FlDotData(show: true),
              ),
            ],
          )),
        ),
      ),
    );
  }
}

/// Rosca com contagem por categoria.
class Rosca extends StatelessWidget {
  final Map<String, int> dados;
  final Map<String, String> rotulos;
  final Color Function(String) cor;
  const Rosca({super.key, required this.dados, required this.rotulos, required this.cor});

  @override
  Widget build(BuildContext context) {
    final total = dados.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    final desc = dados.entries.map((e) => '${rotulos[e.key] ?? e.key}: ${e.value}').join(', ');
    return Semantics(
      label: 'Gráfico de rosca. $desc',
      child: ExcludeSemantics(
        child: Row(children: [
          SizedBox(
            width: 130, height: 130,
            child: PieChart(PieChartData(
              centerSpaceRadius: 34,
              sectionsSpace: 2,
              sections: dados.entries
                  .map((e) => PieChartSectionData(value: e.value.toDouble(), color: cor(e.key), radius: 26, title: '${e.value}',
                      titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)))
                  .toList(),
            )),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in dados.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: cor(e.key), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${rotulos[e.key] ?? e.key} (${e.value})', style: const TextStyle(fontSize: 13))),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Barras verticais de compatibilidade por eixo (0–100).
class BarrasCompat extends StatelessWidget {
  final List<MapEntry<String, double>> dados;
  const BarrasCompat({super.key, required this.dados});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Gráfico de barras de compatibilidade: ${dados.map((e) => '${e.key} ${e.value.round()}%').join(', ')}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            maxY: 100, minY: 0,
            gridData: FlGridData(horizontalInterval: 25, drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant, strokeWidth: .6)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 25,
                  getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
                  getTitlesWidget: (v, m) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Transform.rotate(angle: -math.pi / 8,
                            child: Text(RadarEixos._curto(dados[v.toInt()].key).split(' ').first, style: const TextStyle(fontSize: 9))),
                      ))),
            ),
            barGroups: [
              for (var i = 0; i < dados.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: dados[i].value, width: 16, color: AppTheme.coresEixos[i % AppTheme.coresEixos.length],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                ]),
            ],
          )),
        ),
      ),
    );
  }
}
