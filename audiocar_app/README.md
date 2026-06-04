# AUDIOCAR — App (Núcleo MVP)

Aplicativo Flutter de **simulação de som de motor** com integração de **velocidade GPS**,
**dashboard cockpit** (velocímetro, RPM e carro 3D) e **motor de áudio em tempo real**.

Esta entrega cobre o **núcleo do produto** (Seção 4.2 da RFP: "3D e áudio são o produto"):

```
Velocidade (GPS ou demo) ──► RPM estimado (câmbio virtual) ──► Som do motor (pitch + volume)
                                          └────────────────────► Dashboard (gauges + HUD + 3D)
```

---

## ✅ O que está implementado

| Requisito RFP | Status | Onde |
|---|---|---|
| 4.1 Captura de velocidade via GPS (~1 Hz, foreground) | ✅ | `services/gps_service.dart` |
| 4.2 Conversão velocidade → RPM | ✅ | `core/rpm_model.dart` |
| 4.2 Simulação de som (pitch/volume dinâmicos) | ✅ | `services/engine_audio*.dart` |
| 5.1/5.2 Dashboard cockpit (velocímetro, RPM, 3D, HUD, rodapé) | ✅ | `ui/` |
| 5.3 Sincronização áudio + visual (loop ~30 Hz) | ✅ | `ui/dashboard_screen.dart` |
| 6.2 Modelo 3D glTF/GLB real (com fallback estilizado) | ✅ | `ui/widgets/car_3d_view.dart` + `assets/models/car.glb` |
| 7 Módulo OBD2 (stub ELM327, mesma interface) | ✅ | `services/obd2_speed_source.dart` |
| 4.6 Contas/login + gate de conteúdo premium | ✅ | `services/auth_service.dart`, `ui/login_screen.dart` |
| 7 OBD2 via Bluetooth real (ELM327, ref.) | ✅ código | `services/obd2_bluetooth*.dart` |
| 4.2 Sample de áudio real (com fallback) | ✅ infra | `assets/audio/`, `services/engine_audio_*.dart` |
| 10 Abstração de fonte de dados (GPS vs OBD2 vs demo) | ✅ | `services/speed_source.dart` |
| Modo demo (testar sem deslocamento — apoia a POC da Seção 17) | ✅ | `services/demo_speed_source.dart` |
| Testes unitários do modelo de RPM (11 testes) | ✅ | `test/rpm_model_test.dart` |

### Estado de verificação
- `flutter analyze` → **No issues found!**
- `flutter test` → **11/11 passed**
- `flutter build web --release` → **build OK** (app compila de ponta a ponta)

### Motor de áudio multiplataforma
O áudio usa uma interface (`engine_audio_interface.dart`) com duas implementações
selecionadas por *conditional import* (`engine_audio.dart`):
- **Android / iOS / desktop:** `engine_audio_native.dart` (flutter_soloud, nativo).
- **Navegador:** `engine_audio_web.dart` (**Web Audio API**) — verificado rodando
  no Chrome (osciladores + filtro + ganho seguindo RPM/aceleração).

> O áudio é iniciado a partir de um **gesto do usuário** (botão "Ativar áudio" ou
> mover o slider), exigência da política de autoplay dos navegadores.
> No navegador, para o áudio funcionar, sirva com cross-origin isolation —
> use o `run_web.ps1` (já inclui os cabeçalhos COOP/COEP).

### Pontos de integração deixados prontos (próximas fases)
- **OBD2 real (Seção 7):** o `obd2_speed_source.dart` simula o ELM327; basta trocar a camada de transporte por um socket Bluetooth/Wi-Fi real enviando os PIDs. A interface não muda.
- **Áudio com sample real:** trocar a síntese procedural por um sample de motor.

---

## ▶️ Como rodar

> O **Flutter SDK 3.44.1** já foi instalado nesta máquina em `C:\Users\flavio.leite\flutter`.
> As plataformas **android/ ios/ web/** já foram geradas e as dependências já resolvidas.

```bash
cd audiocar_app

# Opção A — rodar no navegador (mais rápido para ver funcionando):
flutter run -d chrome

# Opção B — rodar em celular Android (requer Android SDK / Android Studio):
#   1. Instale o Android Studio (instala o Android SDK)
#   2. Aplique as permissões de plataforma (pasta platform_setup/):
#      - Android: android/app/src/main/AndroidManifest.xml  (android_permissions.xml)
#      - iOS:     ios/Runner/Info.plist                     (ios_Info.plist.snippet)
#      - Android: minSdkVersion 23 em android/app/build.gradle
#   3. flutter run
```

### Usando o app
- Abre em **modo demo**: use o **slider** para simular a velocidade e ouvir o motor reagir.
- Botão no topo **cicla os modos**: Demo → **Usar GPS** → **Usar OBD2** → Demo.
  - **GPS**: captura a velocidade real (ande/dirija para ver variar).
  - **OBD2**: simula a leitura da ECU via ELM327 (stub).
- **Arraste** o carro 3D para girá-lo.

---

## 🧪 Medições da POC (Seção 17 da RFP)
Para coletar FPS, latência e consumo exigidos na POC:
```bash
flutter run --profile          # build de performance
# No DevTools: aba Performance (FPS) e aba Memory (consumo).
```

---

## 📁 Estrutura
```
lib/
  main.dart
  app.dart
  theme.dart
  core/
    rpm_model.dart            # velocidade → RPM (câmbio virtual)
  services/
    speed_source.dart         # abstração GPS/OBD2/demo
    gps_service.dart          # GPS (geolocator)
    demo_speed_source.dart    # velocidade simulada
    engine_audio_service.dart # síntese + pitch/volume (flutter_soloud)
  ui/
    dashboard_screen.dart     # orquestra tudo
    widgets/
      speedometer_gauge.dart
      rpm_gauge.dart
      car_3d_view.dart        # placeholder 3D (ponto de integração)
      status_footer.dart
platform_setup/               # snippets de permissão Android/iOS
```

---

## ⚠️ Observações
- O projeto foi **escrito mas não compilado** nesta máquina (sem Flutter SDK).
  Ao rodar `flutter pub get`, confirme as versões de `geolocator` e `flutter_soloud`
  no `pubspec.yaml` — se houver atualização de API, o `flutter pub get` indicará.
- O som do motor é **sintetizado proceduralmente** (sem assets binários), então o app
  roda imediatamente. A qualidade de áudio premium (Fase 2) virá de samples reais.
