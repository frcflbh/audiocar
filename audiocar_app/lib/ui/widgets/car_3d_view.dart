import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import '../../theme.dart';

/// Visualização do veículo com rotação por toque (Requisitos 5.2 e 6 da RFP).
///
/// Carrega um modelo **glTF/GLB real** (Requisito 6.2) via `flutter_3d_controller`.
/// Caso o asset não esteja presente, faz *fallback* automático para um render
/// estilizado — assim o app roda mesmo sem o modelo. Para trocar o carro, basta
/// substituir o arquivo em [modelAsset] (declarado no pubspec.yaml).
class Car3DView extends StatefulWidget {
  final double rpm;
  final String modelAsset;

  const Car3DView({
    super.key,
    required this.rpm,
    this.modelAsset = 'assets/models/car.glb',
  });

  @override
  State<Car3DView> createState() => _Car3DViewState();
}

class _Car3DViewState extends State<Car3DView> {
  final Flutter3DController _controller = Flutter3DController();
  bool? _hasModel; // null = verificando

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    // No web, o model-viewer (renderer glTF via web component) é instável em
    // container pequeno (renderiza em branco). Usamos o render estilizado,
    // confiável e atraente. No MOBILE/desktop, o GLB real é renderizado
    // nativamente pelo flutter_3d_controller (onde os modelos baixados aparecem).
    if (kIsWeb) {
      if (mounted) setState(() => _hasModel = false);
      return;
    }
    try {
      await rootBundle.load(widget.modelAsset);
      if (mounted) setState(() => _hasModel = true);
    } catch (_) {
      if (mounted) setState(() => _hasModel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [CockpitColors.panel, CockpitColors.background],
          radius: 0.9,
        ),
      ),
    );

    if (_hasModel == null) {
      return Stack(
        fit: StackFit.expand,
        children: [bg, const Center(child: CircularProgressIndicator())],
      );
    }

    if (_hasModel == true) {
      // Modelo 3D real, com gestos de rotação nativos.
      return Stack(
        fit: StackFit.expand,
        children: [
          bg,
          Flutter3DViewer(
            controller: _controller,
            src: widget.modelAsset,
            progressBarColor: CockpitColors.accent,
            enableTouch: true,
          ),
        ],
      );
    }

    // Fallback estilizado (sem asset).
    return _StylizedCar(rpm: widget.rpm);
  }
}

/// Render estilizado de reserva, usado quando não há modelo GLB embarcado.
class _StylizedCar extends StatefulWidget {
  final double rpm;
  const _StylizedCar({required this.rpm});

  @override
  State<_StylizedCar> createState() => _StylizedCarState();
}

class _StylizedCarState extends State<_StylizedCar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idleSpin;
  double _dragAngle = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _idleSpin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _idleSpin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (_) => _dragging = true,
      onHorizontalDragUpdate: (d) =>
          setState(() => _dragAngle += d.delta.dx * 0.012),
      onHorizontalDragEnd: (_) => _dragging = false,
      child: AnimatedBuilder(
        animation: _idleSpin,
        builder: (context, _) {
          final double auto = _dragging ? 0 : _idleSpin.value * 2 * pi;
          final double angle = _dragAngle + auto;
          return Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [CockpitColors.panel, CockpitColors.background],
                radius: 0.9,
              ),
            ),
            child: Center(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateX(-0.35)
                  ..rotateY(angle),
                child: CustomPaint(
                  size: const Size(260, 110),
                  painter: _CarPainter(rpm: widget.rpm),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  final double rpm;
  _CarPainter({required this.rpm});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2A3442), Color(0xFF161C24)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path = Path()
      ..moveTo(w * 0.05, h * 0.70)
      ..lineTo(w * 0.16, h * 0.45)
      ..lineTo(w * 0.34, h * 0.30)
      ..lineTo(w * 0.62, h * 0.28)
      ..lineTo(w * 0.80, h * 0.42)
      ..lineTo(w * 0.95, h * 0.55)
      ..lineTo(w * 0.95, h * 0.70)
      ..close();
    canvas.drawPath(path, body);

    final glass = Paint()..color = CockpitColors.accent.withValues(alpha: 0.35);
    final cabin = Path()
      ..moveTo(w * 0.30, h * 0.45)
      ..lineTo(w * 0.40, h * 0.32)
      ..lineTo(w * 0.60, h * 0.31)
      ..lineTo(w * 0.66, h * 0.45)
      ..close();
    canvas.drawPath(cabin, glass);

    final glow = (rpm / 6800).clamp(0.0, 1.0);
    final head = Paint()
      ..color = Color.lerp(
        const Color(0xFF5A6472),
        const Color(0xFFFFE28A),
        glow,
      )!;
    canvas.drawCircle(Offset(w * 0.90, h * 0.52), 5, head);

    final tire = Paint()..color = const Color(0xFF0A0D11);
    final rim = Paint()..color = CockpitColors.textMuted;
    for (final cx in [w * 0.27, w * 0.74]) {
      canvas.drawCircle(Offset(cx, h * 0.74), 16, tire);
      canvas.drawCircle(Offset(cx, h * 0.74), 6, rim);
    }

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.92), width: w * 0.8, height: 14),
      shadow,
    );
  }

  @override
  bool shouldRepaint(covariant _CarPainter old) => old.rpm != rpm;
}
