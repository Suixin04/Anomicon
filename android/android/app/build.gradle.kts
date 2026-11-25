import java.io.File

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadKeyStore = providers.environmentVariable("ANOMICON_UPLOAD_KEYSTORE")
val uploadStorePassword = providers.environmentVariable("ANOMICON_UPLOAD_STORE_PASSWORD")
val uploadKeyAlias = providers.environmentVariable("ANOMICON_UPLOAD_KEY_ALIAS")
val uploadKeyPassword = providers.environmentVariable("ANOMICON_UPLOAD_KEY_PASSWORD")

val validateReleaseUploadSigning = tasks.register("validateReleaseUploadSigning") {
    doLast {
        val storePath = uploadKeyStore.orNull
        if (storePath.isNullOrBlank() || uploadStorePassword.orNull.isNullOrBlank() ||
            uploadKeyAlias.orNull.isNullOrBlank() || uploadKeyPassword.orNull.isNullOrBlank()
        ) {
            throw GradleException(
                "Set ANOMICON_UPLOAD_KEYSTORE, ANOMICON_UPLOAD_STORE_PASSWORD, " +
                    "ANOMICON_UPLOAD_KEY_ALIAS and ANOMICON_UPLOAD_KEY_PASSWORD to build an Android release."
            )
        }
        val keyStore = File(storePath)
        if (!keyStore.isAbsolute || !keyStore.isFile) {
            throw GradleException("ANOMICON_UPLOAD_KEYSTORE must point to an existing absolute file path.")
        }
    }
}

tasks.configureEach {
    if (name == "preReleaseBuild" || name == "validateSigningRelease") {
        dependsOn(validateReleaseUploadSigning)
    }
}

android {
    namespace = "com.suixin.anomicon"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.suixin.anomicon"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            storeFile = uploadKeyStore.orNull?.let(::File)
            storePassword = uploadStorePassword.orNull
            keyAlias = uploadKeyAlias.orNull
            keyPassword = uploadKeyPassword.orNull
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("upload")
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
