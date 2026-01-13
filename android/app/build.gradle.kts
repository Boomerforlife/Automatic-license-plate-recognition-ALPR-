plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.security.alpr"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.security.alpr"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode?.toInt() ?: 1
        versionName = flutter.versionName ?: "1.0.0"
        multiDexEnabled = true
        
        // ndk {
        //     abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        // }
    }
    
    // Force specific versions to resolve lStar crash
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core-remoteviews:1.0.0-rc01")
            force("androidx.core:core:1.9.0") 
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
