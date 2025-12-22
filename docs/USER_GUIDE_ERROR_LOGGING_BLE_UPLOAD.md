# User Guide: Error Logging & BLE Auto-Upload Features

## Overview
This guide covers two new automated features added to TekTool:
1. **Automatic Error Reporting** - Crashes and errors automatically saved to Firebase
2. **BLE Sniff Auto-Upload** - Bluetooth protocol captures automatically synced to cloud

---

## 🚨 Automatic Error Reporting

### What It Does
The app now automatically captures and reports any crashes or errors to Firebase. This helps the development team identify and fix bugs faster.

### What's Logged
- Error message and stack trace
- Device information (phone model, OS version)
- App version
- User ID (if logged in)
- Timestamp

### Privacy & Security
- ✅ No personal data (contacts, messages, etc.) is logged
- ✅ Only authenticated users can create error logs
- ✅ Only tech/admin users can view error logs in Firebase
- ✅ Errors are stored securely in Firebase Firestore

### User Experience
- **Silent operation** - Errors are logged automatically in the background
- **No user action required** - Everything happens automatically
- **No performance impact** - Logging is async and non-blocking

---

## 🔵 BLE Sniff Auto-Upload

### What It Does
BLE Sniffer sessions (Bluetooth protocol captures) are now automatically uploaded to Firebase after each scan. This enables:
- Remote analysis of device protocols
- Collaborative troubleshooting
- Machine learning for device detection
- Backup of valuable protocol data

### How to Access Settings

1. Open **Tools** → **BLE Sniffer**
2. Tap the **Settings icon (⚙️)** in the top-right corner
3. Configure your preferences

### Settings Options

#### 1. Auto-Upload Toggle
**Default: ON** ✅

When enabled:
- Sessions automatically upload to Firebase after each scan
- Unsynced sessions upload on app startup
- Progress shown in log messages

When disabled:
- Sessions only saved locally (in Hive storage)
- Manual sync available via "Sync to Firebase" button
- Useful for offline work or bandwidth conservation

#### 2. Upload Mode
**Default: NEW LOGS ONLY** (Recommended)

**NEW logs only mode:**
- ✅ Only uploads sessions that haven't been synced
- ✅ Prevents duplicate data
- ✅ Saves bandwidth
- ✅ Recommended for daily use

**ALL logs mode:**
- ⚠️ Re-uploads ALL sessions, including previously synced
- Useful for:
  - Initial cloud backup
  - Data recovery after Firebase deletion
  - Ensuring complete sync after connection issues
- **Warning:** Can use significant bandwidth

### Visual Indicators

#### Settings Screen Layout
```
┌─────────────────────────────────────────┐
│  BLE Sniffer Settings            [Back] │
├─────────────────────────────────────────┤
│                                          │
│  ┌────────────────────────────────────┐ │
│  │ 🔵 Auto-Upload to Firebase   [ON] │ │
│  │                                    │ │
│  │ BLE sniff logs will automatically  │ │
│  │ sync to Firebase after each scan   │ │
│  └────────────────────────────────────┘ │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │ 🎯 Upload Mode           [OFF]     │ │
│  │                                    │ │
│  │ Upload NEW logs only (skip        │ │
│  │ previously synced)                │ │
│  │                                    │ │
│  │ ℹ️ Recommended mode. Only uploads  │ │
│  │   new data, preventing duplicates │ │
│  │   and saving bandwidth.           │ │
│  └────────────────────────────────────┘ │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │ 💡 How It Works                    │ │
│  │                                    │ │
│  │ ✓ Logs are saved locally first    │ │
│  │ ☁️ Auto-upload syncs in background │ │
│  │ ✓ Uploaded logs marked to prevent │ │
│  │   duplicates                       │ │
│  │ 🔄 Manual sync available from main │ │
│  │   screen                           │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

#### BLE Sniffer Toolbar
```
┌─────────────────────────────────────────┐
│ [←] BLE Sniffer    [⚙️][📜][📊][💾][🔗] │
│                     ▲                    │
│                     │                    │
│              NEW: Settings Icon          │
└─────────────────────────────────────────┘
```

### Log Messages

When auto-upload is active, you'll see these messages in the BLE Sniffer log:

```
[SUCCESS] Session auto-uploaded to Firebase
[INFO] Auto-uploaded 3 unsynced session(s) to Firebase
[ACTION] Syncing to Firebase...
[SUCCESS] Synced to Firebase: sniff_1703267834123
```

### Use Cases

#### Daily Use (Recommended Settings)
- ✅ Auto-Upload: **ON**
- ✅ Upload Mode: **NEW logs only**
- **Why:** Automatic backup without duplicates

#### Offline/Field Work
- ❌ Auto-Upload: **OFF**
- **Why:** Save bandwidth, sync later when on WiFi
- **Action:** Manually sync when back online

#### Initial Cloud Backup
- ✅ Auto-Upload: **ON**
- ⚠️ Upload Mode: **ALL logs**
- **Why:** Ensure all historical data is backed up
- **Action:** Switch back to "NEW logs only" after initial sync

#### Data Recovery
- ✅ Auto-Upload: **ON**
- ⚠️ Upload Mode: **ALL logs**
- **Why:** Re-upload data after Firebase deletion
- **Action:** Switch back to "NEW logs only" when complete

### Troubleshooting

#### Sessions Not Uploading
1. Check internet connection
2. Verify auto-upload is enabled in settings
3. Check Firebase authentication status
4. Look for error messages in BLE Sniffer log

#### Duplicate Data in Firebase
- Switch to "NEW logs only" mode
- This prevents re-uploading synced sessions

#### High Bandwidth Usage
- Disable "ALL logs" mode
- Use "NEW logs only" mode instead
- Disable auto-upload and sync manually on WiFi

---

## For Administrators

### Viewing Error Logs

**Firebase Console:**
1. Go to Firebase Console → Firestore Database
2. Navigate to `app_error_logs` collection
3. View error details, stack traces, and device info

**Useful Queries:**
```javascript
// Recent fatal errors
db.collection('app_error_logs')
  .where('fatal', '==', true)
  .orderBy('timestamp', 'desc')
  .limit(50)

// Errors from specific user
db.collection('app_error_logs')
  .where('userId', '==', 'user-id-here')
  .orderBy('timestamp', 'desc')
```

### Viewing BLE Sniff Logs

**Firebase Console:**
1. Go to Firebase Console → Firestore Database
2. Navigate to `ble_sniff_logs` collection
3. View scan results, device data, and protocol captures

**Filter Auto-Uploaded Sessions:**
```javascript
db.collection('ble_sniff_logs')
  .where('autoUploaded', '==', true)
  .orderBy('timestamp', 'desc')
```

---

## Technical Details

### Session Metadata
Each BLE session in Hive storage includes:
```dart
{
  'id': 'session_1703267834123',
  'timestamp': 1703267834123,
  'date': '2024-12-22T13:30:34.123Z',
  'uploaded': true,          // NEW: Upload tracking
  'uploadedAt': '2024-12-22T13:30:35.456Z', // NEW: Upload timestamp
  'devices': [...],
  'logs': [...],
  'deviceCount': 5,
  'logCount': 42
}
```

### Firebase Collections

**`app_error_logs`** - Automated error reports
- Created by: Any authenticated user
- Read by: Techs and admins only
- Immutable (no updates or deletes)

**`ble_sniff_logs`** - BLE protocol captures
- Created by: Techs and admins
- Read/Write by: Techs and admins
- Auto-uploaded sessions include `autoUploaded: true`

---

## FAQ

**Q: Will error reporting slow down my app?**
A: No. Error logging is asynchronous and has negligible performance impact.

**Q: Can I disable error reporting?**
A: Error reporting cannot be disabled as it's essential for app quality. However, no personal data is logged.

**Q: How much bandwidth does auto-upload use?**
A: Minimal. A typical BLE session is 50-200 KB. Use "NEW logs only" mode to minimize bandwidth.

**Q: What happens if I'm offline?**
A: Sessions are saved locally in Hive storage. They'll auto-upload when you're back online.

**Q: Can I view uploaded sessions on the device?**
A: Yes, through Session History (📜 icon) in BLE Sniffer. Both local and uploaded sessions are visible.

**Q: Will old sessions be re-uploaded?**
A: Only if "ALL logs" mode is enabled. In "NEW logs only" mode, uploaded sessions are skipped.

---

**Last Updated:** December 22, 2024  
**Version:** 1.0.0
