import 'dart:async';

/// Origem do dado de velocidade.
enum SpeedOrigin { gps, obd2, demo }

/// Amostra de velocidade entregue por uma [SpeedSource].
class SpeedSample {
  final double kmh;
  final SpeedOrigin origin;
  const SpeedSample(this.kmh, this.origin);
}

/// Abstração de fonte de velocidade.
///
/// Requisito 10 da RFP: "Arquitetura de abstração para fontes de dados
/// (GPS vs. OBD2)". GPS, OBD2 e o modo demo implementam esta mesma interface,
/// de modo que a camada de áudio e a UI independem da origem do dado.
abstract class SpeedSource {
  Stream<SpeedSample> get stream;

  /// Garante permissões/conexão necessárias. Retorna true se pronto.
  Future<bool> prepare();

  Future<void> start();
  Future<void> stop();
  void dispose();
}
