
---
# 📜 Rules.md: Offline ALPR Gate System (2025)

## **1. Core Infrastructure Rules**

* **Offline First:** Strictly no `INTERNET` permission in `AndroidManifest.xml`.
* **Data Vault:** Use `sqflite` for all data persistence. No cloud databases.
* **Minimum SDK:** Set `minSdkVersion` to **21** in `android/app/build.gradle` (Required for ML Kit).
* **Privacy:** All license plate data and owner details must remain on the physical device.

---

## **2. ML & Vision Strategy (Option B)**

* **OCR Engine:** Use `google_mlkit_text_recognition` (On-device version).
* **Language Script:** Use `TextRecognitionScript.latin`.
* **Resolution:** Set camera to `ResolutionPreset.high` to ensure the text is sharp enough to read from a distance.
* **Filtering (The Regex):** Only process text that matches the Indian License Plate format:
> `r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,2}[0-9]{4}$'`
> *(Example: KA01MG1234 or DL3CA5678)*



---

## **3. UI & Experience Standards**

* **High Contrast:** Use **Dark Mode** with high-visibility colors (Neon Green for Pass, Bright Red for Alert). This is for gate guards working in harsh sunlight.
* **Thumb-Friendly:** Buttons must be large and placed in the bottom half of the screen for one-handed use while the guard holds the camera.
* **Real-time Feedback:** Use a full-screen "Flash" overlay to indicate a successful scan so the guard doesn't have to squint at small text.

---

## **4. Data Coordination**

* **Antigravity (Backend) Ownership:** * Responsible for `lib/data/`.
* Manages SQLite schemas and Excel I/O.
* Ensures `excel_service.dart` handles file permissions correctly.


* **Windsurf (Frontend) Ownership:**
* Responsible for `lib/presentation/` and `lib/logic/vision/`.
* Manages camera lifecycle and real-time OCR stream.
* Calls `DatabaseHelper` from the data layer to verify plates.



---

## **5. File Handling & Permissions**

* **Scoped Storage:** Exported Excel files must be saved to the public `Downloads` or `Documents` folder so the guard can find them to share later.
* **Permission Handler:** Always check for `Camera` and `Storage` permissions before launching the respective features.

---
