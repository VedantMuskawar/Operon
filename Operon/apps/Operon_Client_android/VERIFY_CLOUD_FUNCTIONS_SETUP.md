# Verify Cloud Functions Setup

Since the platform channel error persists after clean rebuild, let's verify the setup step by step.

## Step 1: Verify Dependency in pubspec.lock

```bash
cd apps/Operon_Client_android
grep -A 5 "cloud_functions:" pubspec.lock
```

Should show:
```
cloud_functions:
  dependency: "direct main"
  description:
    name: cloud_functions
    ...
```

## Step 2: Verify Native Dependency in build.gradle.kts

Check `android/app/build.gradle.kts` line 67 should have:
```kotlin
implementation("com.google.firebase:firebase-functions-ktx")
```

## Step 3: Verify Gradle Sync

In Android Studio:
1. Open `android/app/build.gradle.kts`
2. Click the "Sync Now" banner at the top (if it appears)
3. Or go to **File → Sync Project with Gradle Files**
4. Check for any sync errors in the Build output

## Step 4: Check Build Output for Plugin Registration

When building, check the build output for:
- `cloud_functions` plugin being registered
- No errors about missing Firebase dependencies

## Step 5: Verify Firebase Initialization

The app should initialize Firebase in `main.dart` BEFORE creating repositories:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

This happens in `main.dart` before `runApp()` is called, which is correct.

## Step 6: Try Manual Plugin Registration (if needed)

If the plugin still doesn't work, you can try explicitly registering it in `MainActivity.kt`:

```kotlin
import io.flutter.plugins.GeneratedPluginRegistrant

override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    
    // ... existing code ...
}
```

But this should already be handled automatically by Flutter.

## Step 7: Check for Version Conflicts

Verify cloud_functions version compatibility:
- `cloud_functions: ^4.6.5` in pubspec.yaml
- `firebase-functions-ktx` comes from `firebase-bom:33.6.0` (should be compatible)

## Step 8: Alternative - Try Default Instance First

If region-specific instance fails, we can try default instance as a test:

In `app.dart`, temporarily change:
```dart
functions: FirebaseFunctions.instance, // Instead of instanceFor(region: ...)
```

If this works, the issue is with region-specific initialization.

## Step 9: Check Logcat for Detailed Errors

When running the app and trying to generate DM, check Android Logcat for:
- Any Firebase initialization errors
- Plugin registration errors
- Network permission errors
- Missing class errors

Run:
```bash
adb logcat | grep -i "firebase\|cloud.*function\|plugin"
```

## Step 10: Verify google-services.json

Make sure `android/app/google-services.json` exists and is valid:
```bash
cat android/app/google-services.json | head -20
```

Should show valid JSON with Firebase project configuration.

