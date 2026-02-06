/**
 * Alternative script using Firebase CLI emulator or direct HTTP call
 * This doesn't require service account key
 * 
 * Option 1: Using curl (after deployment)
 * curl -X POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/cleanupTestData \
 *   -H "Content-Type: application/json" \
 *   -H "Authorization: Bearer YOUR_TOKEN" \
 *   -d '{}'
 * 
 * Option 2: Using Firebase CLI (for local emulator or deployed function)
 * firebase functions:shell
 * cleanupTestData({})
 */

const https = require('https');

// Configuration
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'your-project-id';
const REGION = process.env.FIREBASE_FUNCTIONS_REGION || 'asia-south1';
const FUNCTION_URL = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/cleanupTestData`;

// Get access token from Firebase CLI
const { execSync } = require('child_process');

function getAccessToken() {
  try {
    const token = execSync('firebase login:ci --no-localhost', { encoding: 'utf8' }).trim();
    return token;
  } catch (error) {
    console.error('Error getting access token. Make sure you are logged in with: firebase login');
    process.exit(1);
  }
}

async function callCleanupFunction() {
  console.log('🚀 Calling cleanup function...\n');

  const accessToken = getAccessToken();

  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({});

    const options = {
      hostname: `${REGION}-${PROJECT_ID}.cloudfunctions.net`,
      path: '/cleanupTestData',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode === 200) {
          try {
            const result = JSON.parse(data);
            console.log('✅ Cleanup completed successfully!\n');
            console.log('Results:');
            console.log(JSON.stringify(result, null, 2));
            resolve(result);
          } catch (error) {
            console.error('Error parsing response:', error);
            console.log('Raw response:', data);
            reject(error);
          }
        } else {
          console.error(`❌ Error: HTTP ${res.statusCode}`);
          console.log('Response:', data);
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', (error) => {
      console.error('❌ Request error:', error);
      reject(error);
    });

    req.write(postData);
    req.end();
  });
}

// Run
callCleanupFunction()
  .then(() => {
    console.log('\n✨ Done!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });

