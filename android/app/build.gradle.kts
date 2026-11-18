import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase (Auth + Firestore): el plugin de servicios de Google solo se aplica si
// existe `android/app/google-services.json`. Sin ese archivo la app compila y corre
// igual en modo sin conexión (USE_OFFLINE_FALLBACK=true). El classpath se declara,
// también de forma condicional, en `android/build.gradle.kts`.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Firma de release: si existe `android/key.properties` (fuera de Git) se firma con
// ese almacén; si no, se usa la clave de depuración para que `flutter build apk
// --release` produzca un APK instalable para compartir y probar.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "co.edu.javeriana.pontimaps_app"
    // permission_handler_android exige compilar contra API 37; compileSdk no cambia
    // el comportamiento en ejecución (eso lo define targetSdk).
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "co.edu.javeriana.pontimaps_app"
        // Android 10 (API 29) o superior. Firebase exige al menos API 23.
        // `compileSdk` y `targetSdk` siguen la versión de Flutter (API 35 o más).
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                // Clave de depuración: sirve para probar y compartir el APK, no para Play Store.
                signingConfigs.getByName("debug")
            }
            // Reglas de R8 para `flutter_map` y Firebase (ver proguard-rules.pro).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
