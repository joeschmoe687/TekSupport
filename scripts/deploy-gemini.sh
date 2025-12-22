#!/bin/bash
# Deploy Gemini AI Integration to Firebase
# Run from project root: ./scripts/deploy-gemini.sh

set -e  # Exit on error

echo "🚀 Deploying Gemini AI Integration to Firebase..."
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: Must run from project root directory"
  exit 1
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
  echo "❌ Error: Firebase CLI not installed"
  echo "Install with: npm install -g firebase-tools"
  exit 1
fi

echo "📦 Installing Cloud Function dependencies..."
cd functions
npm install
cd ..
echo "✅ Dependencies installed"
echo ""

echo "🔧 Deploying Cloud Functions..."
firebase deploy --only functions:autoRespondWithGemini,functions:tekmateChatProxy
echo "✅ Cloud Functions deployed"
echo ""

echo "📱 Building Flutter app..."
echo "(Skipping - requires Flutter SDK)"
echo "To build manually: flutter build apk --release"
echo ""

echo "✨ Deployment Complete!"
echo ""
echo "Next Steps:"
echo "1. Configure Gemini API key in Firebase Console or Admin App"
echo "2. Enable Gemini in Admin Dashboard → Settings"
echo "3. Test with GEMINI_TESTING.md guide"
echo ""
echo "Firestore Configuration:"
echo "  Collection: settings"
echo "  Document: gemini"
echo "  Fields:"
echo "    - enabled: true"
echo "    - apiKey: 'AIza...'"
echo "    - personality: '...'"
echo ""
echo "Happy Testing! 🎉"

