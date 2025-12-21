#!/bin/bash
# ============================================================================
# TekNeck HVAC Support App - Overnight Automation Script (ENHANCED)
# ============================================================================
# Comprehensive production-readiness checks for overnight unattended runs.
#
# Usage:
#   cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app
#   nohup ./scripts/overnight-tasks.sh > overnight.log 2>&1 &
#
# ============================================================================

# Load shell profile to get PATH (needed for nohup)
export PATH="/Users/joeykeilbarth/flutter/bin:/usr/local/bin:/Users/joeykeilbarth/.nvm/versions/node/v22.16.0/bin:$PATH"

# Don't exit on first error - run everything and report at the end
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Track failures for summary
FAILURES=()
WARNINGS=()

# Create logs directory
mkdir -p "$LOG_DIR"

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}TekNeck ENHANCED Overnight Automation - $TIMESTAMP${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# ============================================================================
# 1. PHONE SETUP (if connected)
# ============================================================================
echo -e "${YELLOW}[1/14] Checking Android device...${NC}"

if adb devices 2>/dev/null | grep -q "device$"; then
    DEVICE_ID=$(adb devices | grep "device$" | head -1 | awk '{print $1}')
    echo -e "${GREEN}✓ Device connected: $DEVICE_ID${NC}"
    
    # Keep phone awake while plugged in
    adb shell settings put global stay_on_while_plugged_in 3 2>/dev/null
    echo "  → Screen will stay on while charging"
    
    # Disable screen timeout
    adb shell settings put system screen_off_timeout 2147483647 2>/dev/null
    echo "  → Screen timeout disabled"
else
    echo -e "${YELLOW}⚠ No Android device connected - skipping device tasks${NC}"
    WARNINGS+=("No Android device connected")
    DEVICE_ID=""
fi

# ============================================================================
# 2. CLEAN BUILD
# ============================================================================
echo ""
echo -e "${YELLOW}[2/14] Cleaning build cache...${NC}"
cd "$PROJECT_DIR"
flutter clean > "$LOG_DIR/clean_$TIMESTAMP.log" 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Clean complete${NC}"
else
    echo -e "${RED}✗ Clean failed${NC}"
    FAILURES+=("Flutter clean failed")
fi

# ============================================================================
# 3. GET DEPENDENCIES
# ============================================================================
echo ""
echo -e "${YELLOW}[3/14] Getting dependencies...${NC}"
flutter pub get > "$LOG_DIR/pubget_$TIMESTAMP.log" 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Dependencies resolved${NC}"
else
    echo -e "${RED}✗ Pub get failed${NC}"
    FAILURES+=("Flutter pub get failed")
fi

# ============================================================================
# 4. ANALYZE CODE (Static Analysis)
# ============================================================================
echo ""
echo -e "${YELLOW}[4/14] Running Flutter analyze...${NC}"
flutter analyze --no-fatal-infos > "$LOG_DIR/analyze_$TIMESTAMP.log" 2>&1
ANALYZE_EXIT=$?
ANALYZE_ERRORS=$(grep -c " error " "$LOG_DIR/analyze_$TIMESTAMP.log" 2>/dev/null || echo "0")
ANALYZE_WARNINGS=$(grep -c " warning " "$LOG_DIR/analyze_$TIMESTAMP.log" 2>/dev/null || echo "0")
ANALYZE_INFO=$(grep -c " info " "$LOG_DIR/analyze_$TIMESTAMP.log" 2>/dev/null || echo "0")

if [ "$ANALYZE_ERRORS" -gt 0 ] || [ $ANALYZE_EXIT -ne 0 ]; then
    echo -e "${RED}✗ Analyze: $ANALYZE_ERRORS errors, $ANALYZE_WARNINGS warnings${NC}"
    FAILURES+=("Static analysis found $ANALYZE_ERRORS errors")
else
    echo -e "${GREEN}✓ Analyze: $ANALYZE_ERRORS errors, $ANALYZE_WARNINGS warnings, $ANALYZE_INFO info${NC}"
fi

# ============================================================================
# 5. CHECK FOR SECURITY ISSUES (Hardcoded secrets, API keys)
# ============================================================================
echo ""
echo -e "${YELLOW}[5/14] Checking for hardcoded secrets...${NC}"
SECRETS_LOG="$LOG_DIR/secrets_$TIMESTAMP.log"
echo "Scanning for potential secrets in lib/..." > "$SECRETS_LOG"

# Search for common secret patterns (excluding comments and false positives)
grep -rn --include="*.dart" -E "(api[_-]?key|secret|password|token|credential)\s*[:=]\s*['\"][^'\"]{10,}" lib/ 2>/dev/null >> "$SECRETS_LOG" || true
grep -rn --include="*.dart" -E "sk_live_|pk_live_|AIza|AKIA" lib/ 2>/dev/null >> "$SECRETS_LOG" || true

SECRET_COUNT=$(wc -l < "$SECRETS_LOG" | tr -d ' ')
if [ "$SECRET_COUNT" -gt 1 ]; then
    echo -e "${RED}✗ Found $((SECRET_COUNT-1)) potential hardcoded secrets!${NC}"
    echo "  Check: $SECRETS_LOG"
    FAILURES+=("Potential hardcoded secrets found")
else
    echo -e "${GREEN}✓ No hardcoded secrets detected${NC}"
fi

# ============================================================================
# 6. CHECK FOR TODO/FIXME/HACK in Code
# ============================================================================
echo ""
echo -e "${YELLOW}[6/14] Checking for TODO/FIXME/HACK comments...${NC}"
TODO_LOG="$LOG_DIR/todos_$TIMESTAMP.log"
grep -rn --include="*.dart" -E "(TODO|FIXME|HACK|XXX|BUG):" lib/ > "$TODO_LOG" 2>/dev/null || true
TODO_COUNT=$(wc -l < "$TODO_LOG" | tr -d ' ')

if [ "$TODO_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $TODO_COUNT TODO/FIXME comments${NC}"
    WARNINGS+=("$TODO_COUNT TODO/FIXME comments in code")
else
    echo -e "${GREEN}✓ No TODO/FIXME comments${NC}"
fi

# ============================================================================
# 7. CHECK FOR PRINT STATEMENTS (Should use logging)
# ============================================================================
echo ""
echo -e "${YELLOW}[7/14] Checking for debug print statements...${NC}"
PRINTS_LOG="$LOG_DIR/prints_$TIMESTAMP.log"
grep -rn --include="*.dart" -E "^\s*print\(" lib/ > "$PRINTS_LOG" 2>/dev/null || true
PRINT_COUNT=$(wc -l < "$PRINTS_LOG" | tr -d ' ')

if [ "$PRINT_COUNT" -gt 20 ]; then
    echo -e "${YELLOW}⚠ Found $PRINT_COUNT print() statements (consider using proper logging)${NC}"
    WARNINGS+=("$PRINT_COUNT print() statements should use logging")
else
    echo -e "${GREEN}✓ Print statement count acceptable ($PRINT_COUNT)${NC}"
fi

# ============================================================================
# 8. RUN UNIT/WIDGET TESTS
# ============================================================================
echo ""
echo -e "${YELLOW}[8/14] Running Flutter tests...${NC}"
flutter test --coverage > "$LOG_DIR/test_$TIMESTAMP.log" 2>&1
TEST_EXIT=$?
if [ $TEST_EXIT -eq 0 ]; then
    TEST_RESULT=$(grep -E "^[0-9]+ tests? passed" "$LOG_DIR/test_$TIMESTAMP.log" 2>/dev/null || echo "Tests passed")
    echo -e "${GREEN}✓ Tests: $TEST_RESULT${NC}"
else
    TEST_FAILURES=$(grep -c "FAILED" "$LOG_DIR/test_$TIMESTAMP.log" 2>/dev/null || echo "unknown")
    echo -e "${RED}✗ Tests failed: $TEST_FAILURES failures${NC}"
    FAILURES+=("Flutter tests failed")
fi

# ============================================================================
# 9. BUILD DEBUG APK
# ============================================================================
echo ""
echo -e "${YELLOW}[9/14] Building debug APK...${NC}"
flutter build apk --debug > "$LOG_DIR/build_debug_$TIMESTAMP.log" 2>&1
if [ -f "$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk" ]; then
    APK_SIZE=$(du -h "$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk" | cut -f1)
    echo -e "${GREEN}✓ Debug APK built: $APK_SIZE${NC}"
else
    echo -e "${RED}✗ Debug APK build failed${NC}"
    FAILURES+=("Debug APK build failed")
fi

# ============================================================================
# 10. BUILD RELEASE APK
# ============================================================================
echo ""
echo -e "${YELLOW}[10/14] Building release APK...${NC}"
flutter build apk --release > "$LOG_DIR/build_release_$TIMESTAMP.log" 2>&1
if [ -f "$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk" ]; then
    APK_SIZE=$(du -h "$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk" | cut -f1)
    echo -e "${GREEN}✓ Release APK built: $APK_SIZE${NC}"
else
    echo -e "${YELLOW}⚠ Release APK build failed (may need signing)${NC}"
    WARNINGS+=("Release APK build failed")
fi

# ============================================================================
# 11. FIREBASE CLI CHECKS
# ============================================================================
echo ""
echo -e "${YELLOW}[11/14] Running Firebase checks...${NC}"
FIREBASE_LOG="$LOG_DIR/firebase_$TIMESTAMP.log"

if command -v firebase &> /dev/null; then
    echo "Firebase CLI found" > "$FIREBASE_LOG"
    
    # Check Firebase login status
    firebase login:list >> "$FIREBASE_LOG" 2>&1
    if firebase login:list 2>&1 | grep -q "@"; then
        echo -e "${GREEN}✓ Firebase: Logged in${NC}"
        
        # List projects
        echo "  → Checking accessible projects..."
        firebase projects:list >> "$FIREBASE_LOG" 2>&1 || true
        
        # Check if we can access the project
        if [ -f "$PROJECT_DIR/android/app/google-services.json" ]; then
            PROJECT_ID=$(grep -o '"project_id": "[^"]*"' "$PROJECT_DIR/android/app/google-services.json" | head -1 | cut -d'"' -f4)
            if [ -n "$PROJECT_ID" ]; then
                echo "  → Project: $PROJECT_ID"
                
                # Test Firestore connection (dry run)
                echo "  → Testing Firestore rules..."
                firebase --project="$PROJECT_ID" firestore:indexes >> "$FIREBASE_LOG" 2>&1 && \
                    echo -e "${GREEN}✓ Firestore accessible${NC}" || \
                    echo -e "${YELLOW}⚠ Firestore check skipped (may need permissions)${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ Firebase: Not logged in (run 'firebase login')${NC}"
        WARNINGS+=("Firebase CLI not logged in")
    fi
else
    echo -e "${YELLOW}⚠ Firebase CLI not installed${NC}"
    WARNINGS+=("Firebase CLI not installed")
fi

# ============================================================================
# 12. CHECK APP PERMISSIONS (AndroidManifest)
# ============================================================================
echo ""
echo -e "${YELLOW}[12/14] Checking Android permissions...${NC}"
PERMS_LOG="$LOG_DIR/permissions_$TIMESTAMP.log"
MANIFEST="$PROJECT_DIR/android/app/src/main/AndroidManifest.xml"

if [ -f "$MANIFEST" ]; then
    echo "Permissions in AndroidManifest.xml:" > "$PERMS_LOG"
    grep -o 'android.permission.[A-Z_]*' "$MANIFEST" | sort | uniq >> "$PERMS_LOG"
    PERM_COUNT=$(grep -c 'android.permission' "$MANIFEST" || echo "0")
    echo -e "${GREEN}✓ Found $PERM_COUNT Android permissions${NC}"
    
    # Check for dangerous permissions
    DANGEROUS=$(grep -E "(READ_SMS|SEND_SMS|READ_CONTACTS|ACCESS_FINE_LOCATION|CAMERA|RECORD_AUDIO)" "$MANIFEST" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DANGEROUS" -gt 0 ]; then
        echo -e "${YELLOW}  ⚠ $DANGEROUS dangerous permissions (require user consent)${NC}"
    fi
else
    echo -e "${RED}✗ AndroidManifest.xml not found${NC}"
    FAILURES+=("AndroidManifest.xml missing")
fi

# ============================================================================
# 13. ON-DEVICE INTEGRATION TEST (if device connected)
# ============================================================================
echo ""
echo -e "${YELLOW}[13/15] Running on-device smoke test...${NC}"

if [ -n "$DEVICE_ID" ]; then
    INTEGRATION_LOG="$LOG_DIR/integration_$TIMESTAMP.log"
    
    # Install and launch app
    echo "  → Installing debug APK..."
    adb install -r "$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk" >> "$INTEGRATION_LOG" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  → Launching app..."
        adb shell am start -n com.tekneckjoe.tektool/.MainActivity >> "$INTEGRATION_LOG" 2>&1
        sleep 5
        
        # Check if app is running
        APP_RUNNING=$(adb shell pidof com.tekneckjoe.tektool 2>/dev/null)
        if [ -n "$APP_RUNNING" ]; then
            echo -e "${GREEN}✓ App launched successfully (PID: $APP_RUNNING)${NC}"
            
            # Take screenshot
            echo "  → Taking screenshot..."
            adb shell screencap -p /sdcard/tekneck_test.png 2>/dev/null
            adb pull /sdcard/tekneck_test.png "$LOG_DIR/screenshot_$TIMESTAMP.png" 2>/dev/null && \
                echo "  → Screenshot saved: logs/screenshot_$TIMESTAMP.png"
            
            # Check logcat for crashes
            echo "  → Checking for crashes..."
            adb logcat -d -s AndroidRuntime:E | tail -50 >> "$INTEGRATION_LOG" 2>&1
            CRASHES=$(grep -c "FATAL EXCEPTION" "$INTEGRATION_LOG" 2>/dev/null || echo "0")
            if [ "$CRASHES" -gt 0 ]; then
                echo -e "${RED}✗ Found $CRASHES crash(es) in logcat!${NC}"
                FAILURES+=("App crashed during smoke test")
            else
                echo -e "${GREEN}✓ No crashes detected${NC}"
            fi
            
            # Check for Firebase errors
            adb logcat -d | grep -i "firebase\|firestore" | grep -i "error\|exception" | tail -10 >> "$INTEGRATION_LOG" 2>&1
            FIREBASE_ERRORS=$(grep -c -i "error\|exception" "$INTEGRATION_LOG" 2>/dev/null || echo "0")
            if [ "$FIREBASE_ERRORS" -gt 5 ]; then
                echo -e "${YELLOW}⚠ Firebase errors in logcat${NC}"
                WARNINGS+=("Firebase errors detected in logcat")
            fi
        else
            echo -e "${RED}✗ App failed to start${NC}"
            FAILURES+=("App failed to start on device")
        fi
    else
        echo -e "${RED}✗ APK install failed${NC}"
        FAILURES+=("APK install failed")
    fi
else
    echo -e "${YELLOW}⚠ No device - skipping integration test${NC}"
fi

# ============================================================================
# 14. FULL UI INTEGRATION TESTS (if device connected)
# ============================================================================
echo ""
echo -e "${YELLOW}[14/15] Running full UI integration tests...${NC}"

if [ -n "$DEVICE_ID" ]; then
    UI_TEST_LOG="$LOG_DIR/ui_test_$TIMESTAMP.log"
    UI_REPORT="$LOG_DIR/ui_test_report_$TIMESTAMP.txt"
    
    echo "  → Running integration tests on device..."
    echo "  → This tests ALL screens and buttons (skipping BLE)..."
    
    cd "$PROJECT_DIR"
    
    # Run integration tests with timeout (10 minutes max)
    timeout 600 flutter drive \
        --driver=integration_test/test_driver.dart \
        --target=integration_test/app_test.dart \
        --device-id="$DEVICE_ID" \
        > "$UI_TEST_LOG" 2>&1
    
    UI_TEST_EXIT=$?
    
    # Copy report if generated
    if [ -f "$PROJECT_DIR/integration_test_report.txt" ]; then
        mv "$PROJECT_DIR/integration_test_report.txt" "$UI_REPORT"
        echo "  → UI test report saved: logs/ui_test_report_$TIMESTAMP.txt"
    fi
    
    if [ $UI_TEST_EXIT -eq 0 ]; then
        echo -e "${GREEN}✓ All UI integration tests passed!${NC}"
        
        # Extract summary from log
        PASSED=$(grep -c "✅" "$UI_REPORT" 2>/dev/null || echo "0")
        SKIPPED=$(grep -c "⏭️" "$UI_REPORT" 2>/dev/null || echo "0")
        echo "  → Passed: $PASSED, Skipped: $SKIPPED"
    else
        echo -e "${RED}✗ UI integration tests failed${NC}"
        FAILURES+=("UI integration tests failed")
        
        # Show last few lines of error
        echo "  → Last errors:"
        tail -10 "$UI_TEST_LOG" | sed 's/^/      /'
    fi
else
    echo -e "${YELLOW}⚠ No device - skipping UI integration tests${NC}"
    WARNINGS+=("UI integration tests skipped - no device")
fi

# ============================================================================
# 15. CAPTURE BLE LOGS (if device connected)
# ============================================================================
echo ""
echo -e "${YELLOW}[15/15] Capturing BLE logs...${NC}"

if [ -n "$DEVICE_ID" ]; then
    BLE_DIR="$PROJECT_DIR/docs/BLE-Sniffing"
    mkdir -p "$BLE_DIR"
    
    # Pull bugreport with HCI snoop log
    echo "  → Pulling bugreport (this takes 1-2 minutes)..."
    adb bugreport "$BLE_DIR/bugreport_$TIMESTAMP.zip" > /dev/null 2>&1 || true
    
    if [ -f "$BLE_DIR/bugreport_$TIMESTAMP.zip" ]; then
        echo "  → Extracting..."
        unzip -q -o "$BLE_DIR/bugreport_$TIMESTAMP.zip" -d "$BLE_DIR/extracted_$TIMESTAMP/" 2>/dev/null || true
        
        if [ -f "$BLE_DIR/extracted_$TIMESTAMP/FS/data/log/bt/btsnoop_hci.log" ]; then
            HCI_SIZE=$(du -h "$BLE_DIR/extracted_$TIMESTAMP/FS/data/log/bt/btsnoop_hci.log" | cut -f1)
            echo -e "${GREEN}✓ HCI snoop log captured: $HCI_SIZE${NC}"
        else
            echo -e "${YELLOW}⚠ HCI snoop log not found (is BLE logging enabled?)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Bugreport capture failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No device - skipping BLE capture${NC}"
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}OVERNIGHT RUN COMPLETE${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo "Logs saved to: $LOG_DIR/"
ls -1 "$LOG_DIR"/*_$TIMESTAMP.* 2>/dev/null | sed 's/.*\//  - /'
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ANALYSIS SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Static Analysis:"
echo "    Errors:   $ANALYZE_ERRORS"
echo "    Warnings: $ANALYZE_WARNINGS"
echo "    Info:     $ANALYZE_INFO"
echo "  Code Quality:"
echo "    TODOs:    $TODO_COUNT"
echo "    Prints:   $PRINT_COUNT"
echo ""

if [ ${#FAILURES[@]} -gt 0 ]; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ FAILURES (${#FAILURES[@]})${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    for f in "${FAILURES[@]}"; do
        echo -e "${RED}  ✗ $f${NC}"
    done
    echo ""
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠ WARNINGS (${#WARNINGS[@]})${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    for w in "${WARNINGS[@]}"; do
        echo -e "${YELLOW}  ⚠ $w${NC}"
    done
    echo ""
fi

if [ ${#FAILURES[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ ALL CHECKS PASSED - PRODUCTION READY!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
elif [ ${#FAILURES[@]} -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ NO CRITICAL FAILURES - Review warnings above${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ ${#FAILURES[@]} FAILURES REQUIRE ATTENTION${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi

echo ""
echo "Finished at: $(date)"
echo ""
