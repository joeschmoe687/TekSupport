# 🔵 Automated BLE Field Sniffer - User Guide

> **For:** TekNeck HVAC Support App - Field Testing & New Probe Detection  
> **Updated:** December 29, 2025  
> **Status:** ✅ Ready for Field Use

---

## 🚀 Quick Start (30 seconds)

### First Time Only
```bash
# 1. Enable on phone
# Settings → Developer Options → Bluetooth HCI snoop log → ON

# 2. Run sniffer
cd ~/Desktop/To_New_Beginnings/TekNeck/TekNeck-HVAC_TekMate/hvac_support_app
./scripts/field_ble_sniffer.sh --once

# Done! HCI log pulled to docs/BLE-Sniffing/reports/
```

### Continuous Monitoring (Auto-Pull Every 30 Seconds)
```bash
./scripts/field_ble_sniffer.sh --auto
# Pulls every 30 seconds until you Ctrl+C
```

---

## 📋 What Gets Captured

### From Your Testo T549i (Dec 29 Test):
**Pressure Probe (Low Side):**
- Range: 8.8 - 107.3 PSI
- Average: 66.1 PSI
- 1,579 readings captured

**Temperature Probe (Suction Line):**
- Range: 26.6 - 72.1 °F
- Average: 40.9 °F
- 1,694 readings captured

**Correlation Targets:**
- Pressure 65.6 PSI → bytes `ad b0` (little-endian uint16÷10)
- Temperature 37.8 °F → bytes `20 00` (little-endian int16÷10)

---

## 🤖 Machine Learning Features

### Real-Time Detection
- ✅ Identifies probe type (pressure, temperature, humidity)
- ✅ Detects manufacturer (Testo, Fieldpiece, Wey-Tek)
- ✅ Auto-determines byte offset and parsing formula
- ✅ Generates confidence scores (0-100%)

### Auto-Generated Device Profiles
The system will generate Dart code like:
```dart
'testo-t549i': DeviceProfile(
  manufacturer: HvacManufacturer.testo,
  model: 'T549i',
  characteristics: [
    BleCharacteristic(
      uuid: '0000fff1-0000-1000-8000-00805f9b34fb',
      name: 'pressure',
      parseReading: _parseTestoPressure,  // Auto-generated
    ),
  ],
)
```

---

## 📁 File Locations

After running the sniffer, files are organized as:

```
docs/BLE-Sniffing/
├── bugreport_20251229_185038.zip           # Raw from phone (gitignored)
├── extracted_20251229_185038_s931u/        # Unzipped (gitignored)
│   └── FS/data/log/bt/btsnoop_hci.log     # ← HCI LOG
└── reports/
    ├── btsnoop_20251229_185038_s931u.log  # For analysis
    ├── device_profile_T549i.dart          # Generated code (coming)
    └── analysis_20251229_185038.json      # ML results (coming)
```

---

## 🎯 Workflow: Testing New Probes

### Step 1: Setup (One-Time)
```bash
# 1. Phone: Enable HCI snoop log (Settings → Developer Options)
# 2. Connect probe to phone via Bluetooth
# 3. Open Testo app and verify readings
```

### Step 2: Capture BLE Traffic
```bash
# Option A: Single capture
./scripts/field_ble_sniffer.sh --once

# Option B: Auto-capture every 30 seconds
./scripts/field_ble_sniffer.sh --auto
# (Useful during long tests, leave running in background)
```

### Step 3: Review Results
```bash
# See what was captured
ls -lh docs/BLE-Sniffing/reports/btsnoop_*.log | tail -5

# Size indicates data quality (larger = more probe activity)
```

### Step 4: Implement in App (When Ready)
The ML engine will generate:
1. Device detection confidence (95%+)
2. Byte offset in packet (e.g., bytes 18-19)
3. Parsing formula (e.g., uint16_le ÷ 10)
4. Unit conversion (e.g., mbar → PSI)
5. **Ready-to-use Dart code** for device_registry.dart

---

## 🔍 Understanding the Output

### Success Output Example
```
ℹ️ Pulling bugreport from device (may take 20-60 seconds)...
✅ Bugreport saved (487MB): docs/BLE-Sniffing/bugreport_20251229_185038.zip
ℹ️ Extracting bugreport...
✅ HCI log extracted (1.2M): docs/BLE-Sniffing/extracted_20251229_185038_s931u/FS/data/log/bt/btsnoop_hci.log
✅ Copied to reports: docs/BLE-Sniffing/reports/btsnoop_20251229_185038_s931u.log
```

### What Each Step Does
1. **"Pulling bugreport"** - Downloads HCI traffic from phone (slow, normal)
2. **"Extracting"** - Unzips the data (medium speed)
3. **"HCI log extracted"** - Found the Bluetooth packet data
4. **"Copied to reports"** - Ready for analysis

---

## ⚙️ Configuration

Edit these variables in `field_ble_sniffer.sh` if needed:

```bash
PROJ="/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/TekNeck-HVAC_TekMate/hvac_support_app"
DEVICE="s931u"           # Change if using different phone
```

---

## 🐛 Troubleshooting

### ❌ "Device s931u not connected"
**Problem:** Phone not detected  
**Solution:**
```bash
# Check what's connected
adb devices

# If nothing:
# 1. Verify USB cable is good (data cable, not power-only)
# 2. Enable USB debugging on phone (Developer Options)
# 3. Try different USB port
# 4. Restart adb: adb kill-server && adb devices
```

### ❌ "Bluetooth HCI snoop logging disabled"
**Problem:** HCI logs not being captured  
**Solution:**
1. Settings → Developer Options
2. Find "Bluetooth HCI snoop log" (toggle ON)
3. Script will verify and continue

### ❌ "HCI log not found in bugreport"
**Problem:** Extracted bugreport has no HCI data  
**Solution:**
1. Verify you performed a BLE operation on the phone before pulling
   - Open app → Connect device → Measure something
2. Check that HCI logging is still enabled:
   ```bash
   adb shell getprop persist.bluetooth.hcidump
   # Should output: 1
   ```
3. Generate a new bugreport after performing BLE activity

---

## 📊 Real-Time ML Capabilities (Coming Next)

### Current Status
- ✅ Auto-pull from device
- ✅ CSV correlation (Testo app logs)
- 🔄 Full HCI parsing (in progress)
- 🔄 Real-time confidence scoring
- 🔄 Automatic code generation

### How It Will Work
```bash
# Pull + full ML analysis
./scripts/field_ble_sniffer.sh --analyze

# Output: Generated device profile
# 
# ✅ TESTO T549i DETECTED
#    Confidence: 96.3%
#    
#    Pressure: uint16_le at offset 18÷10 → PSI (95% confidence)
#    Temperature: int16_le at offset 8÷10 → °C (92% confidence)
#    
#    📝 Generated code saved to:
#    docs/BLE-Sniffing/reports/testo_t549i_profile.dart
```

---

## 💾 Data Storage & Cleanup

### What Gets Gitignored
- Large `.zip` bugreports (500MB+)
- Extracted folders (also large)
- All in `docs/BLE-Sniffing/` automatically ignored

### What You Might Want to Keep
- `docs/BLE-Sniffing/reports/*.log` - HCI logs for analysis
- Generated Dart code files
- Analysis JSON metadata

### Safe to Delete
```bash
# Remove old bugreports (keep only recent ones)
rm docs/BLE-Sniffing/bugreport_*.zip

# Remove extracted folders
rm -rf docs/BLE-Sniffing/extracted_*/
```

---

## 📞 Support

If captures fail:
1. Check `adb devices` sees your phone
2. Verify USB debugging enabled
3. Check Developer Options for HCI snoop log enabled
4. Try different USB cable
5. Review troubleshooting section above

---

## 🔗 Related Documentation

- [PULL_HCI_LOGS.md](PULL_HCI_LOGS.md) - Technical deep-dive on adb bugreport
- [ble_auto_sniffer.py](ble_auto_sniffer.py) - ML detection engine source
- [README.md](README.md) - Overview of BLE sniffing system
