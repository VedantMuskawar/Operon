#!/usr/bin/env node

/**
 * Build script to replace Google Maps API key placeholder
 * 
 * Replaces {{GOOGLE_MAPS_API_KEY}} in:
 * - web/maps-config.js (primary location)
 * - web/index.html (if any placeholders remain)
 * 
 * Usage: 
 *   node scripts/replace-maps-api-key.js [API_KEY]
 *   Or set GOOGLE_MAPS_API_KEY environment variable
 * 
 * Example:
 *   GOOGLE_MAPS_API_KEY=your_key_here node scripts/replace-maps-api-key.js
 *   node scripts/replace-maps-api-key.js your_key_here
 */

const fs = require('fs');
const path = require('path');

const webDir = path.join(__dirname, '../web');
const mapsConfigPath = path.join(webDir, 'maps-config.js');
const indexHtmlPath = path.join(webDir, 'index.html');
const placeholder = '{{GOOGLE_MAPS_API_KEY}}';

// Get API key from command line argument or environment variable
const apiKey = process.argv[2] || process.env.GOOGLE_MAPS_API_KEY;

if (!apiKey) {
  console.error('Error: Google Maps API key not provided.');
  console.error('');
  console.error('Usage:');
  console.error('  node scripts/replace-maps-api-key.js [API_KEY]');
  console.error('  Or set GOOGLE_MAPS_API_KEY environment variable');
  console.error('');
  console.error('Example:');
  console.error('  GOOGLE_MAPS_API_KEY=your_key node scripts/replace-maps-api-key.js');
  console.error('  node scripts/replace-maps-api-key.js your_key');
  process.exit(1);
}

if (apiKey.length < 20) {
  console.warn('Warning: API key seems too short. Please verify it is correct.');
}

function replaceInFile(filePath, fileName) {
  try {
    if (!fs.existsSync(filePath)) {
      console.warn(`Warning: ${fileName} not found, skipping...`);
      return 0;
    }

    let content = fs.readFileSync(filePath, 'utf8');
    const regex = new RegExp(placeholder.replace(/[{}]/g, '\\$&'), 'g');
    const matches = content.match(regex);
    const count = matches ? matches.length : 0;
    
    if (count === 0) {
      return 0;
    }
    
    content = content.replace(regex, apiKey);
    fs.writeFileSync(filePath, content, 'utf8');
    
    console.log(`  ✓ Replaced ${count} occurrence(s) in ${fileName}`);
    return count;
  } catch (error) {
    console.error(`  ✗ Error processing ${fileName}:`, error.message);
    return 0;
  }
}

try {
  console.log('Replacing Google Maps API key placeholder...');
  console.log('');
  
  let totalReplaced = 0;
  totalReplaced += replaceInFile(mapsConfigPath, 'maps-config.js');
  totalReplaced += replaceInFile(indexHtmlPath, 'index.html');
  
  console.log('');
  if (totalReplaced > 0) {
    console.log(`✓ Successfully replaced ${totalReplaced} occurrence(s) total`);
    console.log('✓ Ready to build');
  } else {
    console.log('No placeholders found to replace.');
    console.log('The API key may already be configured.');
  }
} catch (error) {
  console.error('Error:', error.message);
  process.exit(1);
}
