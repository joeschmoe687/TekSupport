---
applyTo: '**'
---

# TekNeck HVAC Support App - Development Standards

> **Flutter mobile app for HVAC contractor support, Bluetooth tool integration, and dispatch**

## 📋 Quick Reference

| What | Where |
|------|-------|
| **Main codebase** | `lib/` |
| **Tests** | `test/` (unit/widget), `integration_test/` (e2e) |
| **BLE services** | `lib/tools/services/` |
| **Screens** | `lib/screens/`, `lib/tools/screens/` |
| **Firebase config** | `lib/firebase_options.dart` |
| **Build scripts** | `scripts/` |
| **Test docs** | `test/README.md` |

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

---

## 📝 Git Workflow

### Commit Messages
Follow conventional commits format:
```
feat: Add Fieldpiece broadcast parsing
fix: Resolve BLE reconnection issue
docs: Update BLE protocol documentation
refactor: Simplify device registry lookup
test: Add PT chart calculation tests
chore: Update dependencies
```

### Branch Naming
```
feature/device-name-support
fix/ble-connection-timeout
refactor/device-registry-cleanup
docs/update-readme
```

### Before Committing
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Manual testing on device complete
- [ ] No debug code or commented-out code
- [ ] No secrets or API keys

---

## 🧪 Testing Strategy

### Test Pyramid
1. **Unit Tests** (fast, many) - `test/`
   - Business logic
   - Calculations (PT charts, conversions)
   - Data parsing
   - No UI dependencies

2. **Widget Tests** (medium speed) - `test/screens/`, `test/widgets/`
   - Individual widgets
   - User interactions
   - UI rendering
   - Mock dependencies

3. **Integration Tests** (slow, few) - `integration_test/`
   - Complete user flows
   - Navigation
   - Firebase integration
   - End-to-end scenarios

### Running Tests Efficiently
```bash
# Fast feedback loop (unit tests only)
flutter test --exclude-tags=widget,integration

# Test specific area
flutter test test/tools/

# Watch mode (run tests on file changes)
flutter test --watch

# Parallel execution (faster)
flutter test --concurrency=4

# Integration tests (requires device)
flutter test integration_test/ --device-id=<device_id>
```

### Test Coverage Goals
- **Critical paths:** 100% (BLE connection, Firebase sync)
- **Business logic:** >80% (calculations, validations)
- **UI widgets:** >60% (key screens, components)
- **Overall:** >70%

Check coverage:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## 🔧 Development Tools

### Recommended VS Code Extensions
- **Dart** - Language support
- **Flutter** - Framework support
- **GitLens** - Git insights
- **Error Lens** - Inline error display
- **Flutter Widget Snippets** - Code snippets

### Debugging
```bash
# View Flutter logs
flutter logs

# Android device logs
adb logcat -s flutter

# BLE-specific debugging
adb logcat -s BluetoothGatt

# Performance profiling
flutter run --profile
# Open DevTools at URL shown
```

### Hot Reload Best Practices
- Use hot reload (r) for UI changes
- Use hot restart (R) for:
  - Changing app state
  - Modifying main()
  - Changing global variables
- Full rebuild for:
  - Native code changes (Android/iOS)
  - Asset changes
  - Dependency updates

---

## 🔒 Security Best Practices

### Secrets Management
- **Never commit:**
  - API keys
  - Firebase private keys
  - Keystore passwords
  - Test credentials
  
- **Use `.env` files:** (gitignored)
  ```dart
  await dotenv.load(fileName: ".env");
  final apiKey = dotenv.env['API_KEY'];
  ```

- **Firebase config:** Safe to commit (public info)
  - `google-services.json`
  - `GoogleService-Info.plist`

### Role-Based Access
Always check user role before showing admin features:
```dart
final user = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
final isAdmin = user.data()?['role'] == 'admin';

if (isAdmin) {
  // Show admin features
}
```

### Firestore Security Rules
Before modifying rules:
1. Review existing rules
2. Test with Firebase Emulator
3. Check impact on mobile app
4. Check impact on web dashboard
5. Deploy to staging first
6. Monitor for auth failures

---

## 🎨 UI/UX Guidelines

### Theme Consistency
Use `AppColors` constants from `lib/widgets/gradient_scaffold.dart`:
```dart
AppColors.primaryPurple   // #7C3AED
AppColors.primaryCyan     // #4EC7F3
AppColors.background      // #0A0A0A
AppColors.surfaceDark     // #1A1A1A
AppColors.textPrimary     // #FFFFFF
AppColors.textSecondary   // #9CA3AF
```

### Responsive Design
```dart
// Use layout utilities
final isMobile = MediaQuery.of(context).size.width < 600;
final isTablet = MediaQuery.of(context).size.width >= 600 &&
                 MediaQuery.of(context).size.width < 1024;

// Use LayoutBuilder for complex layouts
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 600) {
      return MobileLayout();
    }
    return TabletLayout();
  },
)
```

### Loading States
Always show feedback during async operations:
```dart
bool _isLoading = false;

Future<void> _loadData() async {
  setState(() => _isLoading = true);
  try {
    // Async operation
  } catch (e) {
    _showError(e.toString());
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
```

### Error Handling
Show user-friendly messages:
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Failed to connect to device'),
    backgroundColor: Colors.red,
    action: SnackBarAction(
      label: 'Retry',
      onPressed: _retryConnection,
    ),
  ),
);
```

---

## 📦 Dependency Management

### Adding Dependencies
1. **Check necessity:** Can we use existing packages?
2. **Check maintenance:** Last updated? Active issues?
3. **Check license:** Compatible with project?
4. **Check size:** Impact on APK size?
5. **Add to `pubspec.yaml`:**
```yaml
dependencies:
  package_name: ^version
```
6. **Get packages:** `flutter pub get`
7. **Update imports:** Use in code
8. **Test:** Verify functionality
9. **Document:** Update README if significant

### Updating Dependencies
```bash
# Check for updates
flutter pub outdated

# Update all (careful!)
flutter pub upgrade

# Update specific package
flutter pub upgrade package_name

# After updating, always:
flutter clean
flutter pub get
flutter test  # Verify nothing broke
```

---

## Repository Info

- **GitHub:** Private repo (TekNeck-LLC/hvac_support_app)
- **Firebase:** tekneck-support (shared with AirPro website)
- **Package:** com.tekneckjoe.tektool
- **Min SDK:** Android 21 (5.0 Lollipop)
- **Target SDK:** Android 34

## 📚 Additional Resources

- **Flutter Docs:** https://docs.flutter.dev/
- **Firebase Docs:** https://firebase.google.com/docs/flutter
- **BLE Plus Docs:** https://pub.dev/packages/flutter_blue_plus
- **Dart Style Guide:** https://dart.dev/guides/language/effective-dart
