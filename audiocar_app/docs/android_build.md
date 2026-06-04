# Build Android (APK/AAB)

Estado: **ambiente Android 100% configurado**; falta apenas executar o build do
Gradle, que **não roda neste ambiente sandbox** (o JVM não consegue abrir o
`Selector`/self-pipe de loopback NIO que o daemon do Gradle exige — falha com
"Unable to establish loopback connection", reproduzível até com um
`Selector.open()` mínimo). Numa máquina/CI normal, os passos abaixo concluem.

## Já configurado nesta máquina
- JDK 17: `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`
- Android SDK: `C:\Android\sdk` (platform-tools, platforms;android-36, build-tools;36.0.0, licenças aceitas)
- Flutter apontado: `flutter config --android-sdk C:\Android\sdk --jdk-dir <jdk17>`
- `AndroidManifest.xml`: permissões INTERNET, ACCESS_FINE/COARSE_LOCATION, BLUETOOTH_SCAN/CONNECT
- `build.gradle.kts`: `minSdk = 24` (exigido pelo flutter_soloud)

## Passos para gerar o APK
```bash
cd audiocar_app
flutter build apk --release
# ou App Bundle para a Play Store:
flutter build appbundle --release
```

### NDK (flutter_soloud)
O `flutter_soloud` tem código nativo C++ e exige **NDK + CMake**. Na primeira
build o Gradle indica a versão exata. Instale com:
```bash
%ANDROID_SDK%\cmdline-tools\latest\bin\sdkmanager "ndk;<versao_indicada>" "cmake;3.22.1"
```
(ex.: `ndk;27.0.12077973`). O `ndkVersion` é resolvido por `flutter.ndkVersion`
em `android/app/build.gradle.kts`; ajuste se o build pedir uma específica.

## Assinatura (release)
Hoje o release usa a **debug key** (placeholder do template). Para publicar:
1. Gere um keystore: `keytool -genkey -v -keystore audiocar.jks -keyalg RSA -keysize 2048 -validity 10000 -alias audiocar`
2. Crie `android/key.properties` com as credenciais (NÃO versionar).
3. Configure `signingConfigs` em `android/app/build.gradle.kts`.
4. Defina um `applicationId` próprio (hoje `com.example.audiocar_app`).

## Artefato
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`
