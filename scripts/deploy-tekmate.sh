#!/bin/bash

# TekMate Cloud Function Deployment Script
# This script deploys the tekmateChatProxy function to Firebase

set -e  # Exit on error

echo "🚀 TekMate Cloud Function Deployment"
echo "=========================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found!"
    echo "Install it with: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI found: $(firebase --version)"
echo ""

# Check if logged in
echo "📝 Checking Firebase authentication..."
firebase projects:list > /dev/null 2>&1 || {
    echo "❌ Not logged in to Firebase"
    echo "Run: firebase login"
    exit 1
}

echo "✅ Authenticated with Firebase"
PROJECT=$(firebase use 2>/dev/null | grep "Active Project" | cut -d':' -f2 | xargs || echo "tekneck-support")
echo "✅ Using project: ${PROJECT}"
echo ""

# Install function dependencies
echo "📦 Installing Cloud Functions dependencies..."
cd functions
npm install
cd ..

echo "✅ Dependencies installed"
echo ""

# Ask for confirmation
echo "⚠️  Ready to deploy: tekmateChatProxy function"
echo ""
read -p "Continue with deployment? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 0
fi

echo ""
echo "🚀 Deploying tekmateChatProxy to Firebase..."
echo ""

# Deploy only tekmateChatProxy function
firebase deploy --only functions:tekmateChatProxy

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Function URL:"
echo "   https://us-central1-${PROJECT}.cloudfunctions.net/tekmateChatProxy"
echo ""
echo "🧪 Test endpoint (should return 401):"
echo "   curl -X POST https://us-central1-${PROJECT}.cloudfunctions.net/tekmateChatProxy \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"data\": {\"message\": \"test\"}}'"
echo ""
echo "📝 Next steps:"
echo "   1. Configure Firestore settings/tekmate document with API URL and key"
echo "   2. Test TekMate backend health: curl https://tekmate.airpronwa.com/health"
echo "   3. Test function with admin user from the app"
echo ""
echo "📖 See DEPLOYMENT_INSTRUCTIONS.md for detailed testing guide"
echo ""
echo "🎉 TekMate Cloud Function is now live!"
