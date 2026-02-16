# Distribution Server Integration Guide

## ✅ Server Status

**Status:** 🟢 **ONLINE**  
**URL:** `http://localhost:3000`  
**Port:** `3000`  
**Running:** Node.js + Express  
**APK Hosted:** v1.0.1 (76 MB)  

## 📊 API Endpoints

### Check for Updates
```
GET http://localhost:3000/api/version/operon-client?currentBuild=1
```

**Response (Update Available):**
```json
{
  "success": true,
  "updateAvailable": true,
  "current": {
    "version": "1.0.1",
    "buildCode": 2,
    "releaseUrl": "http://localhost:3000/apks/operon-client-v1.0.1.apk",
    "releaseNotes": "Version 1.0.1 - Bug fixes and improvements..."
  }
}
```

### Download APK
```
GET http://localhost:3000/api/download/operon-client/1.0.1
```

### View Changelog
```
GET http://localhost:3000/api/changelog/operon-client
```

## 🔗 Flutter Integration

### 1. Update Check Implementation

Create a new service in your Flutter app:

```dart
// lib/data/services/app_update_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateService {
  final String serverUrl = 'http://localhost:3000';
  
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.parse(packageInfo.buildNumber);
      
      // Check for updates from server
      final response = await http.get(
        Uri.parse('$serverUrl/api/version/operon-client?currentBuild=$currentBuild'),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        if (json['updateAvailable'] == true) {
          final current = json['current'];
          return UpdateInfo(
            version: current['version'],
            buildCode: current['buildCode'],
            downloadUrl: current['releaseUrl'],
            releaseNotes: current['releaseNotes'],
            checksum: current['checksum'],
            mandatory: current['mandatory'] ?? false,
          );
        }
      }
    } catch (e) {
      print('Update check error: $e');
    }
    return null;
  }
}

class UpdateInfo {
  final String version;
  final int buildCode;
  final String downloadUrl;
  final String releaseNotes;
  final String checksum;
  final bool mandatory;
  
  UpdateInfo({
    required this.version,
    required this.buildCode,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.checksum,
    required this.mandatory,
  });
}
```

### 2. Add to Bloc/Provider

```dart
// lib/presentation/blocs/app_update/app_update_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

class AppUpdateEvent {}
class CheckUpdateEvent extends AppUpdateEvent {}
class UpdateDownloadStartedEvent extends AppUpdateEvent {}

class AppUpdateState {}
class UpdateUnavailableState extends AppUpdateState {}
class UpdateAvailableState extends AppUpdateState {
  final UpdateInfo updateInfo;
  UpdateAvailableState(this.updateInfo);
}
class UpdateDownloadingState extends AppUpdateState {
  final int progress; // 0-100
  UpdateDownloadingState(this.progress);
}

class AppUpdateBloc extends Bloc<AppUpdateEvent, AppUpdateState> {
  final AppUpdateService updateService;
  
  AppUpdateBloc(this.updateService) : super(UpdateUnavailableState()) {
    on<CheckUpdateEvent>((event, emit) async {
      final updateInfo = await updateService.checkForUpdate();
      if (updateInfo != null) {
        emit(UpdateAvailableState(updateInfo));
      } else {
        emit(UpdateUnavailableState());
      }
    });
  }
}
```

### 3. Show Update Dialog

```dart
// lib/presentation/widgets/update_dialog.dart
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  
  const UpdateDialog({required this.updateInfo});
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update Available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${updateInfo.version} is available'),
            SizedBox(height: 12),
            Text('Changes:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(updateInfo.releaseNotes),
            if (updateInfo.mandatory)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'This update is required to continue using the app.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (!updateInfo.mandatory)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later'),
          ),
        ElevatedButton(
          onPressed: () => _downloadAndInstall(updateInfo.downloadUrl),
          child: Text('Download & Install'),
        ),
      ],
    );
  }
  
  Future<void> _downloadAndInstall(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
```

### 4. Add to Main App

```dart
// lib/main.dart
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocBuilder<AppUpdateBloc, AppUpdateState>(
        builder: (context, state) {
          // Show update dialog if available
          if (state is UpdateAvailableState) {
            Future.delayed(Duration.zero, () {
              showDialog(
                context: context,
                barrierDismissible: !state.updateInfo.mandatory,
                builder: (_) => UpdateDialog(updateInfo: state.updateInfo),
              );
            });
          }
          
          return HomePage();
        },
      ),
    );
  }
}
```

### 5. Check for Updates on App Start

```dart
// In your main app initialization
void initializeApp() {
  // Check for updates when app starts
  context.read<AppUpdateBloc>().add(CheckUpdateEvent());
  
  // Or check periodically
  Timer.periodic(Duration(hours: 1), (_) {
    context.read<AppUpdateBloc>().add(CheckUpdateEvent());
  });
}
```

## 🧪 Testing the Integration

### Test 1: Check Version Endpoint
```bash
curl "http://localhost:3000/api/version/operon-client?currentBuild=1"
```

### Test 2: Download APK
```bash
curl -O "http://localhost:3000/api/download/operon-client/1.0.1"
```

### Test 3: Install on Device
```bash
adb install operon-client-v1.0.1.apk
```

### Test 4: Verify Update Check (in app logs)
The app should show update available dialog when it has build code < 2

## 🔄 Updating to v1.0.2 (Future)

When ready to release v1.0.2:

### 1. Build v1.0.2
```bash
cd apps/Operon_Client_android
# Update pubspec.yaml: version: 1.0.2+3
flutter build apk --release
```

### 2. Copy APK to Server
```bash
cp build/app/outputs/flutter-apk/app-release.apk \
   /path/to/distribution-server/apks/operon-client-v1.0.2.apk
```

### 3. Publish Version
```bash
curl -X POST http://localhost:3000/api/admin/update-version/operon-client \
  -H "X-Admin-Key: operon-secret-admin-key-change-this" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "1.0.2",
    "buildCode": 3,
    "releaseNotes": "Version 1.0.2 - More improvements",
    "mandatory": false
  }'
```

### 4. All Users See Update
Users with v1.0.1 will now see update available dialog

## 📱 Production Deployment

For production, update the server URL:

```dart
// Use your production server URL
final String serverUrl = 'https://operon-updates.yourdomain.com';
```

## 🚀 Next Steps

1. ✅ Distribution server created and running
2. ✅ v1.0.1 APK hosted
3. ⬜ Integrate update check into Flutter app
4. ⬜ Test update flow on device
5. ⬜ Deploy v1.0.1 to users
6. ⬜ Move server to production domain
7. ⬜ Set up monitoring and analytics

## 📝 Server Management Commands

**Restart Server**
```bash
# Kill current process
kill -9 $(lsof -ti:3000)

# Restart
cd /Users/vedantreddymuskawar/Operon/distribution-server
node server.js
```

**Publish New Version**
```bash
curl -X POST http://localhost:3000/api/admin/update-version/operon-client \
  -H "X-Admin-Key: operon-secret-admin-key-change-this" \
  -H "Content-Type: application/json" \
  -d '{...}'
```

**View Server Status**
```bash
curl http://localhost:3000/api/health
```

---

**Ready to integrate?** Follow the Flutter Integration steps above.
