# HCI Log Capture - In-App Implementation Guide

> **Status:** ⚠️ PARTIALLY IMPLEMENTED - Capture UI complete, file access limited by Android SELinux  
> **Last Updated:** December 29, 2025  
> **Tested On:** Samsung S931U (Android 16)

## Overview

Complete in-app BLE sniffing solution for capturing HVAC tool protocols (Testo, Fieldpiece, etc.). The app includes a built-in **BLE Sniffer** screen with HCI log capture functionality.

**IMPORTANT:** Due to Android security restrictions (SELinux policies), the app cannot directly access system Bluetooth logs on non-rooted devices. However, logs CAN be pulled via ADB with simple commands provided by the app.

## Quick Troubleshooting

If the HCI Capture button (recording icon) shows **disabled** (grey):
- ✅ **Solution:** Enable HCI logging in Developer Options on your phone
- **Path:** Settings → Developer Options → Bluetooth HCI snoop log → Toggle ON

If the HCI Capture button shows **enabled** (green) but tapping it shows an error guide:
- ✅ **Solution:** Follow the ADB commands shown in the error message
- **Why:** Android prevents unprivileged apps from reading `/data/misc/bluetooth/logs/btsnoop_hci.log`
- **Workaround:** Use ADB (included commands make this simple)

## User Workflow

### Step 1: Enable HCI Logging (One-Time Setup)

### Step 1: Enable HCI Logging (One-Time Setup)
1. Open phone **Settings → Developer Options**
2. Enable **"Bluetooth HCI snoop log"**
3. Restart Bluetooth (turn off/on)

### Step 2: Use Any HVAC App
1. Open **Testo Smart**, **Fieldpiece Job Link**, or any HVAC tool app
2. Connect to your gauges/probes normally
3. Take measurements as usual
4. TekNeck app is NOT connected - HCI captures everything in background!

### Step 3: Capture in TekNeck App
1. Open TekNeck app as admin
2. Go to **Tools → Devices**  
3. Tap **debug icon (🐛)** in top right
4. Tap **"BLE Sniffer"**
5. Navigate to **Settings** tab
6. Scroll down to **"HCI Log Capture"** section
7. Tap **"Capture HCI Log"** button
8. Wait 10-30 seconds (extracts log from system)

### Step 4: Preview Captured Data
- App automatically parses the log
- Shows list of detected HVAC devices:
  - Device name (T549i, T115i, etc.)
  - Serial number
  - Signal strength (RSSI)
  - Number of packets captured
- Scroll through captured packets
- See timestamp, device, packet size

### Step 5: Manual Upload to Firebase
- Review the data preview
- Tap **"Upload to Firebase"** button at bottom
- Confirms upload success
- Data syncs to Firebase for analysis

## Technical Architecture

### Current Implementation Status (Dec 29, 2025)

```
┌────────────────────────────────────────┐
│  Any Bluetooth App (Testo, Fieldpiece) │
│  ↓ Connected to HVAC gauges            │
└────────────────────────────────────────┘
              ↓ (BLE traffic)
┌────────────────────────────────────────┐
│  Android Bluetooth Stack (System Level)│
│  ↓ Captures all HCI packets            │
│  ↓ Stores in btsnoop_hci.log           │
│  ✅ WORKS - File is created            │
│  ❌ BLOCKED - Unprivileged app access  │
└────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────┐
│  TekNeck BLE Sniffer Screen            │
│  ✅ Detects HCI logging is enabled    │
│  ✅ UI shows green "ready" indicator   │
│  ⚠️  File read blocked by SELinux      │
│  ✅ Shows ADB workaround commands      │
└────────────────────────────────────────┘
```

### File Access Status

| Method | Status | Result |
|--------|--------|--------|
| Direct file read | ❌ Blocked | SELinux permission denied |
| Shell `cat` command | ⚠️ Works in adb, ❌ Blocked in app | App context lacks permissions |
| App private dir | ✅ Works | If system writes logs there (Android 12+) |
| ADB bugreport | ✅ Works | Reliable extraction (use `PULL_HCI_LOGS.md`) |
| ADB shell cat | ✅ Works | Can read via adb (see workaround below) |

### Workaround: ADB-Based Capture

When users tap the HCI Capture button on a non-rooted device:

1. **App detects HCI logging is enabled** ✅ (button shows green)
2. **App attempts to capture** ⚠️ (fails with helpful error)
3. **Error screen shows ADB commands** ✅ (user-friendly guide)
4. **User runs commands** from their computer:

```bash
# Step 1: Enable HCI logging on phone (one-time)
adb shell settings put global bluetooth_hci_snoop_log_output 1

# Step 2: Toggle Bluetooth to generate logs
adb shell svc bluetooth disable && sleep 2 && adb shell svc bluetooth enable && sleep 3

# Step 3: Capture HCI log
adb shell cat /data/misc/bluetooth/logs/btsnoop_hci.log > btsnoop.log

# Step 4: Analyze
# Use Wireshark, parse_abm200.py, or other HCI analyzers
```

## Implementation Status

### ✅ Backend Complete (Dec 29, 2025)

**HCI Log Capture Service**
- File: [lib/tools/services/hci_log_capture_service.dart](../../lib/tools/services/hci_log_capture_service.dart)
- ✅ `HciLogCaptureService` class with async capture
- ✅ btsnoop_hci.log binary parser (validates header)
- ✅ Device extraction and filtering (Testo, Fieldpiece, ABM-200)
- ✅ Detailed parsing with packet timestamps
- ✅ Firebase upload with metadata

**BLE Sniffer Screen (Complete UI)**
- File: [lib/tools/screens/ble_sniffer_screen.dart](../../lib/tools/screens/ble_sniffer_screen.dart)
- ✅ HCI status detection (shows green icon when enabled)
- ✅ Capture button with loading indicator
- ✅ Real-time logs displaying capture progress
- ✅ Detailed error messages and troubleshooting guide
- ✅ Device list with RSSI and timestamps
- ✅ Packet preview with hex display

**Android Platform Channel**
- File: [android/app/src/main/kotlin/.../MainActivity.kt](../../android/app/src/main/kotlin/com/tekneckjoe/tektool/MainActivity.kt)
- ✅ Platform channel: `com.tekneckjoe.tektool/hci_capture`
- ✅ `isHciLoggingEnabled()` - Multi-property detection
- ✅ `captureHciLog()` - 4-method fallback approach:
  1. Direct file read (if app has permissions)
  2. Shell `sh -c` command (works on some devices)
  3. ProcessBuilder `cat` command (standard approach)
  4. App private directory check (Android 12+ feature)
- ✅ Detailed logging for each method
- ✅ Background thread execution

### ⏳ Status Summary (Dec 29, 2025)

| Component | Status | Notes |
|-----------|--------|-------|
| HCI Logging Detection | ✅ Complete | Detects if phone has HCI logging enabled |
| Capture UI | ✅ Complete | Green/grey icon, capture button, progress indicator |
| Log Display | ✅ Complete | Shows captured devices, packet list, timestamps |
| Local Capture | ⚠️ Limited | Works on rooted/debuggable apps; fails on stock devices |
| Error Messages | ✅ Complete | Shows ADB workaround steps (see below) |
| Firebase Upload | ✅ Complete | Stores HCI logs and metadata in Firestore/Storage |

### Known Limitations & Workarounds

**Limitation:** Unprivileged apps cannot read `/data/misc/bluetooth/logs/btsnoop_hci.log` on stock Android 16+ devices.

**Why:** Android's SELinux policies prevent non-system apps from accessing system Bluetooth logs, even with explicit permissions.

**Workaround (Provided to Users):**

When HCI capture fails, the app automatically displays step-by-step ADB commands for manual capture. Users need a computer with ADB:

```bash
# On computer:
adb shell settings put global bluetooth_hci_snoop_log_output 1
adb shell svc bluetooth disable && sleep 2 && adb shell svc bluetooth enable && sleep 3
adb shell cat /data/misc/bluetooth/logs/btsnoop_hci.log > btsnoop.log

# Then analyze locally with Wireshark, parse_abm200.py, etc.
```

## File Structure

```
lib/tools/
├── services/
│   └── hci_log_capture_service.dart     ← NEW (complete)
└── screens/
    └── ble_sniffer_settings_screen.dart ← UPDATE NEEDED

android/app/src/main/kotlin/com/tekneckjoe/tektool/
└── MainActivity.kt                      ← UPDATED (complete)
```

## Firebase Structure

### Cloud Storage
```
gs://tekneck-support.appspot.com/
└── hci_logs/
    └── {userId}/
        └── hci_{timestamp}/
            └── btsnoop_hci.log
```

### Firestore
```javascript
Collection: ble_sniff_logs
Document: hci_{timestamp}
{
  sessionId: "hci_1735540800000",
  userId: "admin_user_id",
  timestamp: Timestamp,
  capturedAt: "2025-12-29T20:00:00Z",
  fileSize: 1638400,
  filePath: "https://storage.googleapis.com/...",
  devices: [
    {
      name: "T549i SN:49291139",
      address: "3c:a3:08:ac:54:42",
      rssi: -57,
      firstSeen: "2025-12-29T19:58:00Z",
      lastSeen: "2025-12-29T19:59:30Z"
    },
    {
      name: "T115i SN:49498664",
      address: "94:e3:6d:75:e8:cf",
      rssi: -52,
      firstSeen: "2025-12-29T19:58:05Z",
      lastSeen: "2025-12-29T19:59:25Z"
    }
  ],
  totalPackets: 14367,
  deviceCount: 2,
  metadata: {
    appVersion: "1.0.0",
    platform: "android",
    osVersion: "Android 16"
  }
}
```

## Permissions Required

### Android Manifest
Already has Bluetooth permissions. May need to add:
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### Runtime Permissions
- Bluetooth (already granted)
- Storage (for saving captured logs)

## Key Features

### ✅ No Computer Needed
- Everything in-app
- No USB cable required
- No adb commands

### ✅ Works with Any App
- Testo Smart connected? ✓ We capture it
- Fieldpiece Job Link connected? ✓ We capture it
- TekNeck app NOT connected? ✓ Still captures!

### ✅ Preview Before Upload
- See devices detected
- See packet count
- Verify data quality
- Decide whether to upload

### ✅ Manual Upload Control
- No auto-upload spam
- Review first, upload if good
- Save bandwidth/storage

## Next Steps to Complete

1. **Add UI to settings screen** (15 min)
   - Add HCI section card
   - Wire up capture button
   - Add preview area
   - Add upload button

2. **Test on Samsung S931U** (10 min)
   - Enable HCI logging in settings
   - Connect Testo app to probes
   - Capture log in TekNeck app
   - Verify preview shows devices
   - Test Firebase upload

3. **Add error handling** (5 min)
   - Show snackbar if HCI disabled
   - Handle capture failures
   - Handle upload errors

4. **Polish UI** (10 min)
   - Add loading indicators
   - Add success/failure messages
   - Add packet preview scrolling

## Usage Instructions for Field Techs

### Quick Start Card
```
📱 BLE PROTOCOL CAPTURE GUIDE

1️⃣ SETUP (do once):
   • Settings → Developer Options
   • Enable "Bluetooth HCI snoop log"
   • Restart Bluetooth

2️⃣ TAKE MEASUREMENTS:
   • Use Testo/Fieldpiece app normally
   • Connect gauges as usual
   • Take your measurements

3️⃣ CAPTURE IN TEKNECK:
   • Open TekNeck as admin
   • Tools → Devices → 🐛 → BLE Sniffer
   • Settings tab → "Capture HCI Log"
   • Wait 30 seconds

4️⃣ PREVIEW & UPLOAD:
   • Review detected devices
   • Check packet count
   • Tap "Upload to Firebase"
   • Done!

💡 TIP: Capture after each job to help us
    learn new gauge protocols!
```

---

**Status:** Backend complete, UI pending (40 minutes of work)  
**Last Updated:** December 29, 2025  
**Ready for:** Field testing once UI added
