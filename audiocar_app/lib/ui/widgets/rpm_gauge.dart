import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme.dart';

/// Tacômetro / gauge de RPM independente, com redline visual
/// (Requisito 5.2 da RFP).
class RpmGauge extends StatelessWidget {
  final double value; // RPM
  final double max;
  final double redline;

  const RpmGauge({
    super.key,
    required this.value,
    this.max = 7200,
    this.redline = 6800,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          return SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              painter: _RpmPainter(value: value, max: max, redline: redline),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 28),
                      Text(
                        (value / 1000).toStringAsFixed(1),
                        style: const TextStyle(
                          color: CockpitColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'x1000 RPM',
                        style: TextStyle(
                            color: CockpitColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RpmPainter extends CustomPainter {
  final double value;
  final double max;
  final double redline;
  _RpmPainter({required this.value, required this.max, required this.redline});

  static const double _startAngle = 135 * pi / 180;
  static const double _sweep = 270 * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Trilha.
    final track = Paint()
      ..color = CockpitColors.gaugeTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweep, false, track);

    // Zona de redline.
    final redStart = _startAngle + _sweep * (redline / max);
    final redSweep = _sweep * (1 - redline / max);
    final redPaint = Paint()
      ..color = CockpitColors.redline.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, redStart, redSweep, false, redPaint);

    // Progresso.
    final pct = (value / max).clamp(0.0, 1.0);
    final inRed = value >= redline;
    final progress = Paint()
      ..color = inRed ? CockpitColors.redline : CockpitColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweep * pct, false, progress);

    // Marcações (0..7).
    final tick = Paint()
      ..color = CockpitColors.textMuted
      ..strokeWidth = 2;
    const divisions = 7;
    for (int i = 0; i <= divisions; i++) {
      final a = _startAngle + _sweep * (i / divisions);
      final outer = center + Offset(cos(a), sin(a)) * (radius - 2);
      final inner = center + Offset(cos(a), sin(a)) * (radius - 14);
      canvas.drawLine(inner, outer, tick);
    }

    // Ponteiro.
    final a = _startAngle + _sweep * pct;
    final needle = Paint()
      ..color = inRed ? CockpitColors.redline : CockpitColors.accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final tip = center + Offset(cos(a), sin(a)) * (radius - 18);
    canvas.drawLine(center, tip, needle);
    canvas.drawCircle(
      center,
      6,
      Paint()..color = inRed ? CockpitColors.redline : CockpitColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _RpmPainter old) =>
      old.value != value || old.max != max || old.redline != redline;
}
