# Vibes: ALPR & Text Recognition App

**Version:** 1.0.0 (Stable)
**Status:** Production Ready

##  Project Overview
"Vibes" is a Flutter-based mobile application designed for efficient text recognition and data logging. It utilizes **Google ML Kit** to scan License Plates (or generic text) and exports the data directly to an Excel sheet.

### Key Features
* **Live Text Recognition:** Uses Google ML Kit for offline, on-device OCR.
* **Smart Excel Export:** Automatically generates `.xlsx` files.
* **Whitelist Logic:**
    * *Whitelisted scans:* Populates the "Details" column with the registered name.
    * *Unknown scans:* Marks the "Details" column as "Data yet to be filled."
* **Optimized Image Handling:** Uses native `image_picker` quality settings (no external compression libraries) to prevent JVM crashes.

---

##  The "Domain-Based" Build System (Critical)
This project uses a custom build configuration to support **Android API 36 (Baklava)** and **Java 21**, while maintaining compatibility with older Flutter plugins.

**Prerequisites:**
* **Java:** You MUST run this with **JDK 21**. (Java 11 or 17 may fail).
* **Flutter SDK:** Latest Stable.
* **Android SDK:** API Level 36 (Baklava) installed via Android Studio.

### Known Configuration Overrides
Do **NOT** remove these specific settings in `android/app/build.gradle.kts` or `android/build.gradle.kts`:

1.  **The Path Bridge:**
    The build directory is forcibly set to `root/build/app` to fix Windows "Ghost APK" issues.
    ```kotlin
    project.layout.buildDirectory.set(file("${rootDir}/../build/app"))
    ```

2.  **The Dependency Harmonizer:**
    We force all plugins to compile with SDK 36 and Java 17 compatibility via `subprojects {}`.

3.  **The Crash Fix (Stylus/Keyboard):**
    We force `androidx.core` to version `1.13.1` to prevent `NoSuchMethodError` crashes on newer Android versions.
    ```kotlin
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
        }
    }
    ```

---

## How to Build & Run

### 1. Debug Mode (Development)
Run on a connected Android device:
```bash
flutter run

```

### 2. Build for Release (Production)

To generate the `.apk` file for distribution:

```bash
flutter build apk --release

```

**Output Location:**
Because of our custom pathing, the APK will be found here:
`Vibes/build/app/outputs/flutter-apk/app-release.apk`

---

## How to Install (For Users)

Since this app is not on the Play Store, users must follow these steps:

1. **Uninstall** any previous version of "Vibes" first.
2. Download the `app-release.apk` file.
3. Tap to Install.
4. **Security Warnings:**
* *Unknown Sources:* Go to Settings > Toggle "Allow from this source."
* *Play Protect:* If it says "Unrecognized Developer," tap **More Details** > **Install Anyway**.



---

##  Maintenance

If you encounter build errors after adding new plugins, reset the cache:

```bash
flutter clean
flutter pub get
# If Gradle is stuck:
cd android
./gradlew clean
cd ..
flutter run

```
## Developer's Note

This project was made possible by alot of Despair, Red bulls and Sleepless Nights.
Hopefully you get something new out of it 

Thank you !

