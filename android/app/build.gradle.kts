import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties()
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
val releaseVersionFile = rootProject.file("release-version.properties")
val releaseVersionProperties = Properties()
if (releaseVersionFile.exists()) {
    releaseVersionProperties.load(FileInputStream(releaseVersionFile))
}
val pubspecFile = rootProject.projectDir.parentFile.resolve("pubspec.yaml")
val pubspecVersionMatch =
    Regex("""^version:\s*([0-9A-Za-z._-]+)\+([0-9]+)\s*$""", RegexOption.MULTILINE)
        .find(pubspecFile.readText())
val pubspecVersionName = pubspecVersionMatch?.groupValues?.getOrNull(1)
val pubspecVersionCode = pubspecVersionMatch?.groupValues?.getOrNull(2)

fun releaseVersionGuardMessage(): String? {
    val localVersionName = localProperties.getProperty("flutter.versionName")
    val localVersionCode = localProperties.getProperty("flutter.versionCode")
    val markerVersionName = releaseVersionProperties.getProperty("versionName")
    val markerVersionCode = releaseVersionProperties.getProperty("versionCode")
    val problems = mutableListOf<String>()

    if (pubspecVersionName == null || pubspecVersionCode == null) {
        problems += "pubspec.yaml version is missing or malformed."
    }
    if (!releaseVersionFile.exists()) {
        problems += "android/release-version.properties is missing."
    }
    if (localVersionName != pubspecVersionName || localVersionCode != pubspecVersionCode) {
        problems += "android/local.properties does not match pubspec.yaml."
    }
    if (markerVersionName != pubspecVersionName || markerVersionCode != pubspecVersionCode) {
        problems += "android/release-version.properties does not match pubspec.yaml."
    }

    if (problems.isEmpty()) {
        return null
    }

    return buildString {
        append("Release version metadata is out of sync. Run ./scripts/build_release_bundle.sh before building a release. ")
        append(problems.joinToString(" "))
    }
}

android {
    namespace = "com.madewithbestpractice.mise_en_pic"
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
        applicationId = "com.madewithbestpractice.mise_en_pic"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

tasks.configureEach {
    if (name.contains("Release", ignoreCase = true)) {
        doFirst {
            releaseVersionGuardMessage()?.let { message ->
                throw GradleException(message)
            }
        }
    }
}
