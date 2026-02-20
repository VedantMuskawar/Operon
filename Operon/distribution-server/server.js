// Operon App Update Server
// Simple Node.js + Express server for managing app updates
// Serves APK files and version metadata

const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;
const APK_BASE_URL = process.env.APK_BASE_URL;
const GCS_BUCKET_NAME = process.env.GCS_BUCKET_NAME;
const GCS_PUBLIC_BASE_URL = process.env.GCS_PUBLIC_BASE_URL;

// Trust proxy headers (Cloud Run sets x-forwarded-proto)
app.set('trust proxy', true);

// Middleware
app.use(cors());
app.use(express.json());

const getExternalApkUrl = (fileName) => {
  if (!fileName) {
    return null;
  }

  if (APK_BASE_URL) {
    return `${APK_BASE_URL.replace(/\/$/, '')}/${fileName}`;
  }

  if (GCS_PUBLIC_BASE_URL) {
    return `${GCS_PUBLIC_BASE_URL.replace(/\/$/, '')}/${fileName}`;
  }

  if (GCS_BUCKET_NAME) {
    return `https://storage.googleapis.com/${GCS_BUCKET_NAME}/${fileName}`;
  }

  return null;
};

app.use('/apks', (req, res) => {
  try {
    const fileName = req.path.replace(/^\//, '');
    const filePath = path.join(__dirname, 'apks', fileName);
    const isHeadRequest = req.method === 'HEAD';
    const range = req.headers.range;

    const externalApkUrl = getExternalApkUrl(fileName);
    if (externalApkUrl) {
      console.log(`[APK] redirecting to external URL: ${externalApkUrl}`);
      return res.redirect(302, externalApkUrl);
    }

    console.log(
      `[APK] ${req.method} ${req.originalUrl} range=${range || 'none'} ua=${req.get('user-agent') || 'unknown'}`
    );

    if (!fileName) {
      return res.status(404).json({
        success: false,
        error: 'APK file not specified'
      });
    }

    if (fileName.includes('..')) {
      return res.status(400).json({
        success: false,
        error: 'Invalid APK file path'
      });
    }

    if (!fs.existsSync(filePath)) {
      return res.status(404).json({
        success: false,
        error: 'APK file not found on server'
      });
    }

    let stat;
    try {
      stat = fs.statSync(filePath);
    } catch (err) {
      console.error('APK stat error:', err);
      return res.status(500).json({
        success: false,
        error: 'Failed to read APK metadata'
      });
    }

    const fileSize = stat.size;

    console.log(`[APK] fileSize=${fileSize}`);

    res.setHeader('Content-Type', 'application/vnd.android.package-archive');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${fileName}"`
    );
    res.setHeader('Accept-Ranges', 'bytes');

    if (range) {
      const parts = range.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      let end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

      if (Number.isNaN(start) || start < 0) {
        res.status(416);
        res.setHeader('Content-Range', `bytes */${fileSize}`);
        return res.end();
      }

      if (Number.isNaN(end) || end >= fileSize) {
        end = fileSize - 1;
      }

      if (start >= fileSize || start > end) {
        res.status(416);
        res.setHeader('Content-Range', `bytes */${fileSize}`);
        return res.end();
      }

      const chunkSize = end - start + 1;
      res.status(206);
      res.setHeader('Content-Range', `bytes ${start}-${end}/${fileSize}`);
      res.setHeader('Content-Length', chunkSize);

      if (isHeadRequest) {
        return res.end();
      }

      const stream = fs.createReadStream(filePath, { start, end });
      res.on('close', () => {
        stream.destroy();
      });

      stream.on('error', (err) => {
        if (err.code === 'ECONNABORTED' || err.code === 'EPIPE') {
          return;
        }
        console.error('APK stream error:', err);
        if (!res.headersSent) {
          res.status(500).end();
        }
      });

      return stream.pipe(res);
    }

    res.setHeader('Content-Length', fileSize);

    if (isHeadRequest) {
      return res.end();
    }

    const stream = fs.createReadStream(filePath);
    res.on('close', () => {
      stream.destroy();
    });

    stream.on('error', (err) => {
      if (err.code === 'ECONNABORTED' || err.code === 'EPIPE') {
        return;
      }
      console.error('APK stream error:', err);
      if (!res.headersSent) {
        res.status(500).end();
      }
    });

    return stream.pipe(res);
  } catch (err) {
    console.error('APK handler error:', err);
    return res.status(500).json({
      success: false,
      error: 'Failed to process APK download'
    });
  }
});

// Version registry - can be moved to database
const versionRegistry = {
  'operon-client': {
    currentVersion: '1.2.2',
    currentBuildCode: 6,
    releaseUrl: '/api/download/operon-client/1.2.2',
    releaseDate: new Date().toISOString(),
    releaseNotes: `Version 1.2.2 - Production release
• Updated APK delivery and distribution metadata
• Stability and reliability improvements`,
    mandatory: false,
    minSdkVersion: 21,
    targetSdkVersion: 34,
    checksum: '4201891d0ee39e53a54b1f080fa6c09e',
    size: 80437664, // bytes
    changelog: [
      {
        version: '1.2.2',
        buildCode: 6,
        date: new Date().toISOString(),
        notes: 'Production release with updated distribution metadata and stability improvements'
      },
      {
        version: '1.2.1',
        buildCode: 5,
        date: new Date().toISOString(),
        notes: 'Bug fixes and stability improvements'
      },
      {
        version: '1.2.0',
        buildCode: 4,
        date: new Date().toISOString(),
        notes: 'UI/UX improvements - defaults, routing, and new features'
      },
      {
        version: '1.1.0',
        buildCode: 3,
        date: new Date().toISOString(),
        notes: 'Performance improvements, stability fixes, update delivery improvements'
      },
      {
        version: '1.0.1',
        buildCode: 2,
        date: new Date().toISOString(),
        notes: 'Bug fixes and improvements'
      },
      {
        version: '1.0.0',
        buildCode: 1,
        date: '2026-02-14',
        notes: 'Initial release'
      }
    ]
  }
};

/**
 * GET /api/version/:appName
 * Get latest version info for an app
 * 
 * Query params:
 *   - currentVersion: Current version on device (optional, for filtering)
 *   - currentBuild: Current build code on device (optional)
 */
app.get('/api/version/:appName', (req, res) => {
  const { appName } = req.params;
  const { currentBuild } = req.query;

  const app = versionRegistry[appName];
  if (!app) {
    return res.status(404).json({
      success: false,
      error: `App not found: ${appName}`
    });
  }

  // Check if update is available
  const currentBuildCode = parseInt(currentBuild) || 0;
  const updateAvailable = app.currentBuildCode > currentBuildCode;

  const host = req.get('host');
  const forwardedProto = req.get('x-forwarded-proto');
  const protocol = forwardedProto || (host && host.includes('run.app') ? 'https' : req.protocol);
  const downloadUrl = `${protocol}://${host}${app.releaseUrl}`;

  return res.json({
    success: true,
    app: appName,
    updateAvailable,
    current: {
      version: app.currentVersion,
      buildCode: app.currentBuildCode,
      releaseDate: app.releaseDate,
      releaseNotes: app.releaseNotes,
      mandatory: app.mandatory,
      releaseUrl: downloadUrl,
      downloadUrl,
      checksum: app.checksum,
      size: app.size,
      minSdkVersion: app.minSdkVersion
    }
  });
});

/**
 * GET /api/download/:appName/:version
 * Direct download endpoint for APK
 */
app.get('/api/download/:appName/:version', (req, res) => {
  const { appName, version } = req.params;
  const app = versionRegistry[appName];

  if (!app || app.currentVersion !== version) {
    return res.status(404).json({
      success: false,
      error: 'Version not found'
    });
  }

  const fileName = `${appName}-v${version}.apk`;
  const externalApkUrl = getExternalApkUrl(fileName);

  if (externalApkUrl) {
    return res.redirect(302, externalApkUrl);
  }

  const filePath = path.join(__dirname, 'apks', fileName);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({
      success: false,
      error: 'APK file not found on server'
    });
  }

  const redirectUrl = `${req.get('x-forwarded-proto') || req.protocol || 'https'}://${req.get('host')}/apks/${fileName}`;
  return res.redirect(302, redirectUrl);
});

/**
 * GET /api/changelog/:appName
 * Get version history and changelog
 */
app.get('/api/changelog/:appName', (req, res) => {
  const { appName } = req.params;
  const app = versionRegistry[appName];

  if (!app) {
    return res.status(404).json({
      success: false,
      error: `App not found: ${appName}`
    });
  }

  return res.json({
    success: true,
    app: appName,
    changelog: app.changelog
  });
});

/**
 * POST /api/admin/update-version/:appName
 * Admin endpoint to update version info
 * Requires X-Admin-Key header
 */
app.post('/api/admin/update-version/:appName', (req, res) => {
  const adminKey = req.get('X-Admin-Key');
  const expectedKey = process.env.ADMIN_KEY || 'your-secret-key-here';

  if (adminKey !== expectedKey) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized: Invalid admin key'
    });
  }

  const { appName } = req.params;
  const { version, buildCode, releaseNotes, mandatory, releaseUrl } = req.body;

  if (!versionRegistry[appName]) {
    return res.status(404).json({
      success: false,
      error: `App not found: ${appName}`
    });
  }

  // Update registry
  versionRegistry[appName].currentVersion = version;
  versionRegistry[appName].currentBuildCode = buildCode;
  versionRegistry[appName].releaseNotes = releaseNotes;
  versionRegistry[appName].mandatory = mandatory || false;
  versionRegistry[appName].releaseDate = new Date().toISOString();
  
  if (releaseUrl) {
    versionRegistry[appName].releaseUrl = releaseUrl;
  }

  // Add to changelog
  versionRegistry[appName].changelog.unshift({
    version,
    buildCode,
    date: new Date().toISOString(),
    notes: releaseNotes
  });

  return res.json({
    success: true,
    message: `Version ${version} published for ${appName}`,
    app: versionRegistry[appName]
  });
});

/**
 * GET /api/health
 * Health check endpoint
 */
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    status: 'online',
    timestamp: new Date().toISOString(),
    apps: Object.keys(versionRegistry)
  });
});

/**
 * GET /health
 * Simple health check alias
 */
app.get('/health', (req, res) => {
  res.redirect(302, '/api/health');
});

/**
 * GET /
 * Welcome page with API docs
 */
app.get('/', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>Operon App Distribution Server</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 20px; }
          code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
          pre { background: #f4f4f4; padding: 10px; border-radius: 5px; overflow-x: auto; }
          .endpoint { margin: 20px 0; padding: 10px; border-left: 4px solid #007bff; }
        </style>
      </head>
      <body>
        <h1>🚀 Operon App Distribution Server</h1>
        <p>Version: 1.0 | Status: ✅ Online</p>

        <h2>📝 API Endpoints</h2>

        <div class="endpoint">
          <h3>GET /api/version/:appName</h3>
          <p>Get latest version and update info</p>
          <pre>curl http://localhost:3000/api/version/operon-client?currentBuild=1</pre>
          <p><strong>Returns:</strong> Version info, update URL, release notes, checksum</p>
        </div>

        <div class="endpoint">
          <h3>GET /api/download/:appName/:version</h3>
          <p>Direct download APK file</p>
          <pre>curl http://localhost:3000/api/download/operon-client/1.0.1 -o app.apk</pre>
        </div>

        <div class="endpoint">
          <h3>GET /api/changelog/:appName</h3>
          <p>Get version history and changelog</p>
          <pre>curl http://localhost:3000/api/changelog/operon-client</pre>
        </div>

        <div class="endpoint">
          <h3>POST /api/admin/update-version/:appName</h3>
          <p>Publish new version (requires admin key)</p>
          <pre>curl -X POST http://localhost:3000/api/admin/update-version/operon-client \\
  -H "X-Admin-Key: your-secret-key" \\
  -H "Content-Type: application/json" \\
  -d '{
    "version": "1.0.2",
    "buildCode": 3,
    "releaseNotes": "Bug fixes",
    "mandatory": false
  }'</pre>
        </div>

        <div class="endpoint">
          <h3>GET /api/health</h3>
          <p>Health check</p>
          <pre>curl http://localhost:3000/api/health</pre>
        </div>

        <h2>📂 Server Structure</h2>
        <pre>
distribution-server/
├── server.js              # Main server file
├── package.json           # Dependencies
├── apks/                  # APK storage directory
│   ├── operon-client-v1.0.1.apk
│   └── ...
├── .env                   # Environment variables (admin key, port, etc)
└── README.md              # Setup instructions
        </pre>

        <h2>🔧 Environment Variables</h2>
        <pre>
PORT=3000
ADMIN_KEY=your-secret-admin-key
NODE_ENV=production
APK_BASE_URL=https://your-cdn.example.com/apks
GCS_PUBLIC_BASE_URL=https://storage.googleapis.com/your-bucket
GCS_BUCKET_NAME=your-bucket
        </pre>
      </body>
    </html>
  `);
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    message: err.message
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`\n╔════════════════════════════════════════╗`);
  console.log(`║  Operon App Distribution Server        ║`);
  console.log(`╚════════════════════════════════════════╝`);
  console.log(`\n✓ Server running on http://localhost:${PORT}`);
  console.log(`✓ API docs available at http://localhost:${PORT}`);
  console.log(`✓ Version endpoint: http://localhost:${PORT}/api/version/operon-client`);
  console.log(`\nRegistered apps:`);
  Object.keys(versionRegistry).forEach(app => {
    console.log(`  • ${app} v${versionRegistry[app].currentVersion}`);
  });
});

module.exports = app;
