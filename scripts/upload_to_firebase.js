#!/usr/bin/env node
/**
 * Upload BLE Sniff Data to Firebase
 * Automatically uploads HCI logs and analysis to Firestore
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('../functions/service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'tekneck-support.appspot.com'
});

const db = admin.firestore();
const storage = admin.storage().bucket();

async function uploadBleSniffData(hciLogPath, metadata = {}) {
  try {
    const timestamp = new Date().toISOString();
    const filename = path.basename(hciLogPath);
    const sessionId = `sniff_${Date.now()}`;
    
    console.log(`📤 Uploading HCI log: ${filename}`);
    
    // 1. Upload HCI log file to Cloud Storage
    const storageRef = storage.file(`ble_sniff_logs/${sessionId}/${filename}`);
    await storageRef.save(fs.readFileSync(hciLogPath), {
      metadata: {
        contentType: 'application/octet-stream',
        metadata: {
          uploadedAt: timestamp,
          ...metadata
        }
      }
    });
    
    const downloadUrl = await storageRef.getSignedUrl({
      action: 'read',
      expires: '03-01-2030' // Long expiration for archive access
    });
    
    console.log(`✅ HCI log uploaded to Cloud Storage`);
    
    // 2. Create Firestore document with metadata
    const sniffDoc = {
      sessionId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      uploadedAt: timestamp,
      filename,
      storageUrl: downloadUrl[0],
      metadata: {
        deviceModel: metadata.deviceModel || 'Unknown',
        androidVersion: metadata.androidVersion || 'Unknown',
        captureDate: metadata.captureDate || timestamp,
        deviceSerialNumber: metadata.deviceSerialNumber || 'Unknown',
        ...metadata
      },
      analysis: {
        status: 'pending',
        testoDevices: []
      }
    };
    
    await db.collection('ble_sniff_logs').doc(sessionId).set(sniffDoc);
    console.log(`✅ Metadata saved to Firestore: ble_sniff_logs/${sessionId}`);
    
    // 3. Parse Testo devices if analysis file exists
    const analysisPath = hciLogPath.replace('.log', '_analysis.txt');
    if (fs.existsSync(analysisPath)) {
      const analysisText = fs.readFileSync(analysisPath, 'utf8');
      const devices = parseTestoDevices(analysisText);
      
      await db.collection('ble_sniff_logs').doc(sessionId).update({
        'analysis.status': 'completed',
        'analysis.testoDevices': devices,
        'analysis.completedAt': admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`✅ Analysis uploaded (${devices.length} Testo devices found)`);
    }
    
    console.log(`\n🔗 View in Firebase Console:`);
    console.log(`   https://console.firebase.google.com/project/tekneck-support/firestore/data/ble_sniff_logs/${sessionId}`);
    
    return sessionId;
    
  } catch (error) {
    console.error('❌ Upload failed:', error.message);
    throw error;
  }
}

function parseTestoDevices(analysisText) {
  const devices = [];
  const lines = analysisText.split('\n');
  
  let currentDevice = null;
  
  for (const line of lines) {
    // Parse device headers: "T549i PRESSURE PROBE (SN:49291139)"
    const deviceMatch = line.match(/(T\d+i)\s+(\w+)\s+PROBE\s+\(SN:(\d+)\)/);
    if (deviceMatch) {
      if (currentDevice) devices.push(currentDevice);
      currentDevice = {
        model: deviceMatch[1],
        type: deviceMatch[2].toLowerCase(),
        serialNumber: deviceMatch[3],
        readings: []
      };
      continue;
    }
    
    // Parse readings: "  Reading #1: 69.7 °F (RSSI: -52 dBm)"
    const readingMatch = line.match(/Reading #\d+:\s+([\d.]+)\s+([°F|PSI]+)\s+\(RSSI:\s+([-\d]+)/);
    if (readingMatch && currentDevice) {
      currentDevice.readings.push({
        value: parseFloat(readingMatch[1]),
        unit: readingMatch[2],
        rssi: parseInt(readingMatch[3])
      });
    }
  }
  
  if (currentDevice) devices.push(currentDevice);
  
  return devices;
}

// CLI Usage
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('Usage: node upload_to_firebase.js <hci_log_path> [--device-model MODEL] [--android-version VERSION]');
    console.log('');
    console.log('Example:');
    console.log('  node upload_to_firebase.js baseline_extracted/FS/data/log/bt/btsnoop_hci.log \\');
    console.log('    --device-model "Samsung SM-S931U" \\');
    console.log('    --android-version "16"');
    process.exit(1);
  }
  
  const hciLogPath = args[0];
  const metadata = {};
  
  // Parse CLI arguments
  for (let i = 1; i < args.length; i += 2) {
    const key = args[i].replace('--', '').replace(/-/g, '_');
    const value = args[i + 1];
    metadata[key] = value;
  }
  
  if (!fs.existsSync(hciLogPath)) {
    console.error(`❌ File not found: ${hciLogPath}`);
    process.exit(1);
  }
  
  uploadBleSniffData(hciLogPath, metadata)
    .then(sessionId => {
      console.log(`\n✅ Upload complete! Session ID: ${sessionId}`);
      process.exit(0);
    })
    .catch(error => {
      console.error('Upload failed:', error);
      process.exit(1);
    });
}

module.exports = { uploadBleSniffData };
