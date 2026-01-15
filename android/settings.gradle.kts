pluginManagement {
    val flutterSdkPath: String by settings

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    plugins {
        id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
        id("com.android.application") version "8.1.0" apply false
        id("org.jetbrains.kotlin.android") version "1.9.10" apply false
        id("com.google.gms.google-services") version "4.4.0" apply false
    }

    resolutionStrategy {
        eachPlugin {
            if (requested.id.namespace == "dev.flutter") {
                useModule("io.flutter:flutter-gradle-plugin:${requested.version}")
            }
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.10" apply false
}

include(":app")