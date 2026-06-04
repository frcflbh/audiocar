import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Carrega credenciais de assinatura de android/key.properties (NÃO versionado).
// Se o arquivo não existir, o release cai para a debug key (build local segue).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // namespace = pacote do código gerado/MainActivity (mantém o do template).
    // O applicationId (ID publicado na store) é definido separadamente abaixo.
    namespace = "com.example.audiocar_app"
    compileSdk = flutter.compileSdkVersion
    // NDK fixado: flutter_soloud tem código nativo (C++). Mantém builds locais e
    // de CI determinísticos. Ajuste se a sua versão do Flutter exigir outra.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.audiocar.app"
        // minSdk 24: requerido pelo flutter_soloud (áudio nativo) e compatível
        // com flutter_blue_plus / webview do 3D.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Usa a chave de release quando key.properties existe; caso contrário,
            // usa a debug key para que `flutter build` ainda funcione localmente.
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
