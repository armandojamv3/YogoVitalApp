plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Cloud Messaging. La versión se declara en settings.gradle.kts.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.yogovital.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications usa APIs modernas de java.time que no
        // existen en las versiones antiguas de Android. El "desugaring"
        // traduce esas llamadas en tiempo de compilación para que funcionen
        // igual en dispositivos viejos. Sin esto la compilación falla con
        // "requires core library desugaring to be enabled".
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Identificador definitivo de la app. Una vez publicada en Google
        // Play NO se puede cambiar: Play lo usa como identidad, así que
        // cambiarlo equivale a publicar una app distinta, sin descargas ni
        // reseñas. Debe coincidir con el paquete registrado en Firebase.
        applicationId = "com.yogovital.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Biblioteca que acompaña a isCoreLibraryDesugaringEnabled: contiene la
    // implementación de java.time y demás APIs modernas para Android antiguo.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
