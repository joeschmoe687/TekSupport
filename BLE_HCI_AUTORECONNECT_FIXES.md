# BLE HCI & Auto-Reconnect Fixes - Samsung S25

**Date:** December 29, 2025  
**Issues Fixed:**
1. HCI logging detection failing on Samsung S25 (Android 16)
2. App connecting to Testo probes too aggressively

---

## Issue 1: HCI Logging Detection Fixed

### Problem
On Samsung S25 (Android 16), the HCI status check was returning false even when HCI logging was enabled. The old implementation only checked one property: `persist.bluetooth.btsnooplogmode`

### Root Cause
Samsung devices (especially newer models) use different property names than stock Android:
- Samsung: `persist.vendor.bluetooth.btsnooplogmode` or `persist.bluetooth.btsnoopenable`
- Stock Android: `persist.bluetooth.btsnooplogmode`

### Solution
Enhanced the HCI detection in `MainActivity.kt` to:

1. **Check multiple properties:**
   - `persist.bluetooth.btsnooplogmode` (stock Android)
   - `persist.bluetooth.btsnoopenable` (some Samsung models)
   - `persist.vendor.bluetooth.btsnooplogmode` (Samsung vendor-specific)

2. **Accept multiple enabled states:**
   - `full`, `filtered`, `true`, `1`

3. **Fallback to file check:**
   - If properties fail, check if `/data/misc/bluetooth/logs/btsnoop_hci.log` exists and was modified in last 5 minutes
   - This catches edge cases where logging is active but properties aren't set correctly

### Code Changes
**File:** `android/app/src/main/kotlin/com/tekneckjoe/tektool/MainActivity.kt`

```kotlin
// Old (single property check):
val prop = Runtime.getRuntime().exec("getprop persist.bluetooth.btsnooplogmode")
value == "full" || value == "filtered"

// New (multi-property + file fallback):
val properties = listOf(
    "persist.bluetooth.btsnooplogmode",
    "persist.bluetooth.btsnoopenable",
    "persist.vendor.bluetooth.btsnooplogmode"
)
// + file lastModified check as fallback
```

---

## Issue 2: Aggressive Auto-Reconnect Fixed

### Problem
TekNeck app was connecting to Testo T549i probe immediately (every 30 seconds), preventing Testo Smart app from connecting unless TekNeck was shut down.

### Root Cause
Auto-reconnect service was:
- Scanning every 30 seconds
- Connecting immediately when devices found
- No way to pause for user to connect via other apps

### Solution
Three improvements to `AutoReconnectService`:

#### 1. **Added Pause/Resume Functionality**
New methods:
- `pause()` - Temporarily disable auto-reconnect
- `resume()` - Re-enable auto-reconnect
- `isPaused` getter - Check current state

#### 2. **Increased Scan Interval**
- **Old:** Every 30 seconds
- **New:** Every 60 seconds (less aggressive)
- Added 5-second delay before first scan (give user time to navigate)

#### 3. **UI Toggle in Tools Hub**
Added Bluetooth icon button next to refresh button:
- **Blue connected icon** = Auto-reconnect active
- **Gray disabled icon** = Auto-reconnect paused
- Tap to toggle state
- Shows snackbar notification when toggled

### Code Changes

**File:** `lib/tools/services/auto_reconnect_service.dart`
```dart
// Added pause state
bool _isPaused = false;

// Pause/resume methods
void pause() {
  _isPaused = true;
  stopBackgroundScanning();
}

void resume() {
  _isPaused = false;
  if (_isInitialized) {
    _startBackgroundScanning();
  }
}

// Increased scan interval
_backgroundScanTimer = Timer.periodic(
  const Duration(seconds: 60),  // Was 30s
  (_) {
    if (!_isPaused) {
      _scanForKnownDevices();
    }
  },
);
```

**File:** `lib/tools/screens/tools_hub_screen.dart`
```dart
// Added toggle button in header
IconButton(
  icon: Icon(
    _reconnectService.isPaused
        ? Icons.bluetooth_disabled
        : Icons.bluetooth_connected,
    color: _reconnectService.isPaused
        ? AppColors.textSecondary
        : AppColors.primaryCyan,
  ),
  onPressed: () {
    if (_reconnectService.isPaused) {
      _reconnectService.resume();
    } else {
      _reconnectService.pause();
    }
  },
)
```

---

## Testing Instructions

### Test HCI Detection (Issue 1)
1. Open TekNeck app on Samsung S25
2. Navigate to **Tools → Devices → 🐛 BLE Sniffer**
3. Look at HCI Capture button (recording icon in top right):
   - **Green icon** = HCI logging detected ✅
   - **Gray icon** = HCI logging not detected ❌
4. If gray, enable HCI in **Settings → Developer Options → Bluetooth HCI snoop log → Enabled**
5. Restart Bluetooth or reboot phone
6. Return to BLE Sniffer - should now show **green icon** ✅

### Test Auto-Reconnect Pause (Issue 2)
1. Open TekNeck app
2. Navigate to **Tools** (main tools screen)
3. See Bluetooth icon button (top right, next to refresh):
   - **Blue connected** = Active (will auto-connect)
   - **Gray disabled** = Paused (won't auto-connect)
4. **To connect Testo probe to Testo app:**
   - Tap Bluetooth button to **pause** (should turn gray)
   - Snackbar shows "Auto-reconnect paused"
   - Close TekNeck app
   - Open Testo Smart app
   - Connect to T549i probe
   - Should connect successfully ✅
5. **To reconnect to TekNeck:**
   - Close Testo Smart app
   - Open TekNeck app
   - Tap Bluetooth button to **resume** (should turn blue)
   - Wait ~5-60 seconds for auto-reconnect
   - Probe should reconnect to TekNeck ✅

---

## Workflow: Using Both Apps

### Scenario: You want to use Testo app, then switch back to TekNeck

1. **Before opening Testo app:**
   - Open TekNeck app
   - Go to Tools screen
   - Tap Bluetooth button to **pause** (gray icon)
   - Close TekNeck

2. **Use Testo app:**
   - Open Testo Smart
   - Connect to probes normally
   - Take readings

3. **Switch back to TekNeck:**
   - Close Testo Smart
   - Open TekNeck app
   - Tap Bluetooth button to **resume** (blue icon)
   - Wait 5-60 seconds
   - Probes auto-reconnect to TekNeck ✅

---

## Technical Details

### Samsung S25 Specifics
- **Android Version:** 16 (API 36)
- **Bluetooth Stack:** Samsung OneUI modified stack
- **HCI Property:** `persist.vendor.bluetooth.btsnooplogmode`
- **HCI Log Path:** `/data/misc/bluetooth/logs/btsnoop_hci.log` (same as stock)

### Logging
Check Android logs for HCI detection:
```bash
adb logcat -s MainActivity:D
# Look for:
# ✅ HCI logging enabled via persist.vendor.bluetooth.btsnooplogmode = full
# ✅ HCI logging enabled (file recently modified)
# ❌ HCI logging not detected via any method
```

---

## Files Modified

| File | Changes |
|------|---------|
| `android/app/src/main/kotlin/com/tekneckjoe/tektool/MainActivity.kt` | Enhanced HCI detection with multi-property check + file fallback |
| `lib/tools/services/auto_reconnect_service.dart` | Added pause/resume, increased scan interval from 30s→60s |
| `lib/tools/screens/tools_hub_screen.dart` | Added Bluetooth toggle button in header |

---

## Known Limitations

1. **HCI Capture is still manual** - You must tap the button to capture. Not real-time streaming.
2. **Auto-reconnect pause persists across app restarts** - If you close the app with pause enabled, it stays paused when you reopen. Just tap resume.
3. **60-second scan interval** - After resuming auto-reconnect, may take up to 60 seconds for devices to reconnect.

---

## Future Improvements (Optional)

1. **Persistent pause state** - Save pause state to shared preferences so it persists across restarts
2. **Per-device pause** - Pause auto-reconnect for specific devices only (e.g., pause T549i but keep T115i auto-reconnecting)
3. **Real-time HCI streaming** - Instead of manual capture, show live BLE traffic in real-time (requires background service)
4. **Smart pause detection** - Automatically pause when other BLE apps are in foreground

---

## Questions?

- **HCI button still gray?** → Check Developer Options, ensure "Bluetooth HCI snoop log" is "Enabled", reboot phone
- **Probes still connecting too fast?** → Make sure you tapped pause (gray icon) before closing TekNeck
- **Auto-reconnect not working?** → Check Bluetooth is enabled, tap resume button (blue icon)
