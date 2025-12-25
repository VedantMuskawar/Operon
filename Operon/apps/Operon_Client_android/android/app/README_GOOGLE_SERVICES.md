# Google Services Configuration

## Setup Instructions

1. Register your Android app in Firebase Console for project `dash-6866c`
2. Download `google-services.json` from Firebase Console
3. Place the downloaded `google-services.json` file in this directory (`android/app/`)
4. Run FlutterFire CLI to generate Firebase options:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=dash-6866c --out=lib/config --platforms=android
   ```
5. This will update `lib/config/firebase_options.dart` with the correct Android app ID

## Note

The `google-services.json` file is required for Firebase to work on Android. 
Do NOT commit this file to version control if it contains sensitive information.

