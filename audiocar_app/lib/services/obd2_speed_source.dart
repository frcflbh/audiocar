import 'dart:async';
import 'dart:math';

import 'speed_source.dart';

/// Stub do módulo OBD2 (Seção 7 da RFP).
///
/// Implementa a mesma interface [SpeedSource] do GPS, validando a arquitetura
/// de abstração (Seção 10): trocar a origem do dado não afeta áudio nem UI.
///
/// Esta versão **simula** uma conexão ELM327 (Bluetooth/Wi-Fi) e a leitura dos
/// PIDs padrão. Para o produto real (Fase 3), substituir a camada de transporte
/// por um socket Bluetooth/Wi-Fi enviando comandos AT/PID ELM327 — a interface
/// pública desta classe permanece a mesma.
///
/// PIDs OBD-II relevantes (Modo 01):
///   0x0D  → Velocidade do veículo (km/h)   [usado aqui]
///   0x0C  → RPM do motor
///   0x11  → Posição do acelerador
///   0x04  → Carga calculada do motor
class Obd2SpeedSource implements SpeedSource {
  final StreamController<SpeedSample> _controller =
      StreamController<SpeedSample>.broadcast();

  Timer? _pollTimer;
  bool _connected = false;
  final Random _rng = Random();

  /// Estado simulado do "veículo" para gerar leituras plausíveis.
  double _simSpeed = 0;
  double _simTarget = 0;

  bool get isConnected => _connected;

  @override
  Stream<SpeedSample> get stream => _controller.stream;

  /// Simula o handshake ELM327: `ATZ`, `ATE0`, `ATSP0`, etc.
  /// No produto real, abrir o socket BT/Wi-Fi e validar a resposta "ELM327".
  @override
  Future<bool> prepare() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _connected = true; // troque por verificação real do adaptador
    return _connected;
  }

  /// Inicia o polling dos PIDs (~5 Hz, típico de adaptadores ELM327).
  @override
  Future<void> start() async {
    if (!_connected) {
      final ok = await prepare();
      if (!ok) return;
    }
    await stop();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _stepSimulation();
      // No real: enviar "010D\r", ler resposta "41 0D XX" e converter XX.
      _controller.add(SpeedSample(_simSpeed, SpeedOrigin.obd2));
    });
  }

  /// Evolui a velocidade simulada de forma suave, com alvos aleatórios,
  /// imitando aceleração/desaceleração reais lidas da ECU.
  void _stepSimulation() {
    if (_rng.nextDouble() < 0.03) {
      _simTarget = _rng.nextDouble() * 160; // novo alvo 0..160 km/h
    }
    _simSpeed += (_simTarget - _simSpeed) * 0.08;
    if (_simSpeed < 0.2) _simSpeed = 0;
  }

  @override
  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _connected = false;
    _controller.close();
  }
}
