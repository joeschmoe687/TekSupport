# HCI In-App Capture - Implementation Complete

> **Status:** ✅ **READY FOR TESTING**  
> **Date:** December 30, 2024  
> **Next Action:** Test on Samsung S931U with Testo probes

---

## 🎯 What Was Built

Complete **in-app HCI log capture** system that allows admins to:
1. Capture system-level Bluetooth HCI logs directly from the app (no computer needed)
2. Preview captured devices and packet data
3. Manually upload to Firebase for protocol analysis

**No more computer required!** Field techs can capture HCI logs on-site.

---

## 📂 Files Created/Modified

### New Files
1. **`lib/tools/services/hci_log_capture_service.dart`** (350 lines)
   - Flutter service to capture and parse HCI logs
   - Binary btsnoop parser (handles 24-byte packet records)
   - Firebase upload functionality
   - Device filtering (Testo, Fieldpiece, Wey-Tek, ABM)

2. **`docs/BLE-Sniffing/IN_APP_HCI_CAPTURE.md`**
   - Complete implementation guide
   - Architecture diagrams
   - Usage instructions

3. **`docs/BLE-Sniffing/TESTING_CHECKLIST.md`**
   - Comprehensive testing procedures (9 test cases)
   - Expected results for each test
   - Debugging commands
   - Sign-off template

### Modified Files
1. **`android/app/src/main/kotlin/com/tekneckjoe/tektool/MainActivity.kt`**
   - Added `HCI_CHANNEL` constant: `com.tekneckjoe.tektool/hci_capture`
   - Added MethodChannel handler in `configureFlutterEngine()`
   - Implemented 3 platform methods:
     - `isHciLoggingEnabled()` - Check system property
     - `captureHciLog()` - Copy log from system to app storage
     - Background thread execution to prevent UI blocking

2. **`lib/tools/screens/ble_sniffer_settings_screen.dart`**
   - Added HCI Capture section at top of settings
   - Status indicator (Enabled/Disabled badge)
   - "Capture HCI Log" button with loading state
   - Device preview with scrollable list (shows up to 5 devices)
   - "Upload to Firebase" button
   - Warning message when HCI disabled

---

## ✅ Compilation Status

```bash
flutter analyze lib/tools/screens/ble_sniffer_settings_screen.dart \
                lib/tools/services/hci_log_capture_service.dart

Result: 0 errors, 24 info warnings (deprecations, style suggestions)
```

**Status:** ✅ **Compiles successfully**

Warnings are non-critical:
- `withOpacity` deprecations (Flutter framework change)
- `print` statements (already wrapped in try/catch, safe for debug)
- Style preferences (`const` suggestions)

---

## 🔧 How It Works

### Architecture
```
┌─────────────────┐
│  Settings UI    │
│  (Flutter)      │
└────────┬────────┘
         │
         │ MethodChannel: com.tekneckjoe.tektool/hci_capture
         │
┌────────▼────────┐
│ MainActivity    │
│ (Kotlin)        │
│ - Check HCI     │
│ - Copy log      │
└────────┬────────┘
         │
         │ File I/O
         │
┌────────▼────────────────────────┐
│ Android System                  │
│ /data/misc/bluetooth/logs/      │
│   btsnoop_hci.log               │
└─────────────────────────────────┘
         │
         │ Copy to app storage
         │
┌────────▼────────────────────────┐
│ App Storage                     │
│ /data/user/0/com.tekneckjoe.    │
│   tektool/files/hci_logs/       │
│   btsnoop_TIMESTAMP.log         │
└────────┬────────────────────────┘
         │
         │ Parse (Flutter)
         │
┌────────▼────────┐
│ HciLogData      │
│ - Devices       │
│ - Packets       │
│ - Metadata      │
└────────┬────────┘
         │
         │ Preview in UI
         │
┌────────▼────────────────────────┐
│ User taps "Upload to Firebase"  │
└────────┬────────────────────────┘
         │
         │ Upload
         │
┌────────▼────────────────────────┐
│ Firebase                        │
│ - Storage: hci_logs/{userId}/   │
│ - Firestore: ble_sniff_logs     │
└─────────────────────────────────┘
```

### Data Flow
1. User taps "Capture HCI Log"
2. Flutter → Kotlin: `captureHciLog()` call
3. Kotlin copies `/data/misc/bluetooth/logs/btsnoop_hci.log` → app storage
4. Kotlin → Flutter: Returns file path
5. Flutter parses btsnoop binary format
6. Flutter extracts HVAC devices (Testo, Fieldpiece, etc.)
7. Flutter displays preview in UI
8. User reviews devices/packets
9. User taps "Upload to Firebase"
10. Flutter uploads to Storage + writes metadata to Firestore
11. Preview clears, ready for next capture

---

## 🧪 Testing Instructions

### Quick Test (5 minutes)
1. Open TekNeck as admin
2. Navigate: `Tools → Devices → 🐛 → BLE Sniffer → Settings`
3. Verify "HCI Log Capture" section shows "Enabled"
4. Tap "Capture HCI Log"
5. Wait for capture (5-15 sec)
6. Verify device preview appears
7. Tap "Upload to Firebase"
8. Verify success message
9. Check [Firebase Console](https://console.firebase.google.com/project/tekneck-support) for uploaded file

### Full Testing
See [TESTING_CHECKLIST.md](./TESTING_CHECKLIST.md) for comprehensive test procedures.

---

## 📋 Prerequisites for Testing

### Device Setup
1. **Enable USB Debugging:**
   - Settings → About Phone → Tap "Build Number" 7 times
   - Settings → Developer Options → USB Debugging → ON

2. **Enable HCI Logging:**
   - Settings → Developer Options → Enable Bluetooth HCI snoop log → **Enabled**
   - Toggle Bluetooth OFF then ON to restart logging

3. **Test Equipment:**
   - Testo T549i (pressure probe, SN:49291139)
   - Testo T115i (temp probe, SN:49498664)
   - Testo Smart app (connect probes to generate BLE traffic)

### Admin User
Must be logged in as user with `role: 'admin'` in Firestore `users/{uid}`.

**Ghost Mode:** Non-admin users will NOT see HCI capture features (completely hidden).

---

## 🔍 Verification Commands

```bash
# Check HCI logging is enabled
adb shell getprop persist.bluetooth.btsnooplogmode
# Expected output: full

# Verify HCI log exists and has data
adb shell ls -lh /data/misc/bluetooth/logs/btsnoop_hci.log
# Expected: File size >100KB if BLE traffic present

# Monitor Flutter logs during testing
adb logcat -s flutter

# Monitor platform channel calls
adb logcat -s MainActivity

# Baseline test (computer method)
adb bugreport bugreport-test.zip
unzip bugreport-test.zip
ls -lh FS/data/misc/bluetooth/logs/btsnoop_hci.log
```

---

## 🚨 Known Limitations

1. **Android Only:** HCI capture only works on Android (iOS does not expose HCI logs)

2. **Root/Developer Mode Required:**
   - HCI snoop logging must be enabled in Developer Options
   - Some devices may require root access to read `/data/misc/bluetooth/logs/`

3. **Measurement Parsing:**
   - Device detection works (names, addresses)
   - Actual measurement values (pressure, temp) need offset refinement
   - Parser extracts raw packets but doesn't decode proprietary protocols yet

4. **File Size:**
   - HCI logs can grow large (1-5MB per minute of active BLE traffic)
   - Upload time depends on internet speed
   - Firebase Storage has 5GB free tier limit

5. **Admin Only:**
   - Only users with `role='admin'` can access HCI capture
   - Non-admins don't see the feature (Ghost Mode)

---

## 🐛 Troubleshooting

### "HCI Status: Disabled"
**Cause:** HCI snoop logging not enabled on device

**Fix:**
1. Go to Developer Options
2. Enable "Bluetooth HCI snoop log"
3. Restart Bluetooth (toggle off/on)
4. Restart TekNeck app

### "Failed to capture HCI log"
**Possible Causes:**
- HCI log file doesn't exist
- Permission denied (device doesn't allow app access)
- File is locked by another process

**Debug:**
```bash
# Check if file exists
adb shell ls -l /data/misc/bluetooth/logs/btsnoop_hci.log

# Try manual pull
adb bugreport bugreport-debug.zip

# Check logcat for errors
adb logcat -s MainActivity -s flutter
```

### "No devices detected"
**Possible Causes:**
- No HVAC devices actively transmitting during capture
- Devices not connected (paired but not streaming)
- Parser not recognizing device names

**Fix:**
1. Ensure Testo probes are connected to Testo Smart app (not just paired)
2. Verify probes are streaming data (readings updating)
3. Try capturing again (BLE is timing-sensitive)

### "Upload failed"
**Possible Causes:**
- No internet connection
- Firebase Auth expired
- Storage rules deny write

**Debug:**
```bash
# Check Firebase connectivity
adb logcat -s FirebaseFirestore -s FirebaseStorage

# Verify auth status in app
# Settings → Profile → Check user is logged in
```

---

## 📝 Next Steps

### Immediate (Before Doc Update)
1. [ ] Test on Samsung S931U with checklist
2. [ ] Verify all 9 test cases pass
3. [ ] Confirm Firebase upload works
4. [ ] Test with multiple devices (>2 probes)
5. [ ] Verify Ghost Mode (non-admin can't see features)

### After Testing Passes
1. [ ] Update `LIVE_TEST_SUMMARY.md` with in-app results
2. [ ] Update `IN_APP_HCI_CAPTURE.md` with verified workflow
3. [ ] Update `START_HERE.md` to recommend in-app method
4. [ ] Update `INDEX.md` with testing results
5. [ ] Mark TODO item as complete

### Future Enhancements
1. [ ] Auto-capture on app open (admin only, background service)
2. [ ] Decode proprietary protocols (Testo, Fieldpiece measurements)
3. [ ] Live streaming mode (continuous capture with preview)
4. [ ] Export parsed data as CSV
5. [ ] Device comparison (diff between captures)

---

## 🎓 What This Enables

### For Field Techs
- **No computer needed** to capture BLE protocol data
- On-site protocol analysis during troubleshooting
- Quick device verification (is probe transmitting?)

### For Development
- **Remote protocol captures** from field techs
- Faster iteration on new device support
- Real-world data collection for parser refinement

### For Protocol Analysis
- **System-level capture** (sees ALL BLE traffic)
- Works with any connected app (Testo, Fieldpiece, etc.)
- Complete packet history for forensics

---

## 📚 Related Documentation

- [TESTING_CHECKLIST.md](./TESTING_CHECKLIST.md) - Testing procedures
- [IN_APP_HCI_CAPTURE.md](./IN_APP_HCI_CAPTURE.md) - Implementation guide
- [START_HERE.md](./START_HERE.md) - Quick start guide
- [INDEX.md](./INDEX.md) - Master documentation index

---

## ✅ Sign-Off

**Implementation Status:** ✅ COMPLETE

**Compilation Status:** ✅ PASS (0 errors, 24 info warnings)

**Testing Status:** ⏳ PENDING (ready for device testing)

**Next Action:** Execute [TESTING_CHECKLIST.md](./TESTING_CHECKLIST.md) on Samsung S931U

---

**Ready to test!** 🚀
