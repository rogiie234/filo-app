import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningFile = rootProject.file("key.properties")
if (releaseSigningFile.isFile) {
    releaseSigningFile.inputStream().use { stream -> releaseSigningProperties.load(stream) }
}

android {
    namespace = "com.filo.filo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.filo.filo"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Version values come from pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseSigningProperties.getProperty("keyAlias")
            keyPassword = releaseSigningProperties.getProperty("keyPassword")
            storeFile = releaseSigningProperties.getProperty("storeFile")?.let { path -> file(path) }
            storePassword = releaseSigningProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

dependencies {
    // Match firebase_core 5.1.0; debug bridge unwraps the native registration cause.
    implementation(platform("com.google.firebase:firebase-bom:35.1.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("androidx.exifinterface:exifinterface:1.4.1")
    testImplementation("junit:junit:4.13.2")
}
