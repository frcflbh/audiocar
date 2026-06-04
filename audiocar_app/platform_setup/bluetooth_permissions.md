# Permissões Bluetooth (OBD2) — Seções 7 e 9 da RFP

Necessárias apenas para o módulo OBD2 via Bluetooth (`obd2_bluetooth_native.dart`).

## Android — `android/app/src/main/AndroidManifest.xml`
```xml
<!-- Android 12+ (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Android <= 11 -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
```

## iOS — `ios/Runner/Info.plist`
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>O AUDIOCAR usa Bluetooth para ler dados do veículo via adaptador OBD2 (ELM327).</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>O AUDIOCAR conecta-se ao adaptador OBD2 para obter RPM e velocidade reais.</string>
```

## Licenciamento (Requisito 14)
O `flutter_blue_plus` 2.x é dual-licenciado. O código usa `License.nonprofit`.
Para uso **comercial**, é necessário adquirir a licença comercial do pacote
e trocar para `License.commercial`.
