#!/usr/bin/env node

/**
 * Manual Tech Role Assignment Script
 * 
 * Assigns 'tech' role to users in Firestore for remote technician access.
 * This gives techs access to the Tech Inbox for answering customer chats.
 * 
 * Usage:
 *   node assign_tech_role.js <email>
 * 
 * Example:
 *   node assign_tech_role.js john@example.com
 */

const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin
const serviceAccount = require('../functions/tekneck-support-firebase-adminsdk.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'tekneck-support'
});

const db = admin.firestore();
const auth = admin.auth();

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
};

async function assignTechRole(email) {
  try {
    console.log(`${colors.cyan}Looking up user: ${email}${colors.reset}`);
    
    // Get user by email
    const userRecord = await auth.getUserByEmail(email);
    const uid = userRecord.uid;
    
    console.log(`${colors.green}✓ Found user: ${userRecord.displayName || email}${colors.reset}`);
    console.log(`  UID: ${uid}`);
    
    // Check current role in Firestore
    const userDoc = await db.collection('users').doc(uid).get();
    const currentRole = userDoc.exists ? userDoc.data().role : 'none';
    
    console.log(`  Current role: ${currentRole}`);
    
    if (currentRole === 'tech') {
      console.log(`${colors.yellow}⚠ User already has 'tech' role${colors.reset}`);
      return;
    }
    
    // Confirm assignment
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    const answer = await new Promise((resolve) => {
      rl.question(`${colors.yellow}Assign 'tech' role to ${email}? (y/n): ${colors.reset}`, resolve);
    });
    rl.close();
    
    if (answer.toLowerCase() !== 'y') {
      console.log(`${colors.red}✗ Cancelled${colors.reset}`);
      return;
    }
    
    // Update Firestore
    await db.collection('users').doc(uid).set({
      role: 'tech',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    
    // Set custom claim in Firebase Auth
    await auth.setCustomUserClaims(uid, {
      role: 'tech'
    });
    
    console.log(`${colors.green}✓ Successfully assigned 'tech' role to ${email}${colors.reset}`);
    console.log(`${colors.cyan}→ User will see Tech Inbox on next login${colors.reset}`);
    
  } catch (error) {
    console.error(`${colors.red}✗ Error: ${error.message}${colors.reset}`);
    process.exit(1);
  }
}

async function listTechs() {
  try {
    console.log(`${colors.cyan}Listing all users with 'tech' role:${colors.reset}\n`);
    
    const snapshot = await db.collection('users').where('role', '==', 'tech').get();
    
    if (snapshot.empty) {
      console.log(`${colors.yellow}No techs found${colors.reset}`);
      return;
    }
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const userRecord = await auth.getUser(doc.id);
      
      console.log(`${colors.green}✓ ${userRecord.email}${colors.reset}`);
      console.log(`  Name: ${data.name || userRecord.displayName || 'N/A'}`);
      console.log(`  UID: ${doc.id}`);
      console.log(`  Phone: ${data.phone || 'N/A'}`);
      console.log('');
    }
    
    console.log(`${colors.cyan}Total techs: ${snapshot.size}${colors.reset}`);
    
  } catch (error) {
    console.error(`${colors.red}✗ Error: ${error.message}${colors.reset}`);
    process.exit(1);
  }
}

// Main execution
const args = process.argv.slice(2);

if (args.length === 0 || args[0] === '--help') {
  console.log(`
${colors.cyan}Tech Role Assignment Script${colors.reset}

Usage:
  node assign_tech_role.js <email>         Assign tech role to user
  node assign_tech_role.js --list          List all current techs
  node assign_tech_role.js --help          Show this help

Examples:
  node assign_tech_role.js john@example.com
  node assign_tech_role.js --list
  `);
  process.exit(0);
}

if (args[0] === '--list') {
  listTechs().then(() => process.exit(0));
} else {
  const email = args[0];
  if (!email.includes('@')) {
    console.error(`${colors.red}✗ Invalid email address${colors.reset}`);
    process.exit(1);
  }
  assignTechRole(email).then(() => process.exit(0));
}
