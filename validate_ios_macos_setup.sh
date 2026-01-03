#!/bin/bash
# iOS and macOS Build Validation Script
# Tests that all configurations are correct before actual device testing

set -e  # Exit on error

echo "======================================"
echo "iOS/macOS Build Validation"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Navigate to project root
PROJECT_DIR="/home/runner/work/hvac_support_app/hvac_support_app"
cd "$PROJECT_DIR"

echo "Project directory: $PROJECT_DIR"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "Checking prerequisites..."
echo ""

# Check Flutter
if command_exists flutter; then
    echo -e "${GREEN}✓${NC} Flutter found"
    flutter --version | head -1
else
    echo -e "${RED}✗${NC} Flutter not found in PATH"
    exit 1
fi

echo ""

# Check Dart
if command_exists dart; then
    echo -e "${GREEN}✓${NC} Dart found"
    dart --version | head -1
else
    echo -e "${YELLOW}⚠${NC} Dart not found (should be included with Flutter)"
fi

echo ""
echo "======================================"
echo "Step 1: Flutter Doctor"
echo "======================================"
echo ""

# Run flutter doctor (don't fail if issues found, just report)
flutter doctor || true

echo ""
echo "======================================"
echo "Step 2: Clean Build Environment"
echo "======================================"
echo ""

echo "Cleaning previous builds..."
flutter clean
echo -e "${GREEN}✓${NC} Clean complete"

echo ""
echo "======================================"
echo "Step 3: Get Dependencies"
echo "======================================"
echo ""

echo "Getting Flutter dependencies..."
flutter pub get
echo -e "${GREEN}✓${NC} Dependencies retrieved"

echo ""
echo "======================================"
echo "Step 4: Analyze Code"
echo "======================================"
echo ""

echo "Running Flutter analyzer..."
flutter analyze --no-fatal-infos || echo -e "${YELLOW}⚠${NC} Analyzer found issues (review above)"

echo ""
echo "======================================"
echo "Step 5: Validate iOS Configuration"
echo "======================================"
echo ""

# Check iOS Podfile
echo "Checking iOS Podfile..."
if [ -f "ios/Podfile" ]; then
    echo -e "${GREEN}✓${NC} iOS Podfile exists"
    
    # Check platform version
    if grep -q "platform :ios, '15.0'" ios/Podfile; then
        echo -e "${GREEN}✓${NC} iOS platform set to 15.0"
    else
        echo -e "${YELLOW}⚠${NC} iOS platform version may not be 15.0"
    fi
    
    # Check post_install hook
    if grep -q "post_install" ios/Podfile; then
        echo -e "${GREEN}✓${NC} post_install hook present"
    else
        echo -e "${YELLOW}⚠${NC} post_install hook missing"
    fi
else
    echo -e "${RED}✗${NC} iOS Podfile not found"
fi

# Check iOS Info.plist
echo ""
echo "Checking iOS Info.plist permissions..."
if [ -f "ios/Runner/Info.plist" ]; then
    echo -e "${GREEN}✓${NC} iOS Info.plist exists"
    
    # Check for key permissions
    if grep -q "NSBluetoothAlwaysUsageDescription" ios/Runner/Info.plist; then
        echo -e "${GREEN}✓${NC} Bluetooth permission present"
    else
        echo -e "${RED}✗${NC} Bluetooth permission missing"
    fi
    
    if grep -q "NSCameraUsageDescription" ios/Runner/Info.plist; then
        echo -e "${GREEN}✓${NC} Camera permission present"
    else
        echo -e "${YELLOW}⚠${NC} Camera permission missing"
    fi
    
    if grep -q "NSLocationWhenInUseUsageDescription" ios/Runner/Info.plist; then
        echo -e "${GREEN}✓${NC} Location permission present"
    else
        echo -e "${YELLOW}⚠${NC} Location permission missing"
    fi
else
    echo -e "${RED}✗${NC} iOS Info.plist not found"
fi

echo ""
echo "======================================"
echo "Step 6: Validate macOS Configuration"
echo "======================================"
echo ""

# Check macOS Podfile
echo "Checking macOS Podfile..."
if [ -f "macos/Podfile" ]; then
    echo -e "${GREEN}✓${NC} macOS Podfile exists"
    
    # Check platform version
    if grep -q "platform :osx, '12.0'" macos/Podfile; then
        echo -e "${GREEN}✓${NC} macOS platform set to 12.0"
    else
        echo -e "${YELLOW}⚠${NC} macOS platform version may not be 12.0"
    fi
    
    # Check post_install hook
    if grep -q "post_install" macos/Podfile; then
        echo -e "${GREEN}✓${NC} post_install hook present"
    else
        echo -e "${YELLOW}⚠${NC} post_install hook missing"
    fi
    
    # Check M1 optimization
    if grep -q "ARCHS" macos/Podfile; then
        echo -e "${GREEN}✓${NC} Apple Silicon optimization present"
    else
        echo -e "${YELLOW}⚠${NC} Apple Silicon optimization may be missing"
    fi
else
    echo -e "${RED}✗${NC} macOS Podfile not found"
fi

# Check macOS Info.plist
echo ""
echo "Checking macOS Info.plist permissions..."
if [ -f "macos/Runner/Info.plist" ]; then
    echo -e "${GREEN}✓${NC} macOS Info.plist exists"
    
    # Check for key permissions
    if grep -q "NSBluetoothAlwaysUsageDescription" macos/Runner/Info.plist; then
        echo -e "${GREEN}✓${NC} Bluetooth permission present"
    else
        echo -e "${RED}✗${NC} Bluetooth permission missing"
    fi
    
    if grep -q "NSCameraUsageDescription" macos/Runner/Info.plist; then
        echo -e "${GREEN}✓${NC} Camera permission present"
    else
        echo -e "${YELLOW}⚠${NC} Camera permission missing"
    fi
    
    if grep -q "NSLocationWhenInUseUsageDescription" macos/Runner/Info.plist; then
        echo -e "${GREEN}✓${NC} Location permission present"
    else
        echo -e "${YELLOW}⚠${NC} Location permission missing"
    fi
else
    echo -e "${RED}✗${NC} macOS Info.plist not found"
fi

echo ""
echo "======================================"
echo "Step 7: Check Dependencies"
echo "======================================"
echo ""

# Check critical packages
echo "Checking critical packages..."

if grep -q "flutter_blue_plus:" pubspec.yaml; then
    echo -e "${GREEN}✓${NC} flutter_blue_plus present (BLE)"
else
    echo -e "${RED}✗${NC} flutter_blue_plus missing"
fi

if grep -q "firebase_core:" pubspec.yaml; then
    echo -e "${GREEN}✓${NC} firebase_core present"
else
    echo -e "${RED}✗${NC} firebase_core missing"
fi

if grep -q "firebase_messaging:" pubspec.yaml; then
    echo -e "${GREEN}✓${NC} firebase_messaging present"
else
    echo -e "${RED}✗${NC} firebase_messaging missing"
fi

echo ""
echo "======================================"
echo "Step 8: Documentation Check"
echo "======================================"
echo ""

# Check for new documentation files
if [ -f "IOS_MACOS_SETUP_GUIDE.md" ]; then
    echo -e "${GREEN}✓${NC} Setup guide present"
else
    echo -e "${YELLOW}⚠${NC} Setup guide missing"
fi

if [ -f "IOS_MACOS_TEST_CHECKLIST.md" ]; then
    echo -e "${GREEN}✓${NC} Test checklist present"
else
    echo -e "${YELLOW}⚠${NC} Test checklist missing"
fi

if [ -f "DEVICE_OPTIMIZATION_NOTES.md" ]; then
    echo -e "${GREEN}✓${NC} Device optimization notes present"
else
    echo -e "${YELLOW}⚠${NC} Device optimization notes missing"
fi

echo ""
echo "======================================"
echo "Validation Summary"
echo "======================================"
echo ""

echo "Build validation complete!"
echo ""
echo "Next steps:"
echo "1. Review any warnings or errors above"
echo "2. If using a Mac with Xcode, run:"
echo "   cd ios && pod install && cd .."
echo "   cd macos && pod install && cd .."
echo "3. Follow IOS_MACOS_SETUP_GUIDE.md for device setup"
echo "4. Use IOS_MACOS_TEST_CHECKLIST.md for testing"
echo ""
echo "For device-specific optimizations, see:"
echo "DEVICE_OPTIMIZATION_NOTES.md"
echo ""
