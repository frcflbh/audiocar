import 'speed_source.dart';

// Seleciona a implementação por plataforma:
//   - Mobile/desktop (dart.library.io) → Bluetooth real (flutter_blue_plus)
//   - Web                               → stub não-suportado
import 'obd2_bluetooth_stub.dart'
    if (dart.library.io) 'obd2_bluetooth_native.dart' as impl;

/// Cria a fonte OBD2 via Bluetooth real onde houver suporte; caso contrário,
/// retorna uma fonte que apenas reporta indisponibilidade (web).
SpeedSource createObd2BluetoothSource() => impl.createObd2BluetoothSource();
