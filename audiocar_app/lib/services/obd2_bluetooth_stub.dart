import 'dart:async';

import 'speed_source.dart';

/// Fábrica para plataformas sem Bluetooth (web).
SpeedSource createObd2BluetoothSource() => _UnsupportedObd2Source();

/// OBD2 via Bluetooth não é suportado no navegador. [prepare] retorna false,
/// permitindo que a UI faça fallback graciosamente.
class _UnsupportedObd2Source implements SpeedSource {
  final StreamController<SpeedSample> _controller =
      StreamController<SpeedSample>.broadcast();

  @override
  Stream<SpeedSample> get stream => _controller.stream;

  @override
  Future<bool> prepare() async => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() => _controller.close();
}
