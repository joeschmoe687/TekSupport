# TekTool - Universal HVAC Bluetooth Hub

Mobile app for HVAC contractors: Bluetooth tool connectivity, dispatch, messaging, and CRM-lite.

## 🔗 GitHub & Firebase Integration

> **IMPORTANT FOR COPILOT/AI AGENTS**: This app shares a Firebase backend with the AirPro website.

| Resource | Location |
|----------|----------|
| **GitHub Repo** | [joeschmoe687/hvac_support_app](https://github.com/joeschmoe687/hvac_support_app) (private - will be renamed to tektool) |
| **Firebase Project** | `tekneck-support` |
| **AirPro Website Repo** | `airpro-website` (same workspace) |
| **Website URL** | [airpronwa.com](https://airpronwa.com) |
| **Firebase Console** | [console.firebase.google.com/project/tekneck-support](https://console.firebase.google.com/project/tekneck-support) |

**Shared Firebase Resources:**
- **Firestore** - `chat_sessions`, `users`, `work_orders`, `ble_sniff_logs` collections
- **Firebase Auth** - Same user accounts across web and mobile
- **Cloud Functions** - Shared functions in `airpro-website/functions/`
- **FCM** - Push notifications for both platforms
- **Cloud Storage** - Shared file storage

**Cross-Platform Features:**
- Customer chats sync between mobile app and admin dashboard
- Work orders created on web appear in mobile dispatch
- BLE sniff captures from mobile sync to Firebase for analysis
- User roles (admin/tech/customer) shared across platforms

## Status (Dec 19, 2025)
- ✅ Android builds successfully (AGP 8.1.1, Kotlin 1.8.22, Java 17)
- ✅ Release APK: `build/app/outputs/flutter-apk/app-release.apk` (55MB)
- ✅ Gradient theme matching website (purple #7C3AED, cyan #4EC7F3)
- ✅ FCM Push notifications implemented (admin + customer alerts)
- ✅ **Mark Session Complete** - Techs can mark chats as complete (pay-per-issue model)
- ✅ **Paid Support System** - Dynamic pricing, WhatsApp-only routing, CST business hours
- ✅ **Website rebranded to TekNeck** - Live at airpronwa.com & tekneck-support.web.app
- ✅ **TekTool** - Universal HVAC Bluetooth hub (Tools + Devices tabs)
- ✅ **Testo BLE Protocol** - Reverse-engineered exact init sequence, probes work independently
- ✅ **Wey-Tek BLE Protocol** - Full protocol reverse-engineered, scale works independently
- ✅ **ABM-200 BLE Protocol** - Airflow meter data capture working (Dec 19)
- ⏳ **Airflow Screen UI** - Next: Build visual display for CFM/temp/humidity
- ✅ **BLE Sniffer** - In-app protocol analyzer with auto-subscribe, cloud sync (Dec 19)
- ✅ **SMS Auto-Responder** - Native Android SMS auto-reply during off-hours (admin only)
- ⚠️ `flutter run` has APK path detection bug with current AGP version

## 🔧 TekTool - Universal HVAC Bluetooth Hub (Dec 18, 2025)

Universal app for connecting all your Bluetooth HVAC tools in one place. Replaces manufacturer-specific apps (Fieldpiece, Testo, Parker, CCS, Weytek).

### ✅ Wey-Tek HD Scale Integration (Dec 18, 2025)
**BLE protocol fully reverse-engineered!** Scale works independently. Tested accurate to 7oz.

- **Weight Readings** - 0.1 oz resolution, 32-bit signed grams → oz conversion
- **Unit Support** - lb, lb:oz, kg, oz (unit indicator in data packet)
- **Service UUID**: `E3B744F3-4309-4A3A-B877-CCACD9EFB97D`
- **Init Sequence** (after enabling notifications):
  ```
  Link: aa aa aa aa 4c 00 00 00 00 00 00 4c 00
  Ack:  aa aa aa aa 41 00 00 00 00 00 00 41 00
  Init: aa aa aa aa 49 00 00 00 00 00 00 49 00
  ```
- **Tare Command**: `aa aa aa aa 4f 00 00 00 00 00 00 4f 00`
- **Weight Format**: `aa aa aa aa 57 [flags] [int32 LE grams] [unit] [chk] 00` (divide by 28.3495 for oz)

### ✅ Testo Smart Probe Integration (Dec 18, 2025)
**BLE protocol fully reverse-engineered!** Probes now work independently without Testo app pre-priming.

- **T115i Pipe Clamp Temperature** - Accurate readings (tested at 68.8°F ambient)
- **T549i Differential Pressure** - Int16/100 format (0.2-1.0 PSI readings confirmed)
- **Init Sequence Captured** - Exact byte commands with CRCs via Android HCI snoop log:
  ```
  Handshake:    56 00 03 00 00 00 0c 69 02 3e 81
  Start stream: 20 01 00 00 00 00 3a bb
  Measurements: 11 03 00 00 00 00 47 5a, 11 04 00 00 00 00 f2 9a
  ```
- **Sensor Assignment** - Tap Low/High side or Suction/Liquid line to assign sensors
- **Auto-Switch** - Tapping a different slot auto-moves sensor AND clears old slot display
- **Zero Sensor** - Zero button in pressure picker stores offset for accurate differential readings
- **PT Chart Integration** - Saturation temps calculated from live pressure readings
- **Direct Gauge Connection** - Connect probes directly from gauge slot picker ✅

### ⚠️ Connection Architecture (Critical - Do Not Modify)
The connection chain MUST remain intact for probes to receive data:

1. **`_SensorPickerSheet._connectAndAssign()`** → calls `bleService.connectToDevice()`
2. **`reconnectService.markConnected()`** → MUST emit `ReconnectStatus.connected` event
3. **`DeviceDataService`** listens for connected events → triggers `_subscribeToDevice()`
4. **`_subscribeToDevice()`** → discovers services, enables fff2 notify, sends init commands
5. **Probe wakes up** → starts streaming data to gauge screen

**Key file:** `lib/tools/services/auto_reconnect_service.dart` - `markConnected()` must emit status!

### Features
- **Tools Hub** - Live readings from all connected devices
  - Superheat/subcool calculations with P/T charts
  - Refrigerant picker (R22, R410A, R407C, Nu-22, R32, R454B)
  - Device grid with connection status
  - Support chat integration
- **Devices** - Manage paired Bluetooth tools
  - Connection status + battery level
  - Swipe to forget devices
  - Quick reconnect
  - **Device persistence** - Saved to storage on connect
  - **Auto-load** - Loads saved devices on screen open
- **Device Scan** - Find and connect HVAC tools
  - Signal strength indicators
  - "SUPPORTED" badge for known devices
  - One-tap connect
- **BLE Sniffer** (Admin only) - Reverse-engineer device protocols
  - GATT service/characteristic explorer
  - Read/Subscribe to characteristics
  - Console logging with export
  - **Data Interpreter** - Parse raw bytes as int8/16/32, float, string
  - **Save Profile** - Export device config for production use
  - **Write Value** - Send hex values to characteristics
  - **Auto-Subscribe** - Connects and subscribes to ALL notify chars automatically (Dec 19) ✅
  - **Auto-Read** - Reads ALL readable characteristics on connect (Dec 19) ✅
  - **Cloud Sync** - Syncs captures to Firebase `ble_sniff_logs` (Dec 19) ✅
  - **Session History** - Local persistence with load/delete/sync (Dec 19) ✅
  - **Device ID** - Manufacturer detection from Bluetooth Company IDs (Dec 19) ✅
- **Storage Screen** (Settings → Storage)
  - View saved devices, connection history
  - ML learned patterns storage
  - Custom device profiles with export code
  - Clear all data option

### Device Persistence & Auto-Reconnect
- **DeviceStorageService** - SharedPreferences-based storage
  - Saved devices with manufacturer, type, auto-reconnect flag
  - Connection event history with timestamps
  - ML learned patterns (data type, parse method, confidence)
  - Custom device profiles for production integration
- **AutoReconnectService** - Background reconnection
  - Scans every 30 seconds for known devices
  - Auto-connects when devices power back on
  - **Platform name fallback** - Reconnects via BLE name if not in storage
  - Connection state monitoring
  - Status stream for UI updates
- **Disconnect Notifications** - SnackBar alerts when devices connect/disconnect on gauge & scale screens

### Supported Devices
- ✅ **Wey-Tek HD Scale** - Refrigerant charging scale (BLE protocol complete Dec 18, 2025)
- ✅ **Testo T115i** - Pipe clamp temperature probe (BLE protocol complete)
- ✅ **Testo T549i** - Differential pressure probe (BLE protocol complete)
- ✅ **ABM-200 Airflow Meter** - WeatherFlow/AAB/CPS (BLE protocol captured Dec 19, 2025)
- 🔧 CCS Airflow Meter (needs BLE sniffing)
- More devices added via BLE sniffing

### Technical Stack
- `flutter_blue_plus` - BLE connectivity
- `shared_preferences` - Device persistence (JSON)
- `flutter_foreground_task` - Persistent BLE in background
- `google_mlkit_text_recognition` - OCR for equipment nameplates
- `geocoding` - Job location auto-detect

## Build & Deploy (Android)

### Option 1: Manual Install + Hot Reload (Recommended)
```bash
# Build debug APK
cd android && ./gradlew assembleDebug

# Install and launch
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.tekneckjoe.hvacsupport.hvac_support_app/.MainActivity

# Attach for hot reload
flutter attach -d RFCY518ZA0Y
```

### Option 2: Release Build
```bash
flutter build apk
# Output: android/app/build/outputs/apk/release/app-release.apk
```

### Troubleshooting
- Stale IDE errors about AGP 7.4.2: Ignore (reload VS Code window to clear)
- `flutter run` fails: Use manual install method above
- Symlink exists at `build/app` → `android/app/build/outputs` for compatibility

## 🌙 Overnight Automation

Run unattended builds, tests, and BLE log captures overnight:

```bash
# From project root
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app
nohup ./scripts/overnight-tasks.sh > overnight.log 2>&1 &
```

**What it does:**
1. Keeps phone screen awake (if connected via USB)
2. `flutter clean` + `flutter pub get`
3. `flutter analyze` → logs errors/warnings
4. `flutter test` → runs all tests
5. Builds debug + release APKs
6. Captures BLE HCI snoop logs from phone
7. Saves all logs to `logs/` folder with timestamps

**Check results in the morning:**
```bash
cat overnight.log                    # Summary
cat logs/analyze_*.log               # Code analysis
cat logs/test_*.log                  # Test results
ls -la build/app/outputs/flutter-apk/  # APKs
```

**Make it a nightly routine** - Run before bed, review logs with coffee.

## Features

### 💰 Paid Support System (Dec 17, 2025) ✅
- **Support Contact Screen** - Dedicated interface with phone/video/text options
- **Dynamic Pricing** - Business Hours (9-5 CST) vs 24HR support with different rates
  - Business Hours: Message $5, Phone $45, Video $60
  - 24HR Support: Message $45, Phone $60, Video $80
- **Real-Time Pricing** - Live fetch from Firestore `settings/pricing` document
- **CST Business Hours Detection** - Automatic timezone-aware detection (Mon-Fri 9-5 CST)
- **WhatsApp-Only Routing** - All support channels (phone, text, video) open WhatsApp Business
  - Prevents users from bypassing payment via direct phone calls
  - Message pre-fills with support type (phone call, video, text support)
- **Transaction Logging** - Logs all support requests to Firestore with userId, type, amount, timestamp
- **App-Web Parity** - Identical support experience on Flutter app and web UI
- **Stripe Payment** (web) - Card payment modal with success logging (app routes through payment interceptor)

### 📱 SMS Auto-Responder (Dec 18, 2025) - Admin Only
Native Android SMS auto-reply for off-hours support. No Firebase or third-party SMS API required.

- **Native Android** - BroadcastReceiver intercepts incoming SMS, SmsManager sends replies
- **Off-Hours Only** - Auto-replies OUTSIDE configured business hours (default 7am-7pm)
- **1-Hour Cooldown** - Prevents spam loops (max 1 reply per phone number per hour)
- **Custom Message** - Editable auto-reply text in Settings
- **Permission UI** - Visual permission status with grant button
- **Send Test SMS** - Test button to verify functionality
- **Reply Counter** - Tracks total auto-replies sent
- **Works Offline** - Uses your phone's native SMS, no internet needed

**Files:**
- `android/.../MainActivity.kt` - MethodChannel bridge
- `android/.../SmsReceiver.kt` - BroadcastReceiver + SmsManager
- `lib/auto_responder/auto_responder_service.dart` - Flutter service
- Settings screen shows controls for admin/tech users only

### Admin Dashboard (Role-Based)
- **Overview**: Real-time stats (Jobs Today, Open Invoices) with quick actions
- **Dispatch**: Full job management with date filters and status tracking
- **Customers**: Search by name/email/phone, Firestore streaming
- **Invoices**: Status badges (paid/unpaid/overdue) with color coding
- **Pricebook**: Categories with item counts, tap to view items (name/code/price)
- **Settings**: Admin toggles for chat notifications, dispatch, login requirements
- **Admin Tab**: Conditional visibility for admin role only

### Universal Password Autofill
- **Auto-discovery**: Works with Samsung Pass, Google Password Manager, NordPass, 1Password, Bitwarden, etc.
- **Zero configuration**: Password managers automatically detect login form on any device
- **One-tap login**: Type email → password manager prompts → credentials fill automatically

### Dispatch Screen
- Filters: all, unassigned, assigned, completed
- Data: `jobDispatch` (Firestore), filters by selected date (`yyyy-MM-dd` prefix)
- Actions: assign / complete with snackbar feedback


## Recent Changes (Dec 18, 2025)

### 🔧 TekTool - Universal HVAC Bluetooth Hub ✅ NEW
- ✅ `lib/bluetooth/bluetooth_service.dart` - Singleton BLE manager
- ✅ `lib/tools/services/device_registry.dart` - Known HVAC device profiles
- ✅ `lib/tools/services/refrigerant_detector.dart` - Auto-detect refrigerant
- ✅ `lib/tools/services/gauge_zero_service.dart` - Smart zero prompt logic
- ✅ `lib/tools/utils/pt_chart.dart` - P/T saturation tables (6 refrigerants)
- ✅ `lib/tools/models/connected_device.dart` - Device data model
- ✅ `lib/tools/screens/tools_hub_screen.dart` - Main dashboard
- ✅ `lib/tools/screens/devices_screen.dart` - Device management
- ✅ `lib/tools/screens/device_scan_screen.dart` - BLE scanning
- ✅ `lib/tools/screens/ble_sniffer_screen.dart` - Admin debugging tool
- ✅ `lib/tools/widgets/zero_prompt_dialog.dart` - Zero gauges modal
- ✅ `lib/tools/widgets/refrigerant_confirm_dialog.dart` - R22 confirmation
- ✅ `lib/screens/main_navigation_screen.dart` - Added Tools + Devices tabs
- ✅ Updated Android/iOS permissions for Bluetooth + background

## Recent Changes (Dec 17, 2025)

### 💰 Paid Support System Implementation ✅
- ✅ `lib/screens/support_contact_screen.dart` - New screen with pricing display
  - Dynamic price fetching from Firestore `settings/pricing`
  - CST business hours detection with time display
  - Phone/Video options route through WhatsApp Business (no direct phone number)
  - Transaction logging with correct pricing for each service type
  - UI: 4 service cards (Text Chat, Phone Call, Video Call, Direct Info)
- ✅ `lib/screens/chat_screen.dart` - Added phone icon button in header
  - Navigates to SupportContactScreen
  - Always-accessible support option from any chat
- ✅ `USERS/pages/chat.html` (Web) - Support modal with Stripe integration
  - Fetches pricing from same Firestore document (app-web parity)
  - Shows business hours indicator and current CST time
  - Payment flow: Select service → Stripe modal → Card entry → WhatsApp opens
  - All support channels (text/phone/video/whatsapp) route through WhatsApp Business
  - Transaction logging to Firestore on successful payment
- ✅ **Phone Number Protection** - Removed direct phone number exposure
  - No phone number displayed in app or web UI
  - All support routes exclusively through WhatsApp
  - Prevents users from calling directly to bypass payment
- ✅ **Production Deployments**
  - Flutter app: Compiled and running on device ✅
  - Web UI: Deployed to Firebase hosting ✅

## Recent Changes (Dec 16, 2025)

### ✅ Mark Session Complete Feature NEW
- ✅ `lib/screens/tech_reply_screen.dart` - Added complete button and function
  - Green "Complete" button in AppBar with checkmark icon
  - Confirmation dialog before marking complete
  - Updates Firestore: status=completed, completedAt, completedBy, completedByUid
  - Adds system message to chat history
  - Shows success snackbar and navigates back to chat list
- ✅ Matches web admin dashboard "Mark Complete" functionality
- ✅ Supports pay-per-issue business model

## Recent Changes (Dec 15, 2025)

### 📱 FCM Push Notifications ✅
- ✅ `lib/services/notification_service.dart` - Full FCM implementation
  - Token registration on login (saved to Firestore `users/{uid}.fcmToken`)
  - Foreground message display
  - Background message handling
  - Notification tap navigation
- ✅ Cloud Functions deployed:
  - `sendPushNotificationOnNewMessage` - Alerts admins when customer sends message
  - `sendPushNotificationOnAdminReply` - Alerts customer when admin replies
- ✅ Auto-cleanup of invalid FCM tokens

### 🎨 Gradient Theme Styling ✅ NEW
- ✅ `lib/widgets/gradient_scaffold.dart` - Reusable gradient components
  - `AppColors` - Consistent color constants (primaryCyan, primaryPurple, etc.)
  - `GradientScaffold` - Dark gradient background matching website
  - `GradientButton` - Styled buttons with gradient
  - `AppCard` - Consistent card styling
- ✅ Updated screens: welcome, main_navigation, chat to use gradient theme

### 🐛 Bug Fixes ✅
- ✅ Fixed RenderFlex overflow in admin_chat_detail_screen.dart
- ✅ Fixed setState() after dispose() in dispatch_screen.dart
- ✅ Fixed settings screen overflow (changed Row to Wrap for auto-reply hours)

### 🔄 Message Sync Fix ✅ NEW

---

## Production Readiness Checklist

### ✅ Completed
- [x] Paid support system with dynamic pricing
- [x] WhatsApp-only routing (no direct phone exposure)
- [x] Business hours logic (9-5 CST vs 24HR)
- [x] Transaction logging to Firestore
- [x] App-web feature parity
- [x] Stripe payment (web)
- [x] Firebase deployment
- [x] Android build configured
- [x] FCM push notifications
- [x] Mark session complete feature
- [x] Gradient theme styling
- [x] Password autofill support

### 🚀 Still Needed for Production
- [ ] **Test Stripe Payment Flow** (end-to-end with real card)
  - Verify payment → Firestore logging → WhatsApp open
  - Test card decline error handling
  - Verify transaction amounts are correct
- [ ] **Test WhatsApp Routing** (all channels)
  - Web on mobile browser
  - App on Android device
  - Verify messages pre-fill correctly
- [ ] **Business Hours Logic Validation**
  - Test pricing shows correctly at different times
  - Verify CST timezone accuracy
- [ ] **Firestore Security Rules Review**
  - Users can only view own transactions
  - Admins can view all transactions
- [ ] **Admin Transaction Dashboard** (to be built)
  - View all support transactions
  - Filter by date/user/type/status
  - Export functionality
  - Refund capability
- [ ] **Google Play Store Submission**
  - Screenshots (support system, chat, dispatch)
  - Privacy policy update
  - Test on multiple device types
- [ ] **Crash Reporting** (Firebase Crashlytics integration)
- [ ] **Monitoring & Alerting** (Cloud Function failures, payment errors)
- [ ] **User Documentation** (FAQ, support process)

---
- ✅ Admin chat screens now receive customer messages in real-time
  - Removed `orderBy('createdAt')` from Firestore queries (caused missing messages)
  - Manual sorting in Dart handles both `createdAt` and legacy `timestamp` fields
  - Auto-scroll to newest message when new messages arrive
- ✅ Updated screens: `admin_chat_detail_screen.dart`, `tech_reply_screen.dart`

### Previous Changes (Dec 14, 2025)

### Chat Fixes ✅
- ✅ Session status badge shows "Claimed by [Tech Name]" instead of generic "Claimed"
- ✅ Fixed admin messages not appearing in chat history
  - Added manual message sorting by `createdAt` or `timestamp` (handles both old and new messages)
  - Updated `chat_detail_screen.dart` to support legacy `timestamp` field
  - Admin messages now sync seamlessly from web UI to mobile app
- ✅ Updated Firestore rules to allow customers to read tech user profiles

### Previous Updates
- ✅ Admin dashboard with 6 tabs (Overview, Dispatch, Customers, Invoices, Pricebook, Settings)
- ✅ Password autofill support via `AutofillGroup` and `AutofillHints`
- ✅ Pricebook categories/items drilldown navigation
- ✅ Dark theme alignment (#1A1A1A background, #4EC7F3 accent)
- `android/app/build.gradle`: using `dev.flutter.flutter-gradle-plugin`; namespace fixed to `com.tekneckjoe.hvacsupport.hvac_support_app`.
- `android/app/src/main/res/values/colors.xml`: added `ic_launcher_background`.
- `lib/screens/dispatch_screen.dart`: `DateFormat` usage, filter chips, color API updated.

## Next
- ✅ Message sync verified - customer → admin messages now update in real-time
- Verify install on SM S931U and full chat flow testing
- Begin Phase 1: CRM separation (new Firebase project, data migration).

---

## 🚀 Quick Commands (Idiot Notes)

### Flutter Not Found?
```bash
# One-liner to run app (temp fix)
export PATH="$HOME/flutter/bin:$PATH" && flutter run

# Permanent fix - add to shell config
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

### Run the App
```bash
cd "/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app"
flutter run                    # Debug on connected device
flutter run --release          # Release build (faster)
flutter devices                # List connected devices
```

### Build APK
```bash
flutter build apk --release    # Creates build/app/outputs/flutter-apk/app-release.apk
flutter build apk --debug      # Debug APK for testing
flutter install                # Install APK to connected device
```

### Clean Build (Fix Weird Errors)
```bash
flutter clean && flutter pub get && flutter run
```

### Check for Issues
```bash
flutter analyze                # Lint check
flutter doctor                 # Environment check
flutter pub outdated           # Check for package updates
```

### Git Commands
```bash
git status                     # See what changed
git add -A && git commit -m "message" && git push   # Quick commit+push
git pull                       # Get latest from GitHub
```

### ADB (Android Debug Bridge)
```bash
adb devices                    # List connected Android devices
adb logcat | grep flutter      # View Flutter logs
adb install app-release.apk   # Install APK manually
adb shell pm clear com.tekneckjoe.hvacsupport.hvac_support_app  # Clear app data
```

### BLE Debugging
```bash
# Enable HCI snoop log (for protocol analysis)
adb shell settings put global bluetooth_hci_log 1
adb shell setprop persist.bluetooth.btsnoopenable true

# Pull bugreport with BLE logs
adb bugreport bugreport_$(date +%Y%m%d_%H%M%S).zip
```
