# Anomicon Android Flutter

Flutter rewrite workspace for the Android target of the HarmonyOS-first Anomicon app.

## Current Scope

- Flutter app root lives in this `android/` directory.
- The generated Android platform shell lives under `android/android/`.
- Package/application ID is `com.suixin.anomicon`.
- The Android client has been rebuilt in Flutter while preserving the HarmonyOS showcase direction: black canvas, deep gray cards, blue emphasis, large Chinese headings, pill filters, and a translucent rounded bottom bar.
- The main Flutter surfaces now cover Explore, Catalog, Stories, Terminal, native article reading, settings, archive gallery, archive detail, favorites, history, reading progress, and local research profile generation.
- Offline/weak-network behavior is implemented with local content, image, and article caches that are preferred when network fetches fail.
- The 3D archive uses `model_viewer_plus` for real GLB display on Android. Classic bundled assets live in `assets/models/`; on-demand assets are downloaded, SHA-256 verified, cached, and removable.

## Build

Prerequisites:

- Flutter 3.47 or compatible SDK
- JDK 17
- Android SDK with a recent platform installed
- Gradle 8.14.4 and Android Gradle Plugin 8.11.1

Commands:

```bash
cd android
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is produced at:

```text
android/build/app/outputs/flutter-apk/app-debug.apk
```

If the Gradle wrapper cannot download its distribution in a restricted network, download `gradle-8.14.4-bin.zip` from a reachable mirror and run the same build through that local Gradle binary:

```bash
cd android/android
JAVA_HOME=/path/to/jdk17 ANDROID_HOME=/path/to/android-sdk /path/to/gradle-8.14.4/bin/gradle assembleDebug --no-daemon --max-workers=2
```

## Verification

Validated during the Flutter migration:

```bash
flutter analyze
flutter test
JAVA_HOME=/tmp/anomicon-jdk17 ANDROID_HOME=/tmp/anomicon-android-sdk /tmp/anomicon-gradle-8.14.4/gradle-8.14.4/bin/gradle assembleDebug --no-daemon --max-workers=2
```

The verified debug APK was generated at:

```text
android/build/app/outputs/flutter-apk/app-debug.apk
```
