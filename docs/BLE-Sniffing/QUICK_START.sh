#!/bin/bash
# Quick reference for BLE log extraction
# Configured for: Samsung S931U (RFCY518ZA0Y) • Android 16 (API 36)

# ============================================================================
# SETUP (one-time)
# ============================================================================

# Install Wireshark (for tshark CSV export)
brew install wireshark

# Enable HCI logging on Samsung S931U:
# Settings → About phone → Build number (tap 7x to unlock Developer Options)
# Developer Options → Bluetooth HCI snoop log (toggle ON)
# Reproduction: Connect device, measure with Testo/Fieldpiece/ABM-200
# Log location: /sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log

# ============================================================================
# PULL HCI LOG (Samsung S931U)
# ============================================================================

cd hvac_support_app
./scripts/pull_ble_logs.sh s931u

# Device tag: s931u (Samsung S931U)
# Result: docs/BLE-Sniffing/phone-data/btsnoop_hci_2025-12-23_s931u.log

# ============================================================================
# PULL + EXPORT TO CSV (Samsung S931U)
# ============================================================================

./scripts/pull_ble_logs.sh s931u --csv

# Result: 
#   docs/BLE-Sniffing/phone-data/btsnoop_hci_2025-12-23_s931u.log
#   docs/BLE-Sniffing/reports/hci_packets_2025-12-23_s931u.csv

# ============================================================================
# PULL + FULL BUGREPORT (if HCI log not available)
# ============================================================================

./scripts/pull_ble_logs.sh s931u --full

# Result:
#   docs/BLE-Sniffing/phone-data/btsnoop_hci_2025-12-23_s931u.log
#   docs/BLE-Sniffing/phone-data/bugreport_2025-12-23_s931u.zip
#   docs/BLE-Sniffing/extracted_2025-12-23_HH-MM-SS_s931u/

# ============================================================================
# EXPORT TESTO/FIELDPIECE DATA
# ============================================================================

# From Testo app:
#   1. Select measurement session
#   2. Export → Share → Save to Files
#   3. Copy to: docs/BLE-Sniffing/reports/
#   Example: 2025-12-23-testo_2-temp_1-Pressure.tjf

# From Fieldpiece app:
#   1. Select measurement session
#   2. Export → CSV
#   3. Copy to: docs/BLE-Sniffing/reports/
#   Example: 22122975_BG_1.csv

# ============================================================================
# FOLDER ORGANIZATION
# ============================================================================

# After running script + exporting app data:
ls docs/BLE-Sniffing/phone-data/         # Raw HCI logs (s931u_*.log)
ls docs/BLE-Sniffing/reports/            # CSV, .tjf, .csv exports
ls docs/BLE-Sniffing/extracted_*/        # Unzipped bugreports (if --full)

# ============================================================================
# ANALYZE CSV IN SPREADSHEET
# ============================================================================

# Open in Numbers/Excel:
open docs/BLE-Sniffing/reports/hci_packets_2025-12-23_s931u.csv

# Key columns to examine:
# - frame.time: When packets were sent
# - bluetooth.src/dst: Device addresses
# - bluetooth.uuid: Service UUIDs
# - bluetooth.manufacturer_data: Fieldpiece (0x5046), Testo, ABM-200, etc.

# ============================================================================
# SYNC TO FIREBASE (OPTIONAL)
# ============================================================================

# Document the capture in docs/BLE-Sniffing/reports/README.txt:
cat > docs/BLE-Sniffing/reports/2025-12-23_s931u_summary.txt << 'EOF'
## Capture: BLE Device Testing on Samsung S931U
- Date: 2025-12-23
- Device: Samsung SM S931U (RFCY518ZA0Y) • Android 16 (API 36)
- Session: HH:MM - HH:MM AM/PM (duration)
- Devices tested: Testo T115i, Fieldpiece, ABM-200, Wey-Tek Scale
- Issues: [List any connection problems, timeouts, etc.]
- Notes: [Testing location, environmental factors, etc.]

Files:
- HCI log: btsnoop_hci_2025-12-23_s931u.log
- CSV: hci_packets_2025-12-23_s931u.csv
- Testo export: 2025-12-23-testo_*.tjf
- Fieldpiece export: *_BG_*.csv
EOF

# Then manually upload summary metadata to Firestore:
# Collection: ble_sniff_logs
# Document: {timestamp, device_type, protocol_findings, s931u_notes}

# ============================================================================
# TROUBLESHOOTING (Samsung S931U specific)
# ============================================================================

# Device not showing up in adb:
adb devices  # Check RFCY518ZA0Y status
# If not listed:
# 1. Reconnect USB cable
# 2. Settings → Developer Options → USB Debugging (toggle OFF then ON)
# 3. Authorize computer when prompted on device

# HCI log not found:
# 1. Settings → About phone → Build number (tap 7x)
# 2. Developer Options → Bluetooth HCI snoop log (ON)
# 3. Reproduce BLE session (connect device, take measurements)
# 4. Try --full option to get full bugreport

# tshark not found:
brew install wireshark  # Install Wireshark (includes tshark)

# CSV export failed:
# - HCI log may be corrupted or empty
# - Try pulling fresh log after reproducing session
# - Check file size: ls -lh docs/BLE-Sniffing/phone-data/*s931u*
# - Verify HCI logging is enabled and device was actively measuring

# ============================================================================
# DEVICE INFO (Samsung S931U)
# ============================================================================

# Model: SM-S931U (Galaxy S25 Ultra)
# Serial: RFCY518ZA0Y
# OS: Android 16 (API 36)
# HCI Log Path: /sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log

adb shell getprop ro.build.version.release  # Check Android version
adb shell getprop ro.product.model          # Check model
adb shell getprop ro.serialno               # Check serial number

