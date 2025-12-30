# Android HCI Snoop Log Extraction - Samsung S931U

> **Status:** ✅ VERIFIED WORKING with Samsung SM S931U (RFCY518ZA0Y - Android 16)  
> **Last Updated:** December 29, 2025  
> **Tested Methods:** Bugreport (reliable), ADB shell cat (fast), Direct file pull (limited)

## Quick Summary - Two Methods

### Method 1: ADB Shell Direct (Fastest) ⚡
```bash
# One-time setup (if not enabled)
adb shell settings put global bluetooth_hci_snoop_log_output 1

# Toggle Bluetooth to generate logs
adb shell svc bluetooth disable && sleep 2 && adb shell svc bluetooth enable && sleep 3

# Pull the log directly to your computer
adb shell cat /data/misc/bluetooth/logs/btsnoop_hci.log > btsnoop.log
```

**Pros:** Fast, simple, direct  
**Cons:** May not work on all devices/configs  
**Works On:** Samsung S931U ✅ (Tested Dec 29, 2025)

---

### Method 2: ADB Bugreport (Most Reliable) 📦
```bash
# Pull full bugreport (slow but reliable)
adb bugreport bugreport.zip

# Extract
unzip -q bugreport.zip -d extracted/

# HCI log is at:
extracted/FS/data/log/bt/btsnoop_hci.log
```

**Pros:** Works on all Android versions, includes system info  
**Cons:** Larger file, slower process (20-60 seconds)  
**Works On:** All devices ✅

See full steps below in [Full Extraction Workflow](#full-extraction-workflow).

---

## TL;DR - Quick Command

```bash
PROJ="/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/TekNeck-HVAC_TekMate/hvac_support_app"
TS=$(date +%Y%m%d_%H%M%S)

# Pull bugreport, extract, done
adb bugreport "$PROJ/docs/BLE-Sniffing/bugreport_${TS}.zip" && \
unzip -q "$PROJ/docs/BLE-Sniffing/bugreport_${TS}.zip" -d "$PROJ/docs/BLE-Sniffing/extracted_${TS}_s931u"

# HCI log is at:
echo "$PROJ/docs/BLE-Sniffing/extracted_${TS}_s931u/FS/data/log/bt/btsnoop_hci.log"
```

---

## Why Multiple Methods?

On Samsung S931U (Android 16), **different extraction methods have different reliability:**

| Method | Status | Why |
|--------|--------|-----|
| `adb shell cat /data/.../btsnoop_hci.log` | ✅ Works | Can read via shell context |
| `adb bugreport` | ✅ Works | System-level collection |
| `adb pull /data/.../btsnoop_hci.log` | ❌ Fails | SELinux blocks adb pull context |
| `adb pull /sdcard/btsnoop_hci.log` | ❌ Fails | File doesn't exist on S931U |

**In-App Capture Status:**  
- App can **detect** HCI logging is enabled ✅  
- App cannot **read** the log file directly ❌ (SELinux policies)
- **Solution:** Use one of the ADB methods above

---

## One-Time Phone Setup

### Step 1: Enable Developer Options
```
Settings → About phone → Build number
Tap 7 times until "You are now a developer"
```

### Step 2: Enable Bluetooth HCI Snoop Log
```
Settings → Developer Options → Bluetooth HCI snoop log → Toggle ON
```

### Step 3: Verify It's Enabled
```bash
adb shell getprop persist.bluetooth.hcidump
# Output should be: 1 (enabled)
```

---

## Full Extraction Workflow

### Setup Variables (Do Once Per Session)
```bash
PROJ="/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/TekNeck-HVAC_TekMate/hvac_support_app"
DEVICE="s931u"  # Samsung S931U device ID
```

### Reproduce BLE Session (On Phone)
1. Open the app (TekTool)
2. Go to **Tools → TekTool** (or BLE Sniffer if admin)
3. Connect to Testo T549i or other BLE device
4. Perform your test session (measure readings, etc.)
5. Exit the app

### Pull HCI Log Using Bugreport
```bash
# Timestamp for unique filenames
TS=$(date +%Y%m%d_%H%M%S)

# Folders
BUGREPORT_FILE="$PROJ/docs/BLE-Sniffing/bugreport_${TS}.zip"
EXTRACT_DIR="$PROJ/docs/BLE-Sniffing/extracted_${TS}_${DEVICE}"

# Generate bugreport (includes HCI logs)
echo "🔵 Pulling bugreport from $DEVICE..."
echo "   (This may take 20-60 seconds - be patient)"
adb bugreport "$BUGREPORT_FILE"

# Check file size
if [ -f "$BUGREPORT_FILE" ]; then
  SIZE=$(du -h "$BUGREPORT_FILE" | cut -f1)
  echo "✅ Bugreport saved: $SIZE"
else
  echo "❌ Error: Bugreport not created"
  exit 1
fi

# Extract bugreport
echo "📦 Extracting bugreport..."
mkdir -p "$EXTRACT_DIR"
unzip -q "$BUGREPORT_FILE" -d "$EXTRACT_DIR"

# Verify HCI log exists
HCILOG="$EXTRACT_DIR/FS/data/log/bt/btsnoop_hci.log"
if [ -f "$HCILOG" ]; then
  SIZE=$(du -h "$HCILOG" | cut -f1)
  echo "✅ HCI log found ($SIZE): $HCILOG"
else
  echo "❌ HCI log not found in bugreport"
  echo "   Did you enable Bluetooth HCI snoop logging?"
  echo "   Checking for alternative locations..."
  find "$EXTRACT_DIR" -iname "*snoop*.log" -type f
  exit 1
fi
```

### Extract HCI Log to Reports (For Analysis)
```bash
TS=$(date +%Y%m%d_%H%M%S)
DEVICE="s931u"
EXTRACT_DIR="$PROJ/docs/BLE-Sniffing/extracted_${TS}_${DEVICE}"
HCILOG="$EXTRACT_DIR/FS/data/log/bt/btsnoop_hci.log"
REPORTS_LOG="$PROJ/docs/BLE-Sniffing/reports/btsnoop_${TS}_${DEVICE}.log"

mkdir -p "$PROJ/docs/BLE-Sniffing/reports"
cp "$HCILOG" "$REPORTS_LOG"

echo "✅ HCI log ready for analysis: $REPORTS_LOG"
```

---

## File Organization (After Pull)

```
docs/BLE-Sniffing/
├── bugreport_20251229_185038.zip           # Raw bugreport (gitignored)
├── extracted_20251229_185038_s931u/        # Extracted bugreport folder (gitignored)
│   ├── FS/data/log/bt/btsnoop_hci.log     # ← THE HCI LOG
│   └── [other bugreport files...]
├── reports/
│   ├── btsnoop_20251229_185038_s931u.log  # Copy for analysis
│   ├── testo_pressure_data.csv             # Parsed readings
│   └── [other analysis files...]
└── [other sniff data...]
```

---

## Export HCI Log to CSV (Optional, For Wireshark)

```bash
PROJ="/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/TekNeck-HVAC_TekMate/hvac_support_app"
TS=$(date +%Y%m%d_%H%M%S)

# Install tshark first (if needed)
# brew install wireshark

HCILOG="$PROJ/docs/BLE-Sniffing/reports/btsnoop_${TS}_s931u.log"
CSV_OUT="$PROJ/docs/BLE-Sniffing/reports/hci_packets_${TS}_s931u.csv"

tshark -r "$HCILOG" -T fields \
  -E header=y -E separator=, \
  -e frame.time \
  -e bluetooth.hci_command_opcode \
  -e bluetooth.hci_event_code \
  -e bluetooth.src \
  -e bluetooth.dst \
  -e bluetooth.uuid \
  -e bluetooth.data \
  > "$CSV_OUT"

echo "✅ CSV exported: $CSV_OUT"
```

---

## Troubleshooting

### ❌ "No such file" When Pulling
**Problem:** Bugreport command fails  
**Solution:**  
1. Verify device is connected: `adb devices`  
2. Try again (may be a temporary connection issue)
3. Check USB connection (try different cable/port)

### ❌ HCI Log Not in Extracted Folder
**Problem:** Bugreport extracted but no `btsnoop_hci.log` found  
**Solution:**  
1. Verify HCI snoop logging is enabled: `adb shell getprop persist.bluetooth.hcidump`  
2. If disabled (returns 0), re-enable in Developer Options
3. Reproduce BLE session again and pull new bugreport

### ❌ Extracted Folder is Very Large (>500MB)
**Problem:** Bugreport contains too much data  
**Solution:** This is normal. Bugreports include full system logs and memory dumps.
- Keep in `docs/BLE-Sniffing/` (already gitignored)
- Only copy the HCI log to `reports/` for analysis

---

## Working Example (Dec 29, 2025 Session)

```bash
PROJ="/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/TekNeck-HVAC_TekMate/hvac_support_app"

# Pull with timestamp
TS=$(date +%Y%m%d_%H%M%S)
adb bugreport "$PROJ/docs/BLE-Sniffing/bugreport_${TS}.zip"

# Extract
unzip -q "$PROJ/docs/BLE-Sniffing/bugreport_${TS}.zip" \
  -d "$PROJ/docs/BLE-Sniffing/extracted_${TS}_s931u"

# Verify HCI log (should show file size in KB/MB)
ls -lh "$PROJ/docs/BLE-Sniffing/extracted_${TS}_s931u/FS/data/log/bt/btsnoop_hci.log"

# Result from actual session:
# -rw-r--r--  1 joeykeilbarth  staff  1.2M Dec 29 19:06 btsnoop_hci.log  ✅
```

---

## Related Files

- [README.md](README.md) - Overview of BLE sniffing system
- [parse_btsnoop.py](parse_btsnoop.py) - Python script to analyze HCI logs
- [analyze_testo_log.py](analyze_testo_log.py) - Extract Testo pressure readings
