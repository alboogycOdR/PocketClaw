plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.carmen.clawcommander"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13113456"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    externalNativeBuild {
        cmake {
            version = "3.31.0"
        }
    }

    defaultConfig {
        applicationId = "com.carmen.clawcommander"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Ship only arm64-v8a. 99% of modern Android devices use this.
        // Saves ~71 MB by excluding armeabi-v7a (legacy 32-bit) and
        // x86_64 (emulators only).
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    flavorDimensions += "app"
    productFlavors {
        create("claw") {
            dimension = "app"
        }
        create("hermes") {
            dimension = "app"
            applicationId = "com.carmen.hermescommander"
        }
    }

    // Force the APK to contain ONLY arm64-v8a native libraries.
    // Flutter's --target-platform flag only controls the Dart snapshot
    // (libapp.so) — plugin AARs bundle libs for all ABIs regardless.
    // Explicit excludes here strip armeabi-v7a (~19 MB) and x86_64
    // (~52 MB) that your phone will never execute.
    //
    // flutter_gemma-specific excludes (MediaPipe/LiteRT/Gecko libs) were
    // dropped along with the flutter_gemma dependency itself.
    packaging {
        jniLibs {
            keepDebugSymbols += listOf("**/*.so")
            excludes += listOf(
                "lib/armeabi-v7a/**",
                "lib/x86/**",
                "lib/x86_64/**",
            )
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

dependencies {
    implementation(project(":android_intent_plus"))
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
