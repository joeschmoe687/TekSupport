#!/bin/bash
# Extract Bluetooth HCI snoop logs from Android device and organize for analysis
# 
# Usage:
#   ./scripts/pull_ble_logs.sh pixel         # Pull HCI log with device tag "pixel"
#   ./scripts/pull_ble_logs.sh pixel --full  # Also pull full bugreport
#   ./scripts/pull_ble_logs.sh pixel --csv   # Pull HCI and export to CSV via tshark

set -e

DEVICE="${1:?Usage: $0 <device_name> [--full|--csv]}"
OPTION="${2:-}"
PROJ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLE_DIR="$PROJ_ROOT/docs/BLE-Sniffing"
PHONE_DATA="$BLE_DIR/phone-data"
REPORTS="$BLE_DIR/reports"
TIMESTAMP=$(date +%Y-%m-%d)
DATETIME=$(date +%Y-%m-%d_%H-%M-%S)

# Create directories
mkdir -p "$PHONE_DATA" "$REPORTS"

echo "🔵 BLE Log Extractor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Device: $DEVICE"
echo "Project: $PROJ_ROOT"
echo "Target: $PHONE_DATA"
echo ""

# Check ADB
if ! command -v adb &> /dev/null; then
  echo "❌ adb not found. Install Android SDK Platform Tools."
  exit 1
fi

# Check device connected
if ! adb devices | grep -q "device$"; then
  echo "❌ No Android device connected."
  adb devices
  exit 1
fi
echo "✅ Device detected"
echo ""

# Pull HCI snoop log
echo "📥 Pulling Bluetooth HCI snoop log..."
HCI_FILE="$PHONE_DATA/btsnoop_hci_${TIMESTAMP}_${DEVICE}.log"

if adb pull /sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log "$HCI_FILE" 2>/dev/null; then
  echo "✅ HCI log saved: $(basename "$HCI_FILE")"
elif adb pull /sdcard/btsnoop_hci.log "$HCI_FILE" 2>/dev/null; then
  echo "✅ HCI log saved (fallback path): $(basename "$HCI_FILE")"
else
  echo "⚠️  HCI log not found. Enable 'Bluetooth HCI snoop log' in Developer Options."
  HCI_FILE=""
fi

# Optional: Full bugreport
if [[ "$OPTION" == "--full" ]]; then
  echo ""
  echo "📦 Pulling full bugreport (this may take a minute)..."
  BUGREPORT="$PHONE_DATA/bugreport_${TIMESTAMP}_${DEVICE}.zip"
  adb bugreport "$BUGREPORT" > /dev/null 2>&1 || adb bugreport "$BUGREPORT"
  echo "✅ Bugreport saved: $(basename "$BUGREPORT")"
  
  # Extract bugreport
  EXTRACTED="$BLE_DIR/extracted_${DATETIME}_${DEVICE}"
  mkdir -p "$EXTRACTED"
  echo ""
  echo "📂 Extracting bugreport..."
  unzip -q "$BUGREPORT" -d "$EXTRACTED"
  echo "✅ Extracted to: $(basename "$EXTRACTED")"
  
  # Find HCI log inside bugreport if not already pulled
  if [[ -z "$HCI_FILE" ]]; then
    HCI_FOUND=$(find "$EXTRACTED" -iname "*snoop*.log" -o -iname "btsnoop_hci.log" | head -1)
    if [[ -n "$HCI_FOUND" ]]; then
      HCI_FILE="$HCI_FOUND"
      echo "✅ Found HCI log in bugreport: $(basename "$HCI_FILE")"
    fi
  fi
fi

# Optional: Export to CSV
if [[ "$OPTION" == "--csv" && -n "$HCI_FILE" && -f "$HCI_FILE" ]]; then
  echo ""
  echo "📊 Exporting to CSV (requires tshark)..."
  
  if ! command -v tshark &> /dev/null; then
    echo "⚠️  tshark not found. Install: brew install wireshark"
  else
    CSV_FILE="$REPORTS/hci_packets_${TIMESTAMP}_${DEVICE}.csv"
    tshark -r "$HCI_FILE" -T fields \
      -E header=y -E separator=, \
      -e frame.time \
      -e frame.len \
      -e bluetooth.hci_command_opcode \
      -e bluetooth.hci_event_code \
      -e bluetooth.src \
      -e bluetooth.dst \
      -e bluetooth.uuid \
      -e bluetooth.manufacturer_data \
      > "$CSV_FILE" 2>/dev/null || true
    
    if [[ -f "$CSV_FILE" ]]; then
      ROWS=$(tail -n +2 "$CSV_FILE" | wc -l)
      echo "✅ CSV exported: $(basename "$CSV_FILE") ($ROWS packets)"
    else
      echo "⚠️  CSV export failed (HCI log may be invalid format)"
    fi
  fi
fi

echo ""
echo "📍 Log locations:"
echo "   Phone data: $PHONE_DATA"
echo "   Reports:   $REPORTS"
echo ""
echo "💡 Next steps:"
echo "   - Copy Testo/Fieldpiece .tjf or .csv exports to $REPORTS/"
echo "   - Document capture context in a README"
echo "   - Optional: Upload summary to Firestore ble_sniff_logs"
echo ""
echo "✨ Done!"
