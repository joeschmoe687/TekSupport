#!/bin/bash
#
# Automated Field BLE Sniffer - Real-Time Probe Detection
# For TekNeck HVAC Support App
#
# Usage:
#   ./field_ble_sniffer.sh              # Interactive mode
#   ./field_ble_sniffer.sh --once       # Single pull + analyze
#   ./field_ble_sniffer.sh --auto       # Auto-pull + analyze loop (every 30s)
#   ./field_ble_sniffer.sh --upload     # Single pull + upload to Firebase
#   ./field_ble_sniffer.sh --help       # Show help
#
# Environment Variables:
#   UPLOAD_TO_FIREBASE=true   # Enable Firebase auto-upload
#

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJ="/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/TekNeck-HVAC_TekMate/hvac_support_app"
DEVICE=""  # Auto-detect first connected device
SNIFF_DIR="$PROJ/docs/BLE-Sniffing"
REPORTS_DIR="$SNIFF_DIR/reports"
UPLOAD_TO_FIREBASE=false  # Set to true to auto-upload to Firebase

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_device() {
    log_info "Checking device connection..."
    
    # Auto-detect first connected device if DEVICE is empty
    if [ -z "$DEVICE" ]; then
        DEVICE=$(adb devices | grep -w "device" | head -1 | awk '{print $1}')
        if [ -z "$DEVICE" ]; then
            log_error "No Android devices connected"
            log_info "Available devices:"
            adb devices
            exit 1
        fi
        log_info "Auto-detected device: $DEVICE"
    fi
    
    # Verify device is online
    if ! adb devices | grep -q "$DEVICE"; then
        log_error "Device $DEVICE not connected. Available devices:"
        adb devices | grep -v "^List"
        return 1
    fi
    log_success "Device $DEVICE connected"
}

check_hci_logging() {
    STATUS=$(adb shell getprop persist.bluetooth.hcidump)
    if [ "$STATUS" = "1" ]; then
        log_success "Bluetooth HCI snoop logging enabled"
    else
        log_warning "Bluetooth HCI snoop logging disabled"
        log_info "Enable: Settings → Developer Options → Bluetooth HCI snoop log"
        read -p "Enable now and press enter when done, or press Ctrl+C to cancel"
        STATUS=$(adb shell getprop persist.bluetooth.hcidump)
        if [ "$STATUS" != "1" ]; then
            log_error "HCI logging still not enabled"
            exit 1
        fi
    fi
}

pull_hci_log() {
    local TS=$(date +%Y%m%d_%H%M%S)
    local BUGREPORT="$SNIFF_DIR/bugreport_${TS}.zip"
    local EXTRACT_DIR="$SNIFF_DIR/extracted_${TS}_${DEVICE}"
    local HCILOG="$EXTRACT_DIR/FS/data/log/bt/btsnoop_hci.log"
    
    log_info "Pulling bugreport from device (may take 20-60 seconds)..."
    
    if ! adb bugreport "$BUGREPORT"; then
        log_error "Failed to pull bugreport"
        return 1
    fi
    
    local SIZE=$(du -h "$BUGREPORT" | cut -f1)
    log_success "Bugreport saved ($SIZE): $BUGREPORT"
    
    log_info "Extracting bugreport..."
    mkdir -p "$EXTRACT_DIR"
    
    if ! unzip -q "$BUGREPORT" -d "$EXTRACT_DIR"; then
        log_error "Failed to extract bugreport"
        return 1
    fi
    
    if [ ! -f "$HCILOG" ]; then
        log_error "HCI log not found in bugreport"
        log_info "Checking for alternative locations..."
        find "$EXTRACT_DIR" -iname "*snoop*.log" -type f || true
        return 1
    fi
    
    local HCI_SIZE=$(du -h "$HCILOG" | cut -f1)
    log_success "HCI log extracted ($HCI_SIZE): $HCILOG"
    
    # Copy to reports for analysis
    mkdir -p "$REPORTS_DIR"
    cp "$HCILOG" "$REPORTS_DIR/btsnoop_${TS}_${DEVICE}.log"
    log_success "Copied to reports: $REPORTS_DIR/btsnoop_${TS}_${DEVICE}.log"
    
    local REPORT_PATH="$REPORTS_DIR/btsnoop_${TS}_${DEVICE}.log"
    
    # Auto-upload to Firebase if enabled
    upload_to_firebase "$REPORT_PATH"
    
    echo "$REPORT_PATH"
}

analyze_with_ml() {
    local HCILOG=$1
    
    log_info "Running ML analysis on HCI log..."
    
    # For now, use parse_testo_live.py for analysis
    if [ ! -f "$HCILOG" ]; then
        log_error "HCI log not found: $HCILOG"
        return 1
    fi
    
    local SIZE=$(du -h "$HCILOG" | cut -f1)
    log_success "HCI log ready for analysis ($SIZE)"
    
    # Run Python parser
    if [ -f "$SNIFF_DIR/parse_testo_live.py" ]; then
        log_info "Parsing Testo probe data..."
        local ANALYSIS_OUTPUT="${HCILOG%.log}_analysis.txt"
        python3 "$SNIFF_DIR/parse_testo_live.py" "$HCILOG" | tee "$ANALYSIS_OUTPUT"
        log_success "Analysis saved: $ANALYSIS_OUTPUT"
    else
        log_warning "Parser not found: $SNIFF_DIR/parse_testo_live.py"
    fi
}

upload_to_firebase() {
    local HCILOG=$1
    
    if [ "$UPLOAD_TO_FIREBASE" != "true" ]; then
        return 0
    fi
    
    log_info "Uploading to Firebase Cloud Storage..."
    
    # Get device info
    local DEVICE_MODEL=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    local ANDROID_VERSION=$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
    local SERIAL=$(adb shell getprop ro.serialno 2>/dev/null | tr -d '\r')
    
    # Upload using Node.js script
    if [ -f "$PROJ/scripts/upload_to_firebase.js" ]; then
        cd "$PROJ/scripts"
        node upload_to_firebase.js "$HCILOG" \
            --device-model "$DEVICE_MODEL" \
            --android-version "$ANDROID_VERSION" \
            --device-serial "$SERIAL"
        
        if [ $? -eq 0 ]; then
            log_success "Successfully uploaded to Firebase!"
        else
            log_warning "Firebase upload failed (continuing anyway)"
        fi
    else
        log_warning "Firebase upload script not found"
    fi
}

show_menu() {
    echo ""
    echo "=========================================="
    echo "  Automated Field BLE Sniffer"
    echo "=========================================="
    echo "1) Pull HCI log from device"
    echo "2) Pull + Analyze with ML"
    echo "3) Show recent captures"
    echo "4) Check device status"
    echo "5) Exit"
    echo ""
    read -p "Select option (1-5): " choice
    
    case $choice in
        1) pull_hci_log ;;
        2) 
            HCILOG=$(pull_hci_log)
            if [ -n "$HCILOG" ]; then
                analyze_with_ml "$HCILOG"
            fi
            ;;
        3) show_recent ;;
        4) check_device && check_hci_logging ;;
        5) exit 0 ;;
        *) log_error "Invalid option" ;;
    esac
}

show_recent() {
    log_info "Recent HCI captures in reports/:"
    echo ""
    ls -lh "$REPORTS_DIR"/btsnoop_*.log 2>/dev/null | tail -10 || log_warning "No captures yet"
    echo ""
}

show_help() {
    cat <<EOF
Usage: ./field_ble_sniffer.sh [OPTIONS]

OPTIONS:
    --once          Pull once, analyze, and exit
    --auto          Run automated pull + analysis loop (pull every 30 seconds)
    --upload        Pull once, analyze, and upload to Firebase
    --help          Show this help message

ENVIRONMENT VARIABLES:
    UPLOAD_TO_FIREBASE=true   Enable automatic Firebase upload for all captures

EXAMPLES:
    # Interactive menu
    ./field_ble_sniffer.sh

    # Pull once
    ./field_ble_sniffer.sh --once

    # Pull once and upload to Firebase
    ./field_ble_sniffer.sh --upload

    # Continuous monitoring (pulls every 30s)
    ./field_ble_sniffer.sh --auto

    # Auto-upload enabled for continuous monitoring
    UPLOAD_TO_FIREBASE=true ./field_ble_sniffer.sh --auto

WHAT THIS DOES:
    1. Pulls Bluetooth HCI snoop log from your Android device via adb bugreport
    2. Extracts the btsnoop_hci.log file
    3. Parses Testo probe measurements (pressure, temperature)
    4. Optionally uploads to Firebase Cloud Storage (ble_sniff_logs collection)

FIREBASE UPLOAD:
    When enabled, each capture is automatically uploaded to:
    - Cloud Storage: gs://tekneck-support.appspot.com/ble_sniff_logs/
    - Firestore: ble_sniff_logs/{sessionId}
    
    Captures ALL BLE traffic regardless of which app is connected to probes!

REQUIREMENTS:
    - Android device connected via USB with USB debugging enabled
    - Developer Options → Bluetooth HCI snoop log enabled
    - adb installed (Flutter SDK provides this)
    - For Firebase upload: Node.js + firebase-admin installed

EOF
}

auto_loop() {
    log_success "Starting auto-pull loop (every 30 seconds)"
    log_info "Press Ctrl+C to stop"
    echo ""
    
    counter=0
    while true; do
        counter=$((counter + 1))
        TS=$(date '+%Y-%m-%d %H:%M:%S')
        echo ""
        echo "========== Pull #$counter at $TS =========="
        
        if pull_hci_log; then
            log_success "Pull #$counter complete"
        else
            log_error "Pull #$counter failed"
        fi
        
        log_info "Waiting 30 seconds before next pull (Ctrl+C to stop)..."
        sleep 30
    done
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Parse arguments
    case "${1:-}" in
        --auto)
            check_device || exit 1
            check_hci_logging
            auto_loop
            ;;
        --once)
            check_device || exit 1
            check_hci_logging
            HCILOG=$(pull_hci_log)
            if [ -n "$HCILOG" ]; then
                analyze_with_ml "$HCILOG"
            fi
            ;;
        --upload)
            UPLOAD_TO_FIREBASE=true
            check_device || exit 1
            check_hci_logging
            HCILOG=$(pull_hci_log)
            if [ -n "$HCILOG" ]; then
                analyze_with_ml "$HCILOG"
            fi
            ;;
        --help|-h)
            show_help
            ;;
        *)
            # Interactive mode
            check_device || exit 1
            check_hci_logging
            
            while true; do
                show_menu
                read -p "Press enter to continue..."
            done
            ;;
    esac
}

# Run main
main "$@"
