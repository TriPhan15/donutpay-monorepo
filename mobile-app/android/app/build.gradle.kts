import java.util.Properties
import java.io.FileInputStream
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
// Khóa ký bản release: máy dev đọc android/key.properties (không commit); CI không có file đó nên đọc biến môi trường
// ANDROID_KEYSTORE_PATH / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD (xem .github/workflows/ci.yml).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
fun releaseSigningValue(propertyKey: String, envKey: String): String? =
    keystoreProperties.getProperty(propertyKey)?.takeIf { it.isNotBlank() }
        ?: System.getenv(envKey)?.takeIf { it.isNotBlank() }
val releaseStoreFilePath = releaseSigningValue("storeFile", "ANDROID_KEYSTORE_PATH")
android {
    namespace = "dev.ledgermind.dev"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "dev.ledgermind.dev"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

  signingConfigs {
        getByName("debug") {
            val customDebugKeystore = file("../../keys/debug.keystore")
            if (customDebugKeystore.exists()) {
                storeFile = customDebugKeystore
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
        
        create("release") {
            keyAlias = releaseSigningValue("keyAlias", "ANDROID_KEY_ALIAS")
            keyPassword = releaseSigningValue("keyPassword", "ANDROID_KEY_PASSWORD")
            if (releaseStoreFilePath != null) {
                storeFile = file(releaseStoreFilePath)
            }
            storePassword = releaseSigningValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
        }
    }

    buildTypes {
        getByName("release") {
            if (releaseStoreFilePath != null) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.8.0"))
}
