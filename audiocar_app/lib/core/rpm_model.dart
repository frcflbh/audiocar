import 'engine_profile.dart';

/// Converte velocidade (km/h) em RPM estimado usando um câmbio virtual.
///
/// Requisito 4.2 da RFP: "Conversão de velocidade → RPM estimado".
/// Agora é **configurável por perfil de motor** (banco "Sons de Motores"):
/// idle/redline/marchas vêm do [EngineProfile] selecionado.
///
/// A arquitetura permite, futuramente, substituir o RPM estimado pelo RPM real
/// vindo do OBD2 (Requisito 7.4) sem alterar a camada de áudio/UI.
class RpmModel {
  // Valores padrão (também usados pelos testes).
  static const double idleRpm = 900;
  static const double redlineRpm = 6800;
  static const double maxRpm = 7200;
  static const List<double> defaultGearTopSpeed = [25, 50, 80, 115, 160, 220];

  final double idle;
  final double redline;
  final double maxRpmValue;
  final List<double> gearTopSpeed;

  RpmModel({
    double? idle,
    double? redline,
    double? maxRpm,
    List<double>? gearTopSpeed,
  })  : idle = idle ?? idleRpm,
        redline = redline ?? redlineRpm,
        maxRpmValue = maxRpm ?? RpmModel.maxRpm,
        gearTopSpeed = gearTopSpeed ?? defaultGearTopSpeed;

  /// Cria um modelo a partir de um perfil do banco "Sons de Motores".
  factory RpmModel.fromProfile(EngineProfile p) => RpmModel(
        idle: p.idleRpm,
        redline: p.redlineRpm,
        maxRpm: p.maxRpm,
        gearTopSpeed: p.gearTopSpeedKmh,
      );

  int get gearCount => gearTopSpeed.length;

  /// Marcha atual (1..N) para uma dada velocidade.
  int gearForSpeed(double kmh) {
    for (int i = 0; i < gearTopSpeed.length; i++) {
      if (kmh <= gearTopSpeed[i]) return i + 1;
    }
    return gearTopSpeed.length;
  }

  /// RPM estimado para a velocidade informada.
  double rpmForSpeed(double kmh) {
    if (kmh <= 0.5) return idle;
    final gear = gearForSpeed(kmh);
    final double low = gear == 1 ? 0.0 : gearTopSpeed[gear - 2];
    final double high = gearTopSpeed[gear - 1];
    final double span = (high - low).clamp(1.0, double.infinity);
    final double t = ((kmh - low) / span).clamp(0.0, 1.0);
    final double rpm = idle + t * (redline - idle);
    return rpm.clamp(idle, maxRpmValue);
  }

  /// Aceleração (0..1) usada para modular o volume do áudio,
  /// proporcional ao quanto o RPM está acima da marcha lenta.
  double throttleForRpm(double rpm) {
    final double t = (rpm - idle) / (redline - idle);
    return t.clamp(0.0, 1.0);
  }
}
