plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("com.google.devtools.ksp")
}

android {
    namespace = "com.suixin.anomicon.core.data"
    compileSdk = 36
    defaultConfig { minSdk = 26; testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
kotlin { jvmToolchain(17) }
ksp { arg("room.schemaLocation", "$projectDir/schemas") }

dependencies {
    implementation("androidx.room:room-runtime:2.7.2")
    ksp("androidx.room:room-compiler:2.7.2")
    implementation("androidx.datastore:datastore-preferences:1.1.7")
    api("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("com.fasterxml.jackson.core:jackson-core:2.19.2")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
}
