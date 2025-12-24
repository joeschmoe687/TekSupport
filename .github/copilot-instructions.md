# TekNeck HVAC Support App - AI Agent Instructions

> **Last Updated:** December 23, 2025  
> **For:** GitHub Copilot, Copilot Chat, and AI coding assistants

---

## 🎯 QUICK START FOR AGENTS

### When User Says "Handle the most important task" or "Do task #X":
1. **Read [TODO.md](../../TODO.md)** immediately
2. Find the task by number in the **🤖 AGENT TASKS** section
3. Check task type icon:
   - 🤖 = Agent can do autonomously (DO THESE)
   - 👤 = Joey must do manually (SKIP - tell user it's manual)
   - 🤝 = Requires Joey + Agent together (ASK if Joey is available)
4. Execute the task completely following all steps listed
5. Report results with clear success/failure status

### Task Priority:
- Tasks are numbered by priority (1 = most important)
- When asked for "most important task" → find lowest numbered 🤖 task
- Skip any 👤 manual tasks - just inform user those need their action

---

## 📋 PROJECT CONTEXT

### What This Is
- **Flutter mobile app** for HVAC contractors
- BLE device integration (Testo, Fieldpiece, Wey-Tek, ABM-200)
- Firebase backend (shared with AirPro website)
- TekMate AI integration (Ghost Mode - admin only)

### Current Status
- ✅ BLE device support working
- ✅ Firebase sync working
- ✅ TekMate code complete
- ⚠️ TekMate deployment pending (Cloud Function)
- ⚠️ TekMate backend verification needed

### Ghost Mode (CRITICAL)
- TekMate is **INVISIBLE** to non-admin users
- Only role='admin' in Firestore sees TekMate UI
- Non-admins get ZERO TekMate features, network calls, or UI elements

### TekMate Setup & Testing
1. **Create Firestore document:**
   ```
   Collection: settings
   Document:   tekmate
   ```
   ```json
   {
     "apiUrl": "https://us-central1-tekneck-support.cloudfunctions.net/tekmateChatProxy",
     "enabled": true,
     "models": ["hvac-support", "tekmate-trained", "tekmate-memory"],
     "timeout": 120000,
     "cloudflareTimeout": 120
   }
   ```

2. **Test with admin user:**
   - Must have `role: 'admin'` in Firestore `users/{uid}`
   - Open TekMate chat feature
   - Ask HVAC question: "What is R-22 pressure at 90°F?"
   - Should receive technical response with pressure value (226 PSIG)

3. **Monitor:**
   ```bash
   firebase functions:log
   # Check admin/tekmate_interactions in Firestore for interaction logs
   ```

---

## 🔧 CRITICAL FILES (Don't Break)

| File | Critical Behavior |
|------|-------------------|
| `auto_reconnect_service.dart` | `markConnected()` MUST emit `ReconnectStatus.connected` |
| `device_registry.dart` | Device profiles and BLE parsing logic |
| `device_data_service.dart` | Central BLE data streaming |
| `tekmate_chat_service.dart` | Returns null for non-admins (Ghost Mode) |

### Key Paths
- **BLE services:** `lib/tools/services/`
- **Screens:** `lib/screens/`, `lib/tools/screens/`
- **Firebase functions:** `functions/index.js`
- **Tests:** `test/`, `integration_test/`

---

## 🛠️ COMMANDS

```bash
# Run app
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app
flutter run

# Run tests
flutter test

# Build APK
flutter build apk --release

# Deploy TekMate function
./scripts/deploy-tekmate.sh
# OR: cd functions && npm install && firebase deploy --only functions:tekmateChatProxy

# Clean rebuild
flutter clean && flutter pub get && flutter run
```

---

## 📝 CODE STYLE

```dart
// Always check mounted before setState
if (mounted) {
  setState(() {
    _data = newData;
  });
}

// Singleton pattern for services
class MyService {
  static final MyService _instance = MyService._internal();
  factory MyService() => _instance;
  MyService._internal();
}

// Error handling
try {
  await someAsyncOperation();
} catch (e) {
  debugPrint('Error: $e');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Something went wrong')),
  );
}
```

---

## ⚠️ BLE PROTOCOL NOTES

- **Testo:** Requires init handshake before streaming data
- **Fieldpiece:** Broadcast-only (ADV_NONCONN_IND) - NO GATT connection possible
  - Parse manufacturer data (ID `0x5046`)
  - No service UUIDs, read advertisement data directly
- **Wey-Tek/ABM-200:** Standard GATT connection

---

## ✅ AFTER COMPLETING ANY TASK

1. `flutter analyze` - No errors
2. `flutter test` - All pass
3. Test on physical device for BLE
4. Update TODO.md (mark task complete)
5. Clear report: what was done + results

---

## 🔗 RELATED PROJECTS

| Project | Path | Relation |
|---------|------|----------|
| AirPro Website | `../airpro-website/` | Shared Firebase, same TekMate |
| Wear OS App | `../wearos-tekmate/` | Same TekMate backend |
| TekMate Server | joloserve:192.168.1.117 | AI backend |

---

## � SERVER ACCESS (TekMate Backend)

**Passwordless SSH is configured:**
```bash
ssh joloserve
# No password needed! Uses ~/.ssh/id_ed25519_server
```

**Server Details:**
- **Host alias:** `joloserve`
- **IP:** `192.168.1.117`
- **User:** `jolo`

**Useful Commands:**
```bash
ssh joloserve 'systemctl status tekmate tekmate-proxy'
ssh joloserve 'journalctl -u tekmate -f'
ssh -t joloserve 'sudo systemctl restart tekmate'
```

---

## �🔥 FIREBASE INFO

- **Project:** tekneck-support
- **Console:** https://console.firebase.google.com/project/tekneck-support

### Shared Collections
| Collection | Purpose | Who writes |
|------------|---------|------------|
| `chats` | Customer support | All platforms |
| `users` | User profiles | Web manages |
| `customers` | CRM data | Web manages |
| `jobs` | Dispatch | Web creates, app updates |
| `ble_sniff_logs` | Protocol captures | App only |
| `admin/tekmate_interactions` | AI logs | Admin only |
