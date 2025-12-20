---
applyTo: '**'
---

# TekNeck HVAC Support App - Development Standards

> **Flutter mobile app for HVAC contractor support, Bluetooth tool integration, and dispatch**

## 🔗 Firebase Integration (CRITICAL)

**This app shares Firebase backend with the AirPro Website:**

| Project | Firebase Project ID | Description |
|---------|---------------------|-------------|
| **This App** | `tekneck-support` | Flutter mobile app (Android/iOS) |
| **AirPro Website** | `tekneck-support` | Web dashboard at airpronwa.com |

**Shared Collections:**
- `chats` - Customer support conversations
- `users` - User profiles (customers, techs, admins)
- `customers` - Customer CRM data
- `jobs` - Dispatch/work orders
- `sessions` - Active support sessions
- `ble_sniff_logs` - BLE protocol captures (from this app)

**Firebase Config:** `lib/firebase_options.dart`

**DO NOT:**
- Create separate Firebase projects
- Modify security rules without checking web dashboard impact
- Delete shared collections

---

## Project Structure

```
lib/
├── main.dart                    # App entry, Firebase init
├── firebase_options.dart        # Firebase config (auto-generated)
├── screens/                     # Main app screens
│   ├── home_screen.dart         # Dashboard
│   ├── chat_screen.dart         # Support chat
│   └── settings_screen.dart     # App settings
├── tools/                       # TekTool - Bluetooth hub
│   ├── screens/
│   │   ├── tools_hub_screen.dart      # Main tools dashboard
│   │   ├── tek_devices_screen.dart    # Device manager
│   │   ├── tek_scan_screen.dart       # BLE scanner
│   │   ├── ble_sniffer_screen.dart    # Protocol analyzer (admin)
│   │   ├── airflow_screen.dart        # ABM-200 airflow display
│   │   └── scale_screen.dart          # Wey-Tek scale display
│   └── services/
│       ├── device_data_service.dart   # Central data stream
│       ├── device_registry.dart       # Known device profiles
│       └── auto_reconnect_service.dart # BLE reconnection
├── services/                    # App-wide services
│   ├── auth_service.dart        # Firebase Auth
│   ├── chat_service.dart        # Firestore chat
│   └── notification_service.dart # FCM push
└── widgets/                     # Reusable UI components
```

---

## Core Principles

### 1. Bluetooth Architecture (DO NOT BREAK)
```
Connection Flow:
_SensorPickerSheet._connectAndAssign() 
  → bleService.connectToDevice()
  → reconnectService.markConnected()    ← MUST emit event
  → DeviceDataService._subscribeToDevice()
  → Probe streams data to UI
```

**Key file:** `auto_reconnect_service.dart` - `markConnected()` MUST emit `ReconnectStatus.connected`

### 2. Device Protocol Implementation
When adding new HVAC Bluetooth devices:
1. Capture protocol with BLE Sniffer (Tools → Sniffer)
2. Sync capture to Firebase (`ble_sniff_logs`)
3. Add profile to `device_registry.dart`
4. Add parser to `device_data_service.dart`
5. Document in `docs/BLE-Sniffing/`

### 3. Firebase Sync
- Real-time listeners for chat/dispatch
- Offline persistence enabled
- Sync BLE captures to cloud for protocol analysis

---

## Coding Standards

### Dart/Flutter
- **Null safety required** - Use `?` and `!` appropriately
- **State management** - Provider + StreamBuilder for BLE data
- **Error handling** - Try/catch with user-friendly snackbars
- **Logging** - Use `debugPrint()` for dev, Firebase Analytics for prod

### Naming Conventions
```dart
// Files: snake_case
device_data_service.dart
tools_hub_screen.dart

// Classes: PascalCase
class DeviceDataService {}
class ToolsHubScreen extends StatefulWidget {}

// Variables/methods: camelCase
final deviceName = 'Testo T115i';
void _connectToDevice() {}

// Constants: camelCase or SCREAMING_SNAKE for config
const primaryCyan = Color(0xFF4EC7F3);
const FIREBASE_PROJECT_ID = 'tekneck-support';
```

### Theme
```dart
// Match website gradient theme
static const primaryPurple = Color(0xFF7C3AED);
static const primaryCyan = Color(0xFF4EC7F3);
static const background = Color(0xFF0A0A0A);
static const surfaceDark = Color(0xFF1A1A1A);
```

---

## BLE Device Support

### ✅ Currently Supported
| Device | Protocol Status | Service UUID |
|--------|----------------|--------------|
| Testo T115i/T549i | Full | `0000fff0-...` |
| Wey-Tek HD Scale | Full | `E3B744F3-4309-4A3A-B877-CCACD9EFB97D` |
| ABM-200 Airflow | Full | `961f0001-d2d6-43e3-a417-3bb8217e0e01` |
| Fieldpiece (all) | Broadcast-only | Manufacturer ID `0x5046` |

### ⏳ Planned
- CPS Probes
- Yellow Jacket
- iManifold

### Fieldpiece Note
Fieldpiece devices use **non-connectable advertisements** (`eventType=0x10`). They broadcast measurement data in manufacturer-specific data (ID `0x5046`). **No GATT connection possible.** Parse advertisement data directly.

---

## Build Commands

```bash
# Development
flutter run                      # Debug build
flutter run --release           # Release build

# Android APK
flutter build apk --release     # APK at build/app/outputs/flutter-apk/

# iOS (requires Xcode)
flutter build ios --release     # Needs Apple Developer account

# Clean rebuild
flutter clean && flutter pub get && flutter run
```

---

## Testing Checklist

Before committing:
- [ ] `flutter analyze` - No errors
- [ ] Test on physical Android device (BLE requires real hardware)
- [ ] Verify Firebase connection works
- [ ] Check BLE device connections
- [ ] Test chat sync with website

---

## 🔗 GitHub Repository

**Private Repo:** [joeschmoe687/hvac_support_app](https://github.com/joeschmoe687/hvac_support_app)

---

## Security

### Secrets (DO NOT COMMIT)
- `android/key.properties` - Keystore passwords
- `android/app/google-services.json` - Firebase config (ok to commit)
- `ios/Runner/GoogleService-Info.plist` - Firebase config (ok to commit)
- Any API keys in plain text

### Already in .gitignore
```
*.jks
*.keystore
key.properties
local.properties
```

---

## Common Issues

### BLE Not Connecting
1. Check `markConnected()` emits event
2. Verify device is in range (RSSI > -80)
3. Check Android location permission granted
4. Try forgetting and re-pairing device

### Firebase Sync Failed
1. Check internet connection
2. Verify `google-services.json` is current
3. Check Firestore security rules allow write

### Build Errors
```bash
# AGP/Gradle issues
cd android && ./gradlew clean && cd ..
flutter clean && flutter pub get
```

---

## AI Assistant Guidelines

### DO
- Check `device_data_service.dart` before modifying BLE logic
- Verify Firebase operations against web dashboard
- Test on physical device for BLE features
- Use existing patterns from codebase

### DON'T
- Break the BLE connection chain
- Create separate Firebase projects
- Commit keystore files
- Use deprecated Flutter APIs

### When Modifying BLE
1. Read the device registry first
2. Check existing protocol implementations
3. Test with real hardware
4. Document any protocol findings

---

## Repository Info

- **GitHub:** Private repo (tekneckjoe/hvac_support_app)
- **Firebase:** tekneck-support (shared with AirPro website)
- **Package:** com.tekneckjoe.hvacsupport.hvac_support_app
