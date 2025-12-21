#!/bin/bash
# TekMate Cloud Function Deployment Script

set -e

echo "🚀 TekMate Cloud Function Deployment"
echo "====================================="

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found!"
    echo "Install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if we're logged in
if ! firebase projects:list &> /dev/null; then
    echo "🔐 Not logged in to Firebase. Please login:"
    firebase login
fi

# Verify project
echo ""
echo "📋 Checking project configuration..."
CURRENT_PROJECT=$(firebase use)
echo "Current project: $CURRENT_PROJECT"

if [[ "$CURRENT_PROJECT" != *"tekneck-support"* ]]; then
    echo "⚠️  Warning: Not using tekneck-support project"
    echo "Switching to tekneck-support..."
    firebase use tekneck-support
fi

# Check Node version
echo ""
echo "🔍 Checking Node.js version..."
NODE_VERSION=$(node -v)
echo "Node version: $NODE_VERSION"

# Install dependencies
echo ""
echo "📦 Installing Cloud Function dependencies..."
cd functions
npm install

# Check configuration
echo ""
echo "⚙️  Checking Firebase configuration..."
firebase functions:config:get

# Deploy functions
echo ""
echo "🚀 Deploying Cloud Functions..."
echo ""
read -p "Deploy ALL functions or just TekMate? (all/tekmate): " DEPLOY_CHOICE

if [ "$DEPLOY_CHOICE" == "tekmate" ]; then
    echo "Deploying only tekmateChatProxy..."
    firebase deploy --only functions:tekmateChatProxy
else
    echo "Deploying all functions..."
    firebase deploy --only functions
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Next steps:"
echo "1. Configure Firestore settings/tekmate document"
echo "2. Test with admin user"
echo "3. Verify Ghost Mode with non-admin user"
echo ""
echo "📚 See docs/TEKMATE_TESTING_GUIDE.md for testing procedures"
