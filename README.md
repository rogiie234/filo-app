# Filo Android

Blank Flutter app for the Phase 0 toolchain and Redmi connection check.

## Run

```powershell
flutter pub get
flutter devices
flutter run -d <device-id>
```

## Check

```powershell
flutter analyze
```

The app displays `Hello World!`. Android application ID: `com.filo.filo`.
Minimum Android SDK: 26 (Android 8.0).

Keep `.env`, `google-services.json`, Firebase service account keys, and
signing credentials out of Git. Build output and local tool configuration
are also excluded by `.gitignore`.
