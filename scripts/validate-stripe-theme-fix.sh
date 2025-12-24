#!/bin/bash

# Stripe Theme Fix Validation Script
# Run this script to verify the theme fix is working correctly

set -e

echo "========================================="
echo "Stripe Theme Fix Validation Script"
echo "========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Verify theme files
echo "Step 1: Verifying theme files..."
echo ""

echo "Checking values/styles.xml..."
VALUES_LAUNCH=$(grep -o 'parent="Theme.AppCompat.Light.NoActionBar"' android/app/src/main/res/values/styles.xml | wc -l)
if [ "$VALUES_LAUNCH" -eq 2 ]; then
    echo -e "${GREEN}✅ values/styles.xml has correct AppCompat themes${NC}"
else
    echo -e "${RED}❌ values/styles.xml has incorrect themes${NC}"
    exit 1
fi

echo "Checking values-night/styles.xml..."
NIGHT_LAUNCH=$(grep -o 'parent="Theme.AppCompat.Light.NoActionBar"' android/app/src/main/res/values-night/styles.xml | wc -l)
if [ "$NIGHT_LAUNCH" -eq 2 ]; then
    echo -e "${GREEN}✅ values-night/styles.xml has correct AppCompat themes${NC}"
else
    echo -e "${RED}❌ values-night/styles.xml has incorrect themes${NC}"
    exit 1
fi

echo ""

# Step 2: Verify ProGuard rules
echo "Step 2: Verifying ProGuard rules..."
echo ""

if grep -q "androidx.appcompat.app.AppCompatActivity" android/app/proguard-rules.pro; then
    echo -e "${GREEN}✅ ProGuard rules contain AppCompat preservation${NC}"
else
    echo -e "${RED}❌ ProGuard rules missing AppCompat preservation${NC}"
    exit 1
fi

echo ""

# Step 3: Verify AndroidManifest metadata
echo "Step 3: Verifying AndroidManifest metadata..."
echo ""

if grep -q "prefers_colorscheme" android/app/src/main/AndroidManifest.xml; then
    echo -e "${GREEN}✅ AndroidManifest has prefers_colorscheme metadata${NC}"
else
    echo -e "${YELLOW}⚠️  AndroidManifest missing prefers_colorscheme metadata (optional)${NC}"
fi

echo ""

# Step 4: Check for conflicting theme files
echo "Step 4: Checking for conflicting theme files..."
echo ""

THEME_FILES=$(find android/app/src/main/res -name "styles.xml" | wc -l)
echo "Found $THEME_FILES theme files:"
find android/app/src/main/res -name "styles.xml"

if [ "$THEME_FILES" -eq 2 ]; then
    echo -e "${GREEN}✅ Expected number of theme files found${NC}"
else
    echo -e "${YELLOW}⚠️  Unexpected number of theme files (expected 2)${NC}"
fi

echo ""

# Summary
echo "========================================="
echo "Configuration Validation: PASSED ✅"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Clean and rebuild:"
echo "   flutter clean"
echo "   flutter pub get"
echo "   flutter build apk --release"
echo ""
echo "2. Install and test:"
echo "   adb install build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "3. Monitor logs for theme errors:"
echo "   adb logcat -s flutter 2>&1 | grep -i 'stripe\\|theme'"
echo ""
echo "4. Test payment flows:"
echo "   - Phone Call payment"
echo "   - Video Call payment"
echo "   - Text Chat payment"
echo ""
echo "Expected result: No theme errors, payment sheet loads successfully"
echo ""
