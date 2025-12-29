# TekNeck HVAC Support App (TekTool)

> **Flutter mobile app for HVAC contractors with Bluetooth tool integration, dispatch, and AI-powered support**

## Quick Links
- [Detailed Development Standards](.github/instructions/Expectations.instructions.md)
- [Test Documentation](../test/README.md)
- [Firebase Console](https://console.firebase.google.com/project/tekneck-support)
- [GitHub Repo](https://github.com/TekNeck-LLC/hvac_support_app)

## Tech Stack
- **Frontend:** Flutter/Dart (SDK ^3.0.0)
- **Backend:** Firebase (Firestore, Cloud Functions, FCM, Auth, Storage)
- **BLE:** flutter_blue_plus (device integration)
- **AI:** TekMate AI (admin-only) + Google Gemini (fallback)
- **Supported Devices:** Testo, Fieldpiece, Wey-Tek, ABM-200

## 🧠 AI Assistant Integration (TekMate) - GHOST MODE ADMIN-ONLY
This app integrates with **tekmate-consolidated** (separate repo) which provides:
- **Technician guidance** - AI walks admin techs through service calls step-by-step
- **Device setup wizard** - AI helps integrate new Bluetooth tools
- **HVAC troubleshooting** - Real-time problem-solving during service calls
- **Knowledge synthesis** - Learns from all technician interactions
- **Noob tech training** - Confidence-based guidance for experienced techs

**Ghost Mode Security (CRITICAL):**
- TekMate is COMPLETELY INVISIBLE to non-admin technicians
- Only authenticated admins (role='admin' in Firestore) see TekMate features
- Non-admins get zero TekMate UI, network calls, or evidence of its existence
- `TekMateChatService().init()` returns false for non-admins (silent, no error)
- All TekMate calls go through Cloud Function with Firebase auth + admin role check
- Logs stored in admin-only Firestore collection `admin/tekmate_interactions`

**How it works (Admin tech workflow):**
1. Admin tech asks question in service chat
2. TekMate UI button available (non-admins don't see this button)
3. Cloud Function `tekmateChatProxy` called with admin auth
4. AI generates guidance with confidence score
5. Admin tech reads suggestion, may add personal notes, then uses it
6. TekMate interaction logged to Firebase for learning
7. BLE device captures feed TekMate's device learning (admin only)

**See also:**
- [GHOST_MODE_SETUP.md](../../tekmate-consolidated/GHOST_MODE_SETUP.md) - Deployment & security verification

## Shared Firebase Backend
This app shares Firebase project `tekneck-support` with:
- AirPro website (`airpro-website`)
- TekMate consolidated AI (`tekmate-consolidated`)

**Shared Collections:**
- `chats` - Customer support & technician guidance (all platforms read/write)
- `users` - User profiles (all platforms read, web manages)
- `customers` - CRM data (all platforms read, web manages)
- `jobs` - Dispatch/work orders (all platforms read, web creates)
- `ble_sniff_logs` - BLE protocol captures (app writes, TekMate analyzes for device learning)

**When modifying Firestore:**
- Check impact on web dashboard AND TekMate AI
- Don't change security rules without testing all three platforms
- Keep collection schemas compatible
- BLE captures logged for TekMate device protocol learning
- Service call interactions logged for technician training

## Code Conventions
- Singleton pattern for services (BluetoothService, DeviceDataService)
- All BLE parsing goes in device_registry.dart
- Check `mounted` before `setState()` calls
- SharedPreferences for device persistence

## BLE Protocol Notes
- Testo probes require init handshake before streaming
- Fieldpiece devices are broadcast-only (ADV_NONCONN_IND)
- Always emit ReconnectStatus.connected after BLE connect

## Critical Files (DO NOT MODIFY BEHAVIOR)
- `auto_reconnect_service.dart`: `markConnected()` must emit status
- `device_registry.dart`: Device profiles and parsing logic
- `device_data_service.dart`: Central BLE data streaming

## Common Tasks & Examples

### Adding a New BLE Device
1. **Capture protocol:** Tools → BLE Sniffer → Connect device
2. **Sync to Firebase:** Sniffer auto-uploads to `ble_sniff_logs`
3. **Add profile:** Edit `lib/tools/services/device_registry.dart`
```dart
'YOUR-SERVICE-UUID': DeviceProfile(
  name: 'Device Name',
  manufacturer: 'Brand',
  type: DeviceType.pressure, // or temperature, scale, etc.
  parseCharacteristic: (uuid, data) {
    // Parse raw bytes to measurement
    return YourMeasurement(value: parseFloat(data));
  },
),
```
4. **Add parser:** Edit `lib/tools/services/device_data_service.dart`
5. **Test:** Connect device, verify data appears in Tools Hub
6. **Document:** Add protocol notes to `docs/BLE-Sniffing/`

### Adding a New Screen
1. **Create widget:** `lib/screens/your_screen.dart`
```dart
class YourScreen extends StatefulWidget {
  const YourScreen({Key? key}) : super(key: key);
  
  @override
  State<YourScreen> createState() => _YourScreenState();
}

class _YourScreenState extends State<YourScreen> {
  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      title: 'Your Screen',
      body: // Your UI here
    );
  }
  
  @override
  void dispose() {
    // Clean up listeners/controllers
    super.dispose();
  }
}
```
2. **Add navigation:** Link from relevant screen
3. **Add tests:** `test/screens/your_screen_test.dart`
4. **Test manually:** Run on device, verify navigation

### Modifying Firebase Collection
1. **Check schema:** Review existing documents in Firebase Console
2. **Check web dashboard:** Will this break the website?
3. **Update security rules:** `firestore.rules` if needed
4. **Test both platforms:** Mobile app + web dashboard
5. **Document changes:** Update README or code comments

### Debugging BLE Issues
```bash
# Enable Android BLE logging
adb shell settings put global bluetooth_hci_log 1
adb shell setprop persist.bluetooth.btsnoopenable true

# View Flutter logs
adb logcat | grep flutter

# Pull bugreport with BLE logs
adb bugreport bugreport_$(date +%Y%m%d_%H%M%S).zip

# Clear app data (fresh start)
adb shell pm clear com.tekneckjoe.tektool
```

## File Locations
- **BLE services:** `lib/tools/services/`
- **Screens:** `lib/tools/screens/`, `lib/screens/`
- **Utils:** `lib/tools/utils/`
- **Tests:** `test/` (unit/widget), `integration_test/` (e2e)
- **Scripts:** `scripts/` (deploy, test runners)

## Testing & Quality

### Running Tests
```bash
# Unit & widget tests (fast)
flutter test

# Specific test file
flutter test test/tools/utils/pt_chart_test.dart

# With coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Integration tests (requires device)
flutter test integration_test/app_test.dart --device-id=<device_id>

# Comprehensive test script
./scripts/run_tests.sh
```

### Linting & Analysis
```bash
# Static analysis
flutter analyze

# Check for outdated packages
flutter pub outdated

# Full environment check
flutter doctor
```

**Before committing:**
1. Run `flutter analyze` - must pass with no errors
2. Run `flutter test` - all tests must pass
3. Test on physical Android device for BLE features
4. Verify Firebase sync with web dashboard

### Build Commands
```bash
# Debug build
flutter run

# Release APK
flutter build apk --release
# Output: android/app/build/outputs/apk/release/app-release.apk

# Manual install + hot reload (recommended)
cd android && ./gradlew assembleDebug
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.tekneckjoe.tektool/.MainActivity
flutter attach -d <device_id>

# Clean rebuild (fixes weird errors)
flutter clean && flutter pub get && flutter run
```

## Development Workflow

### Starting Development
1. **Check Flutter environment:** `flutter doctor`
2. **Get dependencies:** `flutter pub get`
3. **Run analyzer:** `flutter analyze` (baseline check)
4. **Start development:** `flutter run` or manual install method

### Making Changes
1. **Make minimal, surgical changes** - smallest possible modifications
2. **Test early and often** - run relevant tests after each change
3. **Check `mounted` before `setState()`** - prevent disposed widget errors
4. **Use existing patterns** - follow codebase conventions
5. **Don't break critical flows** - especially BLE connection chain

### Firebase Deployments
```bash
# Deploy TekMate Cloud Functions (admin only)
./scripts/deploy-tekmate.sh

# Deploy Gemini AI functions
./scripts/deploy-gemini.sh

# Check Firestore rules before deploy
# Remember: shared with AirPro website!
```

## Common Issues & Solutions

### BLE Not Connecting
1. Verify `markConnected()` emits event in `auto_reconnect_service.dart`
2. Check device is in range (RSSI > -80 dBm)
3. Verify Android location permission granted
4. Try forgetting and re-pairing device
5. Check device battery level

### Firebase Sync Issues
1. Check internet connection
2. Verify `google-services.json` is current
3. Check Firestore security rules allow operation
4. Test with web dashboard to isolate issue
5. Check Firebase Auth token is valid

### Build Errors
```bash
# AGP/Gradle issues
cd android && ./gradlew clean && cd ..
flutter clean && flutter pub get

# Flutter not found
export PATH="$HOME/flutter/bin:$PATH"

# Stale IDE errors
# Ignore stale AGP 7.4.2 errors, reload VS Code window
```

### Test Failures
- **BLE tests:** Require physical hardware, skip in CI
- **Firebase tests:** Need valid test credentials
- **SMS tests:** Android only, manual testing required

## Security & Best Practices

### DO NOT Commit
- `android/key.properties` - Keystore passwords
- `*.jks`, `*.keystore` - Signing keys
- API keys in plain text
- Test credentials

### Ghost Mode (TekMate AI)
- **CRITICAL:** TekMate is invisible to non-admin users
- All TekMate UI elements hidden from non-admins
- Admin checks: `role='admin'` in Firestore users collection
- Cloud Functions enforce admin-only access
- Logs stored in admin-only collection

### Firestore Security
- Read security rules before modifying
- Test impact on web dashboard AND mobile app
- Don't delete shared collections
- Validate role-based access control