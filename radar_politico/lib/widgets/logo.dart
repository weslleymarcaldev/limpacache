import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logo neutro: círculos concêntricos de radar com um ponteiro, em tons de ardósia.
class LogoRadar extends StatelessWidget {
  final double tamanho;
  const LogoRadar({super.key, this.tamanho = 96});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Logotipo do Radar Político',
        image: true,
        child: CustomPaint(size: Size.square(tamanho), painter: _RadarPainter(Theme.of(context).colorScheme)),
      );
}

class _RadarPainter extends CustomPainter {
  final ColorScheme cs;
  _RadarPainter(this.cs);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = cs.primaryContainer);
    final anel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .05
      ..color = cs.primary.withValues(alpha: .55);
    for (final f in [.75, .5, .25]) {
      canvas.drawCircle(c, r * f, anel);
    }
    final setor = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 0,
        colors: [cs.primary.withValues(alpha: 0), cs.primary.withValues(alpha: .7)],
      ).createShader(Rect.fromCircle(center: c, radius: r * .82));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * .82), -math.pi / 2, math.pi / 2, true, setor);
    canvas.drawLine(c, c + Offset(r * .82, 0), Paint()..color = cs.primary..strokeWidth = r * .06..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, r * .08, Paint()..color = cs.primary);
    canvas.drawCircle(c + Offset(r * .35, -r * .45), r * .07, Paint()..color = cs.tertiary);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.cs != cs;
}
