# 🚀 HCI In-App Capture - Quick Test Guide

> **Time:** ~5 minutes  
> **Device:** Samsung S931U  
> **Required:** Testo probes + Admin login

---

## ✅ Pre-Flight Check

```bash
# 1. Check HCI is enabled
adb shell getprop persist.bluetooth.btsnooplogmode
# ✅ Should show: full

# 2. Verify HCI log exists
adb shell ls -l /data/misc/bluetooth/logs/btsnoop_hci.log
# ✅ Should show: file with size >100KB
```

---

## 📱 Testing Steps

### 1. Enable HCI Logging (One-Time Setup)
Settings → Developer Options → **Enable Bluetooth HCI snoop log** → ON  
Toggle Bluetooth OFF then ON

### 2. Connect Test Equipment
- Power on Testo T549i (pressure) + T115i (temp)
- Open **Testo Smart app** on separate device
- Connect both probes
- Verify readings are updating (streaming active)

### 3. Open TekNeck as Admin
Login with admin user (`role: 'admin'` in Firestore)

### 4. Navigate to HCI Capture
Tools → Devices → 🐛 → BLE Sniffer → **Settings**

### 5. Verify Status
Top section shows:
- **"HCI Log Capture"** heading
- Status badge: **"Enabled"** (green) ← Must be enabled!
- "Capture HCI Log" button (not greyed out)

### 6. Capture Log
Tap **"Capture HCI Log"**  
Wait 5-15 seconds  
Button shows "Capturing..." with spinner

### 7. Verify Preview
Snackbar appears: **"Captured X devices, Y packets"**

Device preview shows:
- **Device count:** 2+ (both Testo probes)
- **Packet count:** >100 (active streaming)
- **Devices listed:** Testo T549i, T115i with addresses
- Timestamp shown

### 8. Upload to Firebase
Tap **"Upload to Firebase"**  
Wait 10-30 seconds  
Snackbar: **"HCI log uploaded successfully"** (green)  
Preview section disappears

### 9. Verify Firebase
Open [Firebase Console](https://console.firebase.google.com/project/tekneck-support)

**Storage:**
- Navigate to `hci_logs/{your-uid}/`
- See new folder with `btsnoop_hci.log`
- File size >100KB

**Firestore:**
- Navigate to `ble_sniff_logs` collection
- See new document with matching sessionId
- Contains device data (names, addresses, rssi)

---

## ✅ Success Criteria

| Check | Status |
|-------|--------|
| HCI status shows "Enabled" | ⬜ |
| Capture completes in <15 sec | ⬜ |
| Preview shows 2+ devices | ⬜ |
| Device names include "Testo" | ⬜ |
| Upload completes in <30 sec | ⬜ |
| File appears in Firebase Storage | ⬜ |
| Document created in Firestore | ⬜ |
| Preview clears after upload | ⬜ |

**All checks pass?** → ✅ **IMPLEMENTATION VERIFIED**

---

## 🐛 Quick Troubleshooting

| Issue | Fix |
|-------|-----|
| Status shows "Disabled" | Enable HCI in Developer Options → Restart Bluetooth |
| No devices detected | Ensure Testo probes are streaming (not just paired) |
| Upload fails | Check internet + Firebase Auth logged in |
| App crashes | Check logcat: `adb logcat -s flutter` |

---

## 📊 Monitor Logs

```bash
# Terminal 1: Flutter logs
adb logcat -s flutter

# Terminal 2: Platform channel
adb logcat -s MainActivity

# Terminal 3: Firebase
adb logcat -s FirebaseFirestore -s FirebaseStorage
```

---

## 🎯 Test Variations

### Quick Variations (2 min each)
1. **No devices:** Capture without probes connected → Should succeed with 0 devices
2. **Multiple captures:** Capture → Upload → Capture again → Upload → Both succeed
3. **Large file:** Connect 5+ BLE devices → Capture → Verify handles large log

### Ghost Mode Test (1 min)
1. Log out
2. Log in as non-admin
3. Go to Settings
4. **HCI section should NOT appear** ✅

---

## 📝 After Testing

### If All Tests Pass ✅
Update docs:
- [ ] `LIVE_TEST_SUMMARY.md`
- [ ] `IN_APP_HCI_CAPTURE.md`
- [ ] `START_HERE.md`
- [ ] Mark TODO complete

### If Issues Found ⚠️
Document:
- What failed?
- Error messages?
- Logcat output?
- Screenshots?

---

## 🔗 Full Documentation

- **Complete Testing:** [TESTING_CHECKLIST.md](./TESTING_CHECKLIST.md)
- **Implementation:** [IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md)
- **Architecture:** [IN_APP_HCI_CAPTURE.md](./IN_APP_HCI_CAPTURE.md)

---

**Ready? Let's test!** 🚀

Current time: ___________  
Tester: ___________
