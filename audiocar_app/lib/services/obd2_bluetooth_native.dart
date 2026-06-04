import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'speed_source.dart';

/// Fábrica usada pelo conditional import em `obd2_bluetooth.dart`.
SpeedSource createObd2BluetoothSource() => Obd2BluetoothSource();

/// OBD2 via Bluetooth LE com adaptador ELM327 (Seção 7 da RFP).
///
/// Implementação de referência usando `flutter_blue_plus`. Muitos adaptadores
/// ELM327 BLE expõem um serviço serial:
///   service        = FFE0
///   characteristic = FFE1  (notify + write)
/// Ajuste os UUIDs conforme o seu adaptador, se necessário.
///
/// ATENÇÃO: NÃO testado com hardware nesta entrega (não havia adaptador físico
/// disponível). É código pronto para validação em campo. A interface é a mesma
/// [SpeedSource] do GPS/demo, então plugá-lo no app não exige mudanças na UI
/// nem na camada de áudio (Requisito 10 da RFP).
class Obd2BluetoothSource implements SpeedSource {
  static final Guid _serialService =
      Guid('0000ffe0-0000-1000-8000-00805f9b34fb');
  static final Guid _serialChar =
      Guid('0000ffe1-0000-1000-8000-00805f9b34fb');

  final StreamController<SpeedSample> _controller =
      StreamController<SpeedSample>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _serial;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _pollTimer;
  final StringBuffer _rx = StringBuffer();

  @override
  Stream<SpeedSample> get stream => _controller.stream;

  @override
  Future<bool> prepare() async {
    if (!await FlutterBluePlus.isSupported) return false;

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {
        // iOS não permite ligar via app; segue e tenta usar mesmo assim.
      }
    }

    final device = await _scanForElm();
    if (device == null) return false;

    // NOTA DE LICENCIAMENTO (Requisito 14 da RFP): o flutter_blue_plus 2.x é
    // dual-licenciado. `License.nonprofit` vale para uso pessoal/educacional/sem
    // fins lucrativos; o uso COMERCIAL exige a licença comercial (License.commercial)
    // do pacote. Avaliar/adquirir antes do lançamento.
    await device.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 10),
    );
    _device = device;

    final services = await device.discoverServices();
    for (final s in services) {
      if (s.uuid == _serialService) {
        for (final c in s.characteristics) {
          if (c.uuid == _serialChar) _serial = c;
        }
      }
    }
    _serial ??= _findSerialLike(services);
    if (_serial == null) return false;

    await _serial!.setNotifyValue(true);
    _notifySub = _serial!.onValueReceived.listen(_onData);

    await _initElm();
    return true;
  }

  /// Procura um adaptador cujo nome contenha "OBD" ou "ELM".
  Future<BluetoothDevice?> _scanForElm() async {
    final completer = Completer<BluetoothDevice?>();
    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName.toUpperCase();
        if (name.contains('OBD') || name.contains('ELM')) {
          if (!completer.isCompleted) completer.complete(r.device);
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    final device = await completer.future
        .timeout(const Duration(seconds: 9), onTimeout: () => null);
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    return device;
  }

  BluetoothCharacteristic? _findSerialLike(List<BluetoothService> services) {
    for (final s in services) {
      for (final c in s.characteristics) {
        final p = c.properties;
        if ((p.notify || p.indicate) &&
            (p.write || p.writeWithoutResponse)) {
          return c;
        }
      }
    }
    return null;
  }

  /// Sequência de inicialização típica do ELM327 + polling de velocidade.
  Future<void> _initElm() async {
    await _send('ATZ'); // reset
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _send('ATE0'); // echo off
    await _send('ATL0'); // linefeeds off
    await _send('ATSP0'); // seleção automática de protocolo

    // PID 010D = velocidade do veículo. Polling ~5 Hz.
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _send('010D'),
    );
  }

  @override
  Future<void> start() async {
    // A leitura já começa no prepare() via polling.
  }

  Future<void> _send(String cmd) async {
    final c = _serial;
    if (c == null) return;
    final bytes = Uint8List.fromList('$cmd\r'.codeUnits);
    await c.write(bytes, withoutResponse: c.properties.writeWithoutResponse);
  }

  void _onData(List<int> data) {
    _rx.write(String.fromCharCodes(data));
    final text = _rx.toString();
    // O ELM327 finaliza respostas com o prompt '>'.
    if (!text.contains('>')) return;
    _rx.clear();
    _parseSpeed(text);
  }

  /// Procura "41 0D XX" (resposta ao PID 010D) e converte XX (hex) em km/h.
  void _parseSpeed(String text) {
    final cleaned = text.replaceAll(RegExp(r'[\r\n>]'), ' ');
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    for (int i = 0; i + 2 < tokens.length; i++) {
      if (tokens[i] == '41' && tokens[i + 1] == '0D') {
        final kmh = int.tryParse(tokens[i + 2], radix: 16);
        if (kmh != null) {
          _controller.add(SpeedSample(kmh.toDouble(), SpeedOrigin.obd2));
        }
        return;
      }
    }
  }

  @override
  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _notifySub?.cancel();
    _scanSub?.cancel();
    _device?.disconnect();
    _controller.close();
  }
}
