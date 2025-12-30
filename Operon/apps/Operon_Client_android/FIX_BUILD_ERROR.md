# Fix Build Error: package_config.json Missing

## Error
```
.dart_tool/package_config.json does not exist.
Did you run this command from the same directory as your pubspec.yaml file?
```

## Solution

This error occurs when Flutter dependencies haven't been fetched. Run:

```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android
flutter pub get
```

This will:
1. Fetch all dependencies from `pubspec.yaml`
2. Generate `.dart_tool/package_config.json`
3. Generate plugin registrations

## If Still Failing

### Step 1: Clean and Re-fetch
```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android
flutter clean
flutter pub get
```

### Step 2: Verify Flutter Path
Make sure Flutter is in your PATH:
```bash
which flutter
flutter --version
```

### Step 3: Check pubspec.yaml
Verify `pubspec.yaml` is valid:
```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android
cat pubspec.yaml | head -20
```

### Step 4: Full Clean Rebuild
```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android

# Clean Flutter
flutter clean

# Clean Android
rm -rf android/app/build
rm -rf android/.gradle
rm -rf android/build
rm -rf build
rm -rf .dart_tool

# Re-fetch dependencies
flutter pub get

# Rebuild
flutter run
```

### Step 5: If Permission Errors
If you get permission errors with Flutter cache:
```bash
# Check Flutter cache permissions
ls -la /opt/homebrew/share/flutter/bin/cache/

# If needed, fix permissions (use sudo carefully)
sudo chown -R $(whoami) /opt/homebrew/share/flutter
```

## After Fixing

Once `flutter pub get` succeeds, you should see:
- `.dart_tool/package_config.json` created
- Dependencies downloaded
- Plugin registrations updated

Then try building again.

