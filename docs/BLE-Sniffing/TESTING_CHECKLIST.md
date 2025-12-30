# HCI In-App Capture - Testing Checklist

> **Device:** Samsung SM-S931U (Android 16)  
> **Test Date:** _To be filled_  
> **Tester:** _To be filled_

## 🎯 Test Objective

Verify that the in-app HCI capture functionality works correctly:
1. Capture HCI logs from Android system
2. Parse btsnoop_hci.log binary format
3. Display device preview in UI
4. Upload to Firebase Storage + Firestore

---

## 📋 Prerequisites

### 1. Device Setup
- [ ] USB debugging enabled in Developer Options
- [ ] HCI snoop logging enabled: `Settings → Developer Options → Enable Bluetooth HCI snoop log → Enabled`
- [ ] Restart Bluetooth after enabling HCI logging (toggle off/on)
- [ ] Samsung S931U connected via USB (for adb verification if needed)

### 2. Test Equipment
- [ ] Testo T549i pressure probe (SN:49291139) - fully charged
- [ ] Testo T115i temp probe (SN:49498664) - fully charged
- [ ] Testo Smart app installed on separate device OR using Samsung Multi User
- [ ] Probes paired and connected to Testo Smart app

### 3. App Setup
- [ ] TekNeck app installed (latest build)
- [ ] Logged in as **admin user** (role='admin' in Firestore)
- [ ] Firebase connection active
- [ ] Internet connection stable

### 4. Baseline Check (Computer-Based Method)
Before testing in-app, verify HCI logging is working via computer:

```bash
# Pull bugreport and check for HCI log
adb bugreport bugreport-baseline.zip
unzip bugreport-baseline.zip
ls -lh FS/data/misc/bluetooth/logs/btsnoop_hci.log

# Expected: File exists, >1MB size
```

If baseline fails, HCI logging is not working on device → troubleshoot before app testing.

---

## 🧪 Test Procedures

### Test 1: HCI Status Check

**Steps:**
1. Open TekNeck app
2. Navigate: `Tools → Devices → 🐛 → BLE Sniffer → Settings`
3. Observe HCI Log Capture section at top

**Expected Result:**
- [ ] Section displays "HCI Log Capture" with bluetooth icon
- [ ] Status badge shows "Enabled" (green)
- [ ] "Capture HCI Log" button is enabled (not greyed out)

**If "Disabled" shown:**
- Check Developer Options → HCI snoop logging is ON
- Restart Bluetooth
- Close/reopen app

---

### Test 2: Capture Without Devices

**Objective:** Test capture works even without HVAC devices present

**Steps:**
1. Turn OFF both Testo probes (or disconnect from Testo app)
2. In TekNeck → Settings → HCI Capture section
3. Tap "Capture HCI Log" button
4. Wait for capture to complete (5-15 seconds)

**Expected Result:**
- [ ] Button shows "Capturing..." with spinner
- [ ] Snackbar appears: "Captured X devices, Y packets"
- [ ] Device preview section appears (may show 0 devices or only non-HVAC devices)
- [ ] "Upload to Firebase" button becomes active

**If capture fails:**
- Check logcat: `adb logcat -s flutter`
- Verify HCI log exists: `adb shell ls -l /data/misc/bluetooth/logs/btsnoop_hci.log`
- Check MainActivity.kt platform channel is working

---

### Test 3: Capture With Testo Devices Connected

**Objective:** Verify HVAC device detection and parsing

**Steps:**
1. Connect both Testo probes to Testo Smart app on separate device
2. Verify probes are streaming data in Testo app (readings updating)
3. In TekNeck → Settings → HCI Capture section
4. Tap "Capture HCI Log" button
5. Wait for capture to complete

**Expected Result:**
- [ ] Snackbar shows: "Captured 2 devices, XXX packets" (or more if other BLE devices nearby)
- [ ] Device preview shows:
  - **Testo T549i** (or similar) with MAC address
  - **Testo T115i** (or similar) with MAC address
- [ ] Devices listed with:
  - Device name or "Unknown" with address
  - Cyan bullet points
  - No truncation errors
- [ ] Packet count >100 (active streaming generates many packets)

**Verification Details:**
- Scroll through device list
- Check for "Testo" or "T549i/T115i" in names
- MAC addresses should be in format `XX:XX:XX:XX:XX:XX`

**If devices not detected:**
- Check Testo app is actively connected (not just paired)
- Verify probes are transmitting (readings updating in Testo app)
- Check parser logic in `hci_log_capture_service.dart` → `_extractDeviceInfo()`
- Try capturing again (BLE is timing-sensitive)

---

### Test 4: Device Preview UI

**Objective:** Verify UI displays captured data correctly

**Steps:**
1. After successful capture with Testo devices
2. Observe "Captured Data" section

**Expected Result:**
- [ ] Section has cyan border and icon
- [ ] Shows device count: "2 devices detected" (or more)
- [ ] Shows packet count: "XXX packets captured"
- [ ] Shows timestamp in readable format
- [ ] Device list section displays:
  - Up to 5 devices listed individually
  - If >5 devices: "+ N more" message at bottom
- [ ] Each device row has:
  - Cyan bullet point
  - Device name OR address (if name not parsed)
  - No UI overflow or wrapping issues

---

### Test 5: Upload to Firebase

**Objective:** Verify Firebase Storage + Firestore upload works

**Steps:**
1. After successful capture with preview showing
2. Tap "Upload to Firebase" button
3. Wait for upload to complete (10-30 seconds depending on file size)

**Expected Result:**
- [ ] Button shows "Uploading..." with spinner
- [ ] Progress indicator visible
- [ ] Snackbar appears: "HCI log uploaded successfully" (green)
- [ ] Device preview section **disappears** (cleared after upload)
- [ ] "Capture HCI Log" button becomes active again

**Firebase Verification:**
1. Open [Firebase Console](https://console.firebase.google.com/project/tekneck-support)
2. Navigate to **Storage**:
   - [ ] Path exists: `hci_logs/{userId}/{sessionId}/btsnoop_hci.log`
   - [ ] File size >100KB (typical HCI log with activity)
   - [ ] File uploaded in last minute (check timestamp)

3. Navigate to **Firestore → ble_sniff_logs**:
   - [ ] New document with `sessionId` matching Storage path
   - [ ] Document contains:
     ```json
     {
       "sessionId": "hci_1234567890_abc123",
       "userId": "your-admin-uid",
       "timestamp": <Firestore server timestamp>,
       "capturedAt": "2025-01-XX...",
       "fileSize": 1234567,
       "filePath": "https://firebasestorage.googleapis.com/...",
       "devices": [
         {
           "name": "Testo T549i",
           "address": "XX:XX:XX:XX:XX:XX",
           "rssi": -57,
           "firstSeen": "...",
           "lastSeen": "..."
         },
         ...
       ],
       "totalPackets": 1234,
       "deviceCount": 2,
       "metadata": {
         "appVersion": "1.0.0",
         "platform": "android",
         "osVersion": "16"
       }
     }
     ```
   - [ ] Device data matches preview shown in app

**If upload fails:**
- Check internet connection
- Check Firebase Auth (user logged in?)
- Check Firebase Storage rules allow write for authenticated users
- Check logcat for upload errors
- Verify `google-services.json` is current

---

### Test 6: Multiple Captures

**Objective:** Verify can capture multiple times without restart

**Steps:**
1. Complete Test 3 (capture with devices)
2. Upload to Firebase
3. Wait for preview to clear
4. Tap "Capture HCI Log" again
5. Repeat upload

**Expected Result:**
- [ ] Second capture works without errors
- [ ] New preview shows current data
- [ ] Second upload creates NEW document in Firestore (different sessionId)
- [ ] No stale data from first capture shown

---

### Test 7: Error Handling - HCI Disabled

**Objective:** Verify app handles missing HCI logging gracefully

**Steps:**
1. Go to Developer Options on device
2. Disable "Enable Bluetooth HCI snoop log"
3. Restart Bluetooth
4. Open TekNeck → Settings → HCI Capture

**Expected Result:**
- [ ] Status badge shows "Disabled" (red)
- [ ] "Capture HCI Log" button is greyed out (disabled)
- [ ] Warning box displays:
  - Warning icon (yellow)
  - Message: "HCI logging is disabled in Developer Options. Enable it to capture logs."

---

### Test 8: Error Handling - No Permission

**Objective:** Verify app handles permission errors

**Steps:**
1. (This test may require manual adb shell commands to simulate)
2. Attempt capture when `/data/misc/bluetooth/logs/` is not readable

**Expected Result:**
- [ ] Capture fails gracefully
- [ ] Snackbar shows: "Failed to capture HCI log: [error message]"
- [ ] No app crash
- [ ] UI returns to normal state (not stuck in "Capturing...")

---

### Test 9: Ghost Mode Verification (Non-Admin)

**Objective:** Verify non-admin users don't see HCI features

**Steps:**
1. Log out of TekNeck app
2. Log in as **non-admin user** (role != 'admin')
3. Navigate: Tools → Devices → 🐛 → BLE Sniffer → Settings

**Expected Result:**
- [ ] HCI Log Capture section **does NOT appear**
- [ ] Only shows existing settings (auto-upload, upload mode)
- [ ] No errors or references to HCI in UI

**Ghost Mode Confirmed:** ✅ Non-admins are invisible to HCI features

---

## 🔬 Advanced Testing (Optional)

### Performance Test
- [ ] Capture HCI log with 10+ BLE devices nearby (e.g., in office with Bluetooth headphones, watches, etc.)
- [ ] Verify app doesn't freeze during parsing
- [ ] Check file size and upload time for large logs (>5MB)

### Stress Test
- [ ] Capture 5 logs in a row without uploading
- [ ] Upload all 5 sequentially
- [ ] Verify all uploads succeed and Firestore has 5 documents

### Edge Cases
- [ ] Capture with airplane mode ON (after capture, before upload) → Should fail upload gracefully
- [ ] Capture with Firebase Auth logged out → Should show auth error
- [ ] Capture with HCI log file corrupted/empty → Should handle parse error

---

## 📊 Test Results Summary

### Overall Status
- [ ] ✅ All critical tests passed
- [ ] ⚠️ Some tests passed with warnings
- [ ] ❌ Critical failures detected

### Issues Found

| Test | Status | Issue Description | Severity |
|------|--------|-------------------|----------|
| Example | ❌ | Device names not parsing correctly | Medium |
| ... | ... | ... | ... |

### Performance Metrics

| Metric | Value | Expected |
|--------|-------|----------|
| Capture time (2 devices) | ____ sec | <15 sec |
| Parse time (1MB log) | ____ sec | <5 sec |
| Upload time (1MB log) | ____ sec | <30 sec |
| App memory usage | ____ MB | <200 MB |

---

## 🐛 Debugging Commands

If issues occur during testing:

```bash
# Check HCI status
adb shell getprop persist.bluetooth.btsnooplogmode
# Expected: full

# Check HCI log exists and size
adb shell ls -lh /data/misc/bluetooth/logs/btsnoop_hci.log

# Pull HCI log manually for verification
adb shell "su -c 'cat /data/misc/bluetooth/logs/btsnoop_hci.log'" > manual_pull.log

# Monitor Flutter logs
adb logcat -s flutter

# Monitor platform channel calls
adb logcat -s MainActivity

# Check Firebase connectivity
adb logcat -s FirebaseFirestore -s FirebaseStorage
```

---

## ✅ Sign-Off

**Tester Name:** ___________________________

**Test Date:** ___________________________

**Device:** Samsung SM-S931U, Android 16

**Build Version:** ___________________________

**Result:** [ ] Pass  [ ] Pass with warnings  [ ] Fail

**Notes:**
```
(Add any additional observations or issues discovered)
```

---

## 📝 Next Steps After Testing

1. **If all tests pass:**
   - [ ] Update `LIVE_TEST_SUMMARY.md` with in-app test results
   - [ ] Update `IN_APP_HCI_CAPTURE.md` with verified workflow
   - [ ] Update `START_HERE.md` to reference in-app method
   - [ ] Update `INDEX.md` with testing results
   - [ ] Mark TODO item as complete

2. **If issues found:**
   - [ ] Document issues in GitHub Issues
   - [ ] Fix critical bugs
   - [ ] Re-run failed tests
   - [ ] Update testing checklist with lessons learned

3. **Production Readiness:**
   - [ ] Test on multiple Android versions (API 21-34)
   - [ ] Test on different device manufacturers (Samsung, Pixel, etc.)
   - [ ] Performance profiling for large HCI logs
   - [ ] User acceptance testing with field techs
