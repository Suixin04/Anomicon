plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}
val uploadFile = providers.environmentVariable("ANOMICON_UPLOAD_KEYSTORE")
val uploadStorePassword = providers.environmentVariable("ANOMICON_UPLOAD_STORE_PASSWORD")
val uploadAlias = providers.environmentVariable("ANOMICON_UPLOAD_KEY_ALIAS")
val uploadPassword = providers.environmentVariable("ANOMICON_UPLOAD_KEY_PASSWORD")
android {
    namespace = "com.suixin.anomicon"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.suixin.anomicon"
        minSdk = 26
        targetSdk = 36
        versionName = "1.2.11"
        versionCode = providers.gradleProperty("versionCode").orElse("2").get().toInt()
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    signingConfigs.create("upload") {
        storeFile = uploadFile.orNull?.let(::file)
        storePassword = uploadStorePassword.orNull
        keyAlias = uploadAlias.orNull
        keyPassword = uploadPassword.orNull
    }
    buildTypes.getByName("release") { signingConfig = signingConfigs.getByName("upload") }
    buildFeatures { compose = true }
    androidResources { noCompress += "glb" }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
kotlin { jvmToolchain(17) }
val checkUpload by tasks.registering {
    doLast {
        check(listOf(uploadFile, uploadStorePassword, uploadAlias, uploadPassword).all { !it.orNull.isNullOrBlank() } && file(uploadFile.get()).isFile) {
            "Configure ANOMICON_UPLOAD_KEYSTORE, ANOMICON_UPLOAD_STORE_PASSWORD, ANOMICON_UPLOAD_KEY_ALIAS and ANOMICON_UPLOAD_KEY_PASSWORD for release signing"
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach { dependsOn(checkUpload) }
dependencies {
    implementation(project(":core:designsystem"))
    implementation(project(":core:data"))
    implementation(project(":feature:web"))
    implementation(project(":feature:archive3d"))
    implementation(platform(libs.compose.bom))
    implementation(libs.material)
    implementation(libs.navigation.suite)
    implementation(libs.adaptive.layout)
    implementation(libs.adaptive.navigation)
    implementation(libs.lifecycle.compose)
    implementation(libs.viewmodel.compose)
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.compose.animation:animation")
    implementation(libs.hilt.runtime)
    ksp(libs.hilt.compiler)
    implementation(libs.coil.compose)
    implementation(libs.coil.http)
}
