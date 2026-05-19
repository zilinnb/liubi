plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.liubi.liubi"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    signingConfigs {
        create("release") {
            storeFile = file("../liubi.jks")
            storePassword = "zzs5201314"
            keyAlias = "liubi"
            keyPassword = "zzs5201314"
        }
    }

    defaultConfig {
        applicationId = "com.liubi.liubi"
        minSdk = 24
        targetSdk = 36
        versionCode = 106
        versionName = "Beta 0.0.7"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
