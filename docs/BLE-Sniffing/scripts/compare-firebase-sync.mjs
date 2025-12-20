#!/usr/bin/env node
/**
 * Compare BLE sniff logs between local Hive storage and Firebase
 * Usage: node scripts/compare-firebase-sync.mjs
 */

import { initializeApp } from 'firebase/app';
import { getFirestore, collection, query, orderBy, limit, getDocs } from 'firebase/firestore';
import { readFileSync } from 'fs';

const firebaseConfig = {
  apiKey: 'AIzaSyCNqq-dFTSLz1iMdnPWAiXYNxbWQgCytBw',
  projectId: 'tekneck-support',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function getLatestFirebaseLogs() {
  console.log('📡 Fetching latest BLE sniff logs from Firebase...\n');
  
  const q = query(
    collection(db, 'ble_sniff_logs'),
    orderBy('timestamp', 'desc'),
    limit(2)
  );
  
  const snap = await getDocs(q);
  console.log(`Found ${snap.size} docs in Firebase\n`);
  
  const docs = [];
  snap.forEach(doc => {
    docs.push({ id: doc.id, ...doc.data() });
  });
  return docs;
}

function parseHiveFile(path) {
  console.log('📱 Parsing local Hive file from phone...\n');
  
  const content = readFileSync(path, 'utf-8');
  // Hive stores JSON strings, extract them
  const sessions = [];
  const jsonMatches = content.match(/\{[^}]+}/g);
  
  if (!jsonMatches) return sessions;
  
  // Try to extract full JSON objects by finding balanced braces
  let depth = 0;
  let start = -1;
  for (let i = 0; i < content.length; i++) {
    if (content[i] === '{') {
      if (depth === 0) start = i;
      depth++;
    } else if (content[i] === '}') {
      depth--;
      if (depth === 0 && start !== -1) {
        try {
          const json = JSON.parse(content.slice(start, i + 1));
          sessions.push(json);
        } catch (e) {
          // Skip malformed JSON
        }
        start = -1;
      }
    }
  }
  
  return sessions;
}

function compareSession(local, firebase) {
  console.log('\n📊 COMPARISON RESULTS\n');
  console.log('='.repeat(60));
  
  if (!firebase) {
    console.log('❌ No matching Firebase document found!');
    return;
  }
  
  const localFields = Object.keys(local);
  const firebaseFields = Object.keys(firebase);
  
  // Fields in local but not in Firebase
  const missingInFirebase = localFields.filter(f => !firebaseFields.includes(f) && f !== 'id');
  
  // Fields in Firebase but not in local
  const extraInFirebase = firebaseFields.filter(f => !localFields.includes(f) && f !== 'syncedAt');
  
  console.log(`\n📱 Local fields: ${localFields.length}`);
  console.log(localFields.join(', '));
  
  console.log(`\n☁️  Firebase fields: ${firebaseFields.length}`);
  console.log(firebaseFields.join(', '));
  
  if (missingInFirebase.length > 0) {
    console.log(`\n⚠️  MISSING IN FIREBASE (${missingInFirebase.length}):`);
    missingInFirebase.forEach(f => console.log(`   - ${f}`));
  } else {
    console.log('\n✅ All local fields present in Firebase');
  }
  
  // Compare devices array
  if (local.devices && firebase.devices) {
    console.log(`\n📱 Local devices: ${local.devices.length}`);
    console.log(`☁️  Firebase devices: ${firebase.devices.length}`);
    
    // Check device field completeness
    if (local.devices.length > 0 && firebase.devices.length > 0) {
      const localDeviceFields = Object.keys(local.devices[0]);
      const firebaseDeviceFields = Object.keys(firebase.devices[0]);
      
      console.log(`\nLocal device fields: ${localDeviceFields.join(', ')}`);
      console.log(`Firebase device fields: ${firebaseDeviceFields.join(', ')}`);
      
      const missingDeviceFields = localDeviceFields.filter(f => !firebaseDeviceFields.includes(f));
      if (missingDeviceFields.length > 0) {
        console.log(`\n❌ MISSING DEVICE FIELDS IN FIREBASE: ${missingDeviceFields.join(', ')}`);
      }
    }
  }
  
  // Compare logs array
  if (local.logs && firebase.logs) {
    console.log(`\n📱 Local logs: ${local.logs.length}`);
    console.log(`☁️  Firebase logs: ${firebase.logs.length}`);
  }
  
  // Sample data comparison
  console.log('\n' + '='.repeat(60));
  console.log('SAMPLE DATA COMPARISON\n');
  
  if (local.devices?.[0]) {
    console.log('First device (LOCAL):');
    console.log(JSON.stringify(local.devices[0], null, 2));
  }
  
  if (firebase.devices?.[0]) {
    console.log('\nFirst device (FIREBASE):');
    console.log(JSON.stringify(firebase.devices[0], null, 2));
  }
}

async function main() {
  try {
    // Get Firebase logs
    const firebaseLogs = await getLatestFirebaseLogs();
    
    if (firebaseLogs.length === 0) {
      console.log('❌ No BLE sniff logs found in Firebase!');
      console.log('\nThis could mean:');
      console.log('1. No sessions have been synced yet');
      console.log('2. The collection name is different');
      console.log('3. Firebase security rules are blocking access');
      process.exit(1);
    }
    
    console.log('Firebase logs found:');
    firebaseLogs.forEach((doc, i) => {
      console.log(`  ${i + 1}. ${doc.id} - ${doc.devices?.length || 0} devices, timestamp: ${doc.timestamp}`);
    });
    
    // Parse local Hive file
    const localPath = 'docs/BLE-Sniffing/phone-data/ble_sniff_sessions.hive';
    const localSessions = parseHiveFile(localPath);
    
    console.log(`\nLocal sessions found: ${localSessions.length}`);
    localSessions.forEach((s, i) => {
      console.log(`  ${i + 1}. ${s.id} - ${s.devices?.length || 0} devices, timestamp: ${s.timestamp}`);
    });
    
    // Find matching sessions by timestamp
    const latestFirebase = firebaseLogs[0];
    const matchingLocal = localSessions.find(s => s.timestamp === latestFirebase.timestamp);
    
    if (matchingLocal) {
      console.log(`\n✅ Found matching local session for Firebase doc ${latestFirebase.id}`);
      compareSession(matchingLocal, latestFirebase);
    } else {
      console.log(`\n⚠️  No local session matches Firebase timestamp ${latestFirebase.timestamp}`);
      console.log('\nComparing latest from each:');
      compareSession(localSessions[0], latestFirebase);
    }
    
    process.exit(0);
  } catch (e) {
    console.error('Error:', e.message);
    console.error(e.stack);
    process.exit(1);
  }
}

main();
