# Operon App Distribution Server

Simple Node.js + Express server for managing and distributing app updates.

## Features

✅ **Version Management** - Track and serve multiple app versions  
✅ **Update Check API** - Clients check for updates with version comparison  
✅ **Direct Downloads** - Stream APK files to devices  
✅ **Changelog Tracking** - Maintain version history  
✅ **Admin API** - Publish new versions with admin authentication  
✅ **Health Monitoring** - Built-in health check endpoint  
✅ **CORS Support** - Allow cross-origin requests from mobile apps  

## Quick Start

### 1. Install Dependencies

```bash
cd /Users/vedantreddymuskawar/Operon/distribution-server
npm install
```

### 2. Set Up Environment Variables

Create `.env` file:

```bash
cat > /Users/vedantreddymuskawar/Operon/distribution-server/.env << 'EOF'
PORT=3000
ADMIN_KEY=operon-secret-admin-key-change-this
NODE_ENV=development
EOF
```

### 3. Create APK Directory

```bash
mkdir -p /Users/vedantreddymuskawar/Operon/distribution-server/apks
```

### 4. Copy v1.0.1 APK to Server

```bash
cp /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk \
   /Users/vedantreddymuskawar/Operon/distribution-server/apks/operon-client-v1.0.1.apk
```

### 5. Start the Server

```bash
cd /Users/vedantreddymuskawar/Operon/distribution-server
npm start
```

You should see:

```
╔════════════════════════════════════════╗
║  Operon App Distribution Server        ║
╚════════════════════════════════════════╝

✓ Server running on http://localhost:3000
✓ API docs available at http://localhost:3000
✓ Version endpoint: http://localhost:3000/api/version/operon-client
```

## API Endpoints

### 1. Check for Updates

**Endpoint:** `GET /api/version/:appName`

**Query Parameters:**
- `currentVersion` (optional): Current version on device
- `currentBuild` (optional): Current build code on device

**Example:**
```bash
curl "http://localhost:3000/api/version/operon-client?currentBuild=1"
```

**Response:**
```json
{
  "success": true,
  "app": "operon-client",
  "updateAvailable": true,
  "current": {
    "version": "1.0.1",
    "buildCode": 2,
    "releaseDate": "2026-02-14T...",
    "releaseNotes": "Version 1.0.1 - Bug fixes and improvements...",
    "mandatory": false,
    "releaseUrl": "http://localhost:3000/apks/operon-client-v1.0.1.apk",
    "checksum": "b75af6dcc164b8ad45164b2bfbed42ea",
    "size": 76843520,
    "minSdkVersion": 21
  }
}
```

### 2. Download APK

**Endpoint:** `GET /api/download/:appName/:version`

**Example:**
```bash
curl http://localhost:3000/api/download/operon-client/1.0.1 -o app.apk
```

### 3. Get Changelog

**Endpoint:** `GET /api/changelog/:appName`

**Example:**
```bash
curl http://localhost:3000/api/changelog/operon-client
```

**Response:**
```json
{
  "success": true,
  "app": "operon-client",
  "changelog": [
    {
      "version": "1.0.1",
      "buildCode": 2,
      "date": "2026-02-14T...",
      "notes": "Bug fixes and improvements"
    },
    {
      "version": "1.0.0",
      "buildCode": 1,
      "date": "2026-02-14",
      "notes": "Initial release"
    }
  ]
}
```

### 4. Publish New Version (Admin)

**Endpoint:** `POST /api/admin/update-version/:appName`

**Headers:**
- `X-Admin-Key`: Your admin secret key

**Body:**
```json
{
  "version": "1.0.2",
  "buildCode": 3,
  "releaseNotes": "Version 1.0.2 - More bug fixes",
  "mandatory": false,
  "releaseUrl": "/apks/operon-client-v1.0.2.apk"
}
```

**Example:**
```bash
curl -X POST http://localhost:3000/api/admin/update-version/operon-client \
  -H "X-Admin-Key: operon-secret-admin-key-change-this" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "1.0.2",
    "buildCode": 3,
    "releaseNotes": "Bug fixes and improvements",
    "mandatory": false
  }'
```

### 5. Health Check

**Endpoint:** `GET /api/health`

**Example:**
```bash
curl http://localhost:3000/api/health
```

## Integration with Flutter App

Add this to your Flutter app to check for updates:

```dart
// lib/data/repositories/update_repository.dart
import 'package:http/http.dart' as http;

class UpdateRepository {
  final String updateServerUrl = 'http://your-server:3000';
  
  Future<Map<String, dynamic>> checkForUpdate(String appName, int currentBuild) async {
    try {
      final response = await http.get(
        Uri.parse('$updateServerUrl/api/version/$appName?currentBuild=$currentBuild'),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Update check failed: $e');
    }
    return {};
  }
  
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    // Use package_installer or in_app_update
  }
}
```

## Deployment Options

### Option 1: Local Network (Development)

```bash
npm start
# Accessible at: http://<your-machine-ip>:3000
```

### Option 2: Docker Container

```bash
docker build -t operon-distribution .
docker run -p 3000:3000 -e ADMIN_KEY=your-secret operon-distribution
```

### Option 3: Cloud Deployment (Heroku, Railway, AWS, etc)

1. Set environment variables in your hosting platform
2. Deploy the directory:

```bash
# Heroku example
heroku create operon-distribution
heroku config:set ADMIN_KEY=your-secret
git push heroku main
```

### Option 4: Firebase Cloud Functions

Deploy server.js as a Cloud Function (separate setup).

## File Structure

```
distribution-server/
├── server.js           # Main Express server
├── package.json        # Node.js dependencies
├── .env               # Environment config (don't commit)
├── .env.example       # Environment template
├── apks/              # APK storage
│   ├── operon-client-v1.0.1.apk
│   ├── operon-client-v1.0.2.apk
│   └── ...
├── logs/              # Server logs (optional)
└── README.md          # This file
```

## Security Notes

⚠️ **Admin Key:** Change the `ADMIN_KEY` in `.env` to a strong unique key  
⚠️ **HTTPS:** Use HTTPS in production (add SSL certificate)  
⚠️ **API Authentication:** Consider adding more robust auth for admin endpoints  
⚠️ **Rate Limiting:** Add rate limiting in production  
⚠️ **Log Monitoring:** Monitor server logs for unauthorized access  

## Monitoring & Logging

Enable logging to track:
- Version check requests
- Download counts per version
- Failed requests
- Admin API calls

```javascript
// Add to server.js
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});
```

## Troubleshooting

### APK Not Found
- Verify APK is in `distribution-server/apks/` directory
- Check file permissions: `chmod 644 apks/*.apk`

### Admin Key Not Working
- Verify `ADMIN_KEY` in .env matches header value
- Restart server after changing .env: `npm start`

### Port Already in Use
```bash
# Change port in .env
PORT=3001
```

### Connection Refused
- Verify server is running: `curl http://localhost:3000/api/health`
- Check firewall rules
- Use IP address instead of localhost for network access

## Next Steps

1. ✅ Server created and running locally
2. ⬜ Copy APK files to `apks/` directory
3. ⬜ Test version check endpoint with curl
4. ⬜ Deploy to production server
5. ⬜ Update Flutter app with server URL
6. ⬜ Monitor download/install metrics

## Support

More detailed setup and troubleshooting coming soon. For issues, check the API docs at `http://localhost:3000`
