import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme.dart';

/// Velocímetro circular animado (Requisito 5.2 da RFP).
class SpeedometerGauge extends StatelessWidget {
  final double value; // km/h
  final double max;

  const SpeedometerGauge({super.key, required this.value, this.max = 240});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _SpeedometerPainter(value: value, max: max),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 28),
              Text(
                value.round().toString(),
                style: const TextStyle(
                  color: CockpitColors.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'km/h',
                style: TextStyle(color: CockpitColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double value;
  final double max;
  _SpeedometerPainter({required this.value, required this.max});

  static const double _startAngle = 135 * pi / 180;
  static const double _sweep = 270 * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Trilha de fundo.
    final track = Paint()
      ..color = CockpitColors.gaugeTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _sweep,
      false,
      track,
    );

    // Arco de progresso.
    final pct = (value / max).clamp(0.0, 1.0);
    final progress = Paint()
      ..shader = const SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweep,
        colors: [CockpitColors.accent, Color(0xFF6FD0FF)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _sweep * pct,
      false,
      progress,
    );

    // Marcações.
    final tick = Paint()
      ..color = CockpitColors.textMuted
      ..strokeWidth = 2;
    const divisions = 12;
    for (int i = 0; i <= divisions; i++) {
      final a = _startAngle + _sweep * (i / divisions);
      final outer = center + Offset(cos(a), sin(a)) * (radius - 2);
      final inner = center + Offset(cos(a), sin(a)) * (radius - 14);
      canvas.drawLine(inner, outer, tick);
    }

    // Ponteiro.
    final a = _startAngle + _sweep * pct;
    final needle = Paint()
      ..color = CockpitColors.accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final tip = center + Offset(cos(a), sin(a)) * (radius - 18);
    canvas.drawLine(center, tip, needle);
    canvas.drawCircle(center, 6, Paint()..color = CockpitColors.accent);
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter old) =>
      old.value != value || old.max != max;
}
