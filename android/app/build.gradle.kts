plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.carmen.pocket_claw"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.carmen.pocket_claw"
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

    // Force the APK to contain ONLY arm64-v8a native libraries.
    // Flutter's --target-platform flag only controls the Dart snapshot
    // (libapp.so) — plugin AARs bundle libs for all ABIs regardless.
    // Explicit excludes here strip armeabi-v7a (~19 MB) and x86_64
    // (~52 MB) that your phone will never execute.
    //
    // Also strip unused flutter_gemma/MediaPipe native libs for
    // features we do not use (image generation, Gecko embeddings,
    // vector store). Saves another ~48 MB.
    //
    // If any engine feature breaks at runtime, remove the offending
    // line and rebuild.
    packaging {
        jniLibs {
            excludes += listOf(
                "lib/armeabi-v7a/**",
                "lib/x86/**",
                "lib/x86_64/**",
                "**/libimagegenerator_gpu.so",
                "**/libmediapipe_tasks_vision_image_generator_jni.so",
                "**/libgecko_embedding_model_jni.so",
                "**/libsqlite_vector_store_jni.so",
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
