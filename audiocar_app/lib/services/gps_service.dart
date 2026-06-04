import 'dart:async';
import 'package:geolocator/geolocator.dart';

import 'speed_source.dart';

/// Fonte de velocidade baseada em GPS (Requisito 4.1 da RFP).
///
/// Leitura contínua, atualização ~1 Hz ou superior (distanceFilter = 0),
/// precisão otimizada para navegação.
class GpsSpeedSource implements SpeedSource {
  final StreamController<SpeedSample> _controller =
      StreamController<SpeedSample>.broadcast();
  StreamSubscription<Position>? _sub;

  @override
  Stream<SpeedSample> get stream => _controller.stream;

  @override
  Future<bool> prepare() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<void> start() async {
    await stop();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        final double raw = pos.speed; // m/s
        final double mps = (raw.isNaN || raw < 0) ? 0.0 : raw;
        _controller.add(SpeedSample(mps * 3.6, SpeedOrigin.gps));
      },
      onError: (_) {
        // Em caso de erro de localização, reporta 0 sem derrubar o stream.
        _controller.add(const SpeedSample(0, SpeedOrigin.gps));
      },
    );
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
