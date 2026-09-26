plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "in.dagar.home_cameras"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "in.dagar.home_cameras"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "device"
    productFlavors {
        create("tv") {
            dimension = "device"
            manifestPlaceholders["leanbackRequired"] = "true"
            manifestPlaceholders["screenOrientation"] = "landscape"
        }
        create("mobile") {
            dimension = "device"
            applicationIdSuffix = ".mobile"
            manifestPlaceholders["leanbackRequired"] = "false"
            manifestPlaceholders["screenOrientation"] = "unspecified"
        }
    }

    buildTypes {
        release {
            // This first sideload build uses the development key, not a distribution identity.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("com.google.ai.edge.litert:litert:1.4.0")
}

tasks.matching { it.name == "preBuild" }.configureEach {
    doFirst {
        for (abi in listOf("arm64-v8a", "armeabi-v7a", "x86_64")) {
            check(file("src/main/jniLibs/$abi/libhome_recorder.so").isFile) {
                "Missing NVR native library for $abi. Run native/build.sh with Android NDK r27d on Linux first."
            }
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
