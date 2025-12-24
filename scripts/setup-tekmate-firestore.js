#!/usr/bin/env node

/**
 * Setup TekMate Configuration in Firestore
 * 
 * This script creates the required Firestore settings/tekmate document
 * that the Cloud Functions use to proxy requests to TekMate AI.
 * 
 * Prerequisites:
 * - Firebase CLI authenticated: firebase login
 * - Node.js installed
 * 
 * Run from project root:
 *   npm install firebase-admin
 *   node setup-tekmate-config.js
 */

const admin = require('firebase-admin');

const projectId = 'tekneck-support';

// Initialize Firebase Admin with project ID
// This uses GOOGLE_APPLICATION_CREDENTIALS or Firebase CLI credentials
try {
  admin.initializeApp({
    projectId: projectId
  });
} catch (error) {
  // Already initialized
}

const db = admin.firestore();

async function setupTekMateConfig() {
  try {
    console.log('🔧 Setting up TekMate configuration in Firestore...');
    console.log(`📍 Project: ${projectId}`);

    const tekmateConfig = {
      apiUrl: 'https://us-central1-tekneck-support.cloudfunctions.net/tekmateChatProxy',
      enabled: true,
      models: ['hvac-support', 'tekmate-trained', 'tekmate-memory'],
      timeout: 120000,  // 2 minutes for complex HVAC analysis
      cloudflareTimeout: 120,  // Cloudflare timeout in seconds
      description: 'TekMate AI configuration for hybrid intent-based routing. ' +
                   'Auto-switches to hvac-support model for HVAC questions.',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Write to settings/tekmate
    console.log('📝 Writing settings/tekmate...');
    await db.collection('settings').doc('tekmate').set(tekmateConfig, { merge: true });
    console.log('✓ TekMate configuration written to Firestore');

    // Verify it was written
    const doc = await db.collection('settings').doc('tekmate').get();
    if (doc.exists) {
      console.log('\n✅ Verification: settings/tekmate exists in Firestore');
      console.log('\nConfiguration Details:');
      console.log('─'.repeat(60));
      const data = doc.data();
      console.log(`API URL:      ${data.apiUrl}`);
      console.log(`Enabled:      ${data.enabled}`);
      console.log(`Models:       ${data.models.join(', ')}`);
      console.log(`Timeout:      ${data.timeout}ms (${data.timeout/1000}s)`);
      console.log(`CF Timeout:   ${data.cloudflareTimeout}s`);
      console.log(`Description:  ${data.description}`);
      console.log('─'.repeat(60));
    }

    console.log('\n✅ Setup complete! TekMate is ready to use.');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error setting up TekMate config:');
    console.error(`   ${error.message}`);
    console.error('\n⚠️  Make sure you:');
    console.error('   1. Run: firebase login');
    console.error('   2. Run: npm install firebase-admin');
    console.error('   3. Ensure you\'re in the project root directory');
    process.exit(1);
  }
}

setupTekMateConfig();
