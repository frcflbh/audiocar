import 'dart:async';

import 'speed_source.dart';

/// Fonte de velocidade controlada manualmente (modo demonstração).
///
/// Permite testar todo o pipeline (RPM → áudio → dashboard) em uma mesa,
/// sem deslocamento físico — útil também para a POC exigida na Seção 17.
class DemoSpeedSource implements SpeedSource {
  final StreamController<SpeedSample> _controller =
      StreamController<SpeedSample>.broadcast();
  double _current = 0;

  @override
  Stream<SpeedSample> get stream => _controller.stream;

  @override
  Future<bool> prepare() async => true;

  @override
  Future<void> start() async {
    _controller.add(SpeedSample(_current, SpeedOrigin.demo));
  }

  /// Define a velocidade simulada (km/h) — acionado pelo slider da UI.
  void setSpeed(double kmh) {
    _current = kmh.clamp(0, 260);
    _controller.add(SpeedSample(_current, SpeedOrigin.demo));
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {
    _controller.close();
  }
}
