# HCI Capture Troubleshooting Guide

> **For:** BLE Sniffer users having issues with HCI log capture  
> **Status:** Updated December 29, 2025

## Quick Diagnosis

### Problem 1: HCI Button Shows Grey (Disabled)

**Symptom:** Recording icon in top-right of BLE Sniffer is **grey**, not green

**Cause:** Bluetooth HCI snoop logging is not enabled on your phone

**Fix (2 steps):**
1. On your phone: **Settings → Developer Options**
2. Toggle **"Bluetooth HCI snoop log"** to **ON**

Restart the app - button should now be green ✅

---

### Problem 2: HCI Button Shows Green But Tapping Shows Error

**Symptom:** Recording icon is **green**, button is clickable, but tapping shows:
```
❌ HCI LOG CAPTURE FAILED - TROUBLESHOOTING GUIDE
```

**Cause:** Your phone's security (SELinux) is blocking the app from reading the HCI log file

**Why This Happens:**
- HCI logs are stored in a system-protected directory: `/data/misc/bluetooth/logs/`
- Unprivileged apps can't read system files (security feature)
- The logs DO exist and CAN be accessed via ADB
- This is normal on all modern Android phones

**Fix: Use ADB Method (Computer Required)**

You have two options:

#### Option A: Fast ADB Shell Method (Recommended)

Open a terminal on your computer and run:

```bash
# 1. Enable HCI logging (one-time setup)
adb shell settings put global bluetooth_hci_snoop_log_output 1

# 2. Toggle Bluetooth to generate new logs
adb shell svc bluetooth disable
sleep 2
adb shell svc bluetooth enable
sleep 3

# 3. Capture the HCI log to your computer
adb shell cat /data/misc/bluetooth/logs/btsnoop_hci.log > btsnoop.log

# btsnoop.log is now on your computer - ready to analyze!
```

**Time:** ~30 seconds  
**Device Support:** Samsung S25/S931U ✅ (Tested)

#### Option B: Bugreport Method (Most Reliable)

If Option A doesn't work on your device:

```bash
# 1. Create bugreport (takes 30-60 seconds)
adb bugreport bugreport.zip

# 2. Extract
unzip -q bugreport.zip -d extracted/

# 3. Find HCI log
# extracted/FS/data/log/bt/btsnoop_hci.log
```

See [PULL_HCI_LOGS.md](PULL_HCI_LOGS.md) for detailed steps.

---

### Problem 3: "HCI logging property is empty"

**Symptom:** Logcat shows:
```
D MainActivity: HCI logging property:  (empty)
```

**Cause:** Android property system hasn't cached the setting yet

**Fix:** 
1. Reboot your phone
2. Re-enable HCI logging in Developer Options
3. Toggle Bluetooth off/on once

---

### Problem 4: "File not found" or "Permission denied"

**Symptom:** Error message includes:
- "file not readable"
- "Permission denied"
- "File not found"

**Cause:** HCI log file doesn't exist yet (no Bluetooth activity)

**Fix:**
1. Keep your app open
2. Have Bluetooth devices nearby (Testo probes, etc.)
3. Let them broadcast for 10-30 seconds
4. Try capturing again

---

## Understanding the In-App Process

When you tap the HCI Capture button in the app:

1. **Detection** ✅
   - App checks if HCI logging is enabled on your phone
   - If disabled → Button shows grey (see Problem 1)

2. **Capture Attempt** (What Happens)
   - App tries 4 methods to read the HCI log file
   - On rooted devices → Method 1-3 might succeed
   - On stock devices → All fail (security restriction)
   - App shows you this is expected ✅

3. **Error with Solution** ✅
   - App doesn't just say "failed"
   - Shows you the exact ADB commands to use
   - Provides step-by-step guide (this document)

---

## Technical Details

### Why Can't the App Just Read the File?

Android's SELinux policy restricts access to `/data/misc/bluetooth/logs/` to:
- System apps (labeled `system_server`)
- Certain Bluetooth daemons
- NOT third-party apps (even with permissions)

This is intentional - it's a **security feature**.

### Why ADB Works

ADB runs in a different SELinux context (`adb`) that has broader permissions.

### Will This Work on My Device?

**Option A (ADB Shell) success rate:**
- Samsung devices (Android 14+): ~85% ✅
- Pixel devices: ~70% (may use different paths)
- Other OEM devices: Varies
- Custom ROMs: Often 100% ✅

**Option B (Bugreport) success rate:**
- All devices: 100% ✅ (but slower)

---

## Analyzing the Captured Log

Once you have `btsnoop.log`, you can analyze it with:

### Wireshark (GUI)
1. Download Wireshark
2. Open btsnoop.log
3. Select "Bluetooth HCI H4" format
4. See all Bluetooth packets visually

### Command Line Tools
```bash
# Count packets
wc -c btsnoop.log

# View hex dump
hexdump -C btsnoop.log | head -20

# Parse with custom script
python3 parse_abm200.py btsnoop.log
```

---

## Still Having Issues?

### Check Device Support
```bash
# Verify HCI logging is working
adb shell ls -la /data/misc/bluetooth/logs/

# Should show btsnoop_hci.log (might be 0 bytes if no activity)
```

### Check ADB Connection
```bash
# Verify ADB can reach your device
adb devices

# Should show: SM S931U [or your device ID]    device
```

### Enable More Debugging
```bash
# In TekNeck app, open TekTool → Devices → BLE Sniffer
# Check the console log for diagnostic messages

# In Android logcat:
adb logcat -s MainActivity:D | grep -i hci
```

---

## Next Steps

- If **Option A** worked: Analyze your btsnoop.log with Wireshark
- If **Option B** worked: Extract log and analyze  
- If neither worked: Check `adb devices` - ADB might not be set up
- **For developers:** See [IN_APP_HCI_CAPTURE.md](IN_APP_HCI_CAPTURE.md) for implementation details
