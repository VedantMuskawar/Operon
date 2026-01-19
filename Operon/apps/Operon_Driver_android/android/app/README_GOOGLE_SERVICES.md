# Google Services Configuration (Operon Driver)

## Setup Instructions

1. Register a new Android app in Firebase Console for project `dash-6866c`
2. Use package name: `com.operondriverandroid.app`
3. Download `google-services.json` from Firebase Console
4. Place the downloaded `google-services.json` file in this directory (`android/app/`)
5. Generate Firebase options:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=dash-6866c --out=lib/config --platforms=android
```

This will update `lib/config/firebase_options.dart` with the correct Android app values.

## Note

The `google-services.json` file is required for Firebase to work on Android.
Do NOT commit this file to version control if it contains sensitive information.

