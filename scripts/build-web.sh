#!/bin/bash

# Build and deploy TekTool Web UI
# Usage: ./scripts/build-web.sh [deploy]

set -e

echo "🚀 Building TekTool Web UI..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Clean previous build
echo "🧹 Cleaning previous build..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web
echo "🔨 Building web app..."
flutter build web --release --web-renderer canvaskit

echo "✅ Build complete! Output: build/web/"

# Deploy to Firebase if requested
if [ "$1" = "deploy" ]; then
    echo "🌐 Deploying to Firebase Hosting..."
    firebase deploy --only hosting
    echo "✅ Deployment complete!"
else
    echo ""
    echo "💡 To deploy to Firebase, run:"
    echo "   ./scripts/build-web.sh deploy"
    echo ""
    echo "💡 To test locally, run:"
    echo "   firebase serve --only hosting"
fi
