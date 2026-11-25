plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.suixin.anomicon.archive3d"
    compileSdk = 36
    defaultConfig { minSdk = 26 }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin { jvmToolchain(17) }

dependencies {
    implementation(project(":core:designsystem"))
    implementation(platform(libs.compose.bom))
    implementation(libs.material)
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("io.github.sceneview:sceneview:2.3.0")
    testImplementation("junit:junit:4.13.2")
}
