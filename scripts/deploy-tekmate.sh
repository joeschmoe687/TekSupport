#!/bin/bash

# TekMate Ghost Mode Deployment Script
# This script deploys Cloud Functions and Firestore security rules

set -e  # Exit on error

echo "🔒 TekMate Ghost Mode - Deployment Script"
echo "=========================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found!"
    echo "Install it with: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI found"
echo ""

# Check if logged in
echo "📝 Checking Firebase authentication..."
firebase projects:list > /dev/null 2>&1 || {
    echo "❌ Not logged in to Firebase"
    echo "Run: firebase login"
    exit 1
}

echo "✅ Authenticated with Firebase"
echo ""

# Install function dependencies
echo "📦 Installing Cloud Functions dependencies..."
cd functions
npm install
cd ..

echo "✅ Dependencies installed"
echo ""

# Ask for confirmation
echo "⚠️  Ready to deploy:"
echo "   - Cloud Functions (tekmateChatProxy, createPaymentIntent, stripeWebhook)"
echo "   - Firestore Security Rules (with admin-only TekMate protection)"
echo ""
read -p "Continue with deployment? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 0
fi

echo ""
echo "🚀 Deploying to Firebase..."
echo ""

# Deploy functions
echo "📤 Deploying Cloud Functions..."
firebase deploy --only functions

echo ""
echo "📤 Deploying Firestore Rules..."
firebase deploy --only firestore:rules

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Test as admin user - should see TekMate button"
echo "   2. Test as non-admin user - should see NOTHING"
echo "   3. Check Firestore logs: admin/tekmate_interactions/logs"
echo "   4. Monitor Cloud Function logs: firebase functions:log"
echo ""
echo "📖 Documentation:"
echo "   - GHOST_MODE_DEPLOYMENT.md - Deployment guide"
echo "   - TEKMATE_TESTING.md - Testing procedures"
echo ""
echo "🔗 View deployment:"
echo "   firebase open functions"
echo "   firebase open firestore"
echo ""
echo "🎉 TekMate Ghost Mode is now live!"
