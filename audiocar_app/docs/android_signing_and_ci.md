# Assinatura de release + CI (GitHub Actions)

## 1. Gerar o keystore (uma vez)
```bash
keytool -genkey -v -keystore audiocar-release.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias audiocar
```
Guarde o `.jks` e as senhas em local seguro. **Nunca** versione o keystore nem o
`key.properties` (já estão no `.gitignore`).

## 2. Build local assinado
```bash
cp android/key.properties.example android/key.properties   # e preencha
# coloque o audiocar-release.jks em audiocar_app/ (storeFile=../audiocar-release.jks)
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release # build/app/outputs/bundle/release/app-release.aab
```
Sem `key.properties`, o release usa a **debug key** automaticamente (o build não quebra).

## 3. CI no GitHub Actions
Dois workflows (na raiz do repo, em `.github/workflows/`):

| Workflow | Quando roda | O que faz |
|---|---|---|
| `ci.yml` | push/PR em main | `flutter analyze` + `flutter test` |
| `android-release.yml` | tag `v*` ou disparo manual | instala NDK/CMake, assina e gera **APK + AAB** (artefatos; APK anexado à Release na tag) |

### Secrets necessários (Settings → Secrets and variables → Actions)
| Secret | Conteúdo |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | saída de `base64 -w0 audiocar-release.jks` |
| `ANDROID_STORE_PASSWORD` | senha do keystore |
| `ANDROID_KEY_ALIAS` | `audiocar` |
| `ANDROID_KEY_PASSWORD` | senha da chave |

> Sem os secrets, o `android-release.yml` ainda roda e gera artefatos **debug-signed**
> (útil para validar o pipeline antes de configurar a assinatura).

Para gerar o base64 do keystore:
```bash
base64 -w0 audiocar-release.jks > keystore.b64   # cole o conteúdo no secret
```

### Publicar uma versão
```bash
git tag v0.1.0 && git push origin v0.1.0
```
O workflow builda, assina e cria a Release com o APK anexado. O **AAB** fica como
artefato do run para subir na Play Console.

## 4. applicationId
- `applicationId = com.audiocar.app` (ID publicado) — ajuste se já estiver em uso na store.
- `namespace = com.example.audiocar_app` (pacote do código; mantido p/ não quebrar a MainActivity).

## Observação sobre o ambiente atual
O build do APK **não roda** na máquina sandbox de desenvolvimento (o JVM não consegue
abrir o `Selector`/loopback NIO que o Gradle exige). Estes workflows existem justamente
para gerar os artefatos **fora** desse ambiente — em runners limpos do GitHub.
