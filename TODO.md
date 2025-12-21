# TekNeck HVAC Support App — To Do List

## � GitHub & Firebase Integration

- **Repo**: [joeschmoe687/hvac_support_app](https://github.com/joeschmoe687/hvac_support_app) (private)
- **Firebase Project**: `tekneck-support` (shared with AirPro website)
- **Website Repo**: `airpro-website` (same workspace)
- See [README.md](README.md) for full integration documentation

---

## 🚩 Current Focus: TekTool - Universal HVAC Bluetooth Hub

---

### 🔴 Fieldpiece BLE Discovery (Dec 19, 2025) - BROADCAST ONLY
- [x] **BLE Sniffer Capture** - Captured packets from Fieldpiece Pressure/Temp/Psychrometer/DMM
- [x] **Manufacturer ID**: `0x5046` (20550 decimal) = "FP" ASCII = Fieldpiece
- [x] **Protocol Analysis** - Devices use ADV_NONCONN_IND (`eventType=0x10`) - **NON-CONNECTABLE**
- [x] **GATT Connection Failure** - `GATT_CONNECTION_TIMEOUT` (status 147) is EXPECTED behavior
- [x] **Documentation** - See [FIELDPIECE_PROTOCOL_ANALYSIS.md](docs/BLE-Sniffing/FIELDPIECE_PROTOCOL_ANALYSIS.md)
- [x] **UI Update** - BLE Sniffer now shows "Broadcast-only" warning for Fieldpiece devices
- [x] **Connect Button Disabled** - Grayed out for non-connectable devices
- [ ] **Read advertisement data** - Parse manufacturer_data from advertisements (measurement values encoded)
- [ ] **Manufacturer data format** - Bytes 11 and 17 appear to contain measurement data (need more captures)
- [ ] **Passive monitoring mode** - Show Fieldpiece readings without GATT connection (scan-only)

---

### ✅ ABM-200 Airflow Meter BLE Protocol (Dec 19, 2025)
- [x] **BLE Protocol Capture** - Captured via TekTool in-app sniffer
- [x] **HCI Snoop Log Analysis** - Verified byte mapping via CPS Link app comparison
- [x] **Manufacturer:** WeatherFlow (AAB/CPS branded)
- [x] **Model:** ABM-200 (Airflow, Temp, Humidity, Pressure meter)
- [x] **Primary Data Service:** `961f0001-d2d6-43e3-a417-3bb8217e0e01`
- [x] **Live Data Characteristic:** `961f0005-d2d6-43e3-a417-3bb8217e0e01` (notify, ~10Hz)
- [x] **Data Format** (14-byte packets, VERIFIED via HCI snoop analysis):
  - Bytes 0-1: Airflow velocity (uint16 LE, direct FPM) ✓
  - Bytes 2-5: Unknown (garbage when velocity > 0)
  - Bytes 6-7: Unknown
  - Bytes 8-9: Humidity (uint16 LE ÷ 5.29 = %RH) ✓
  - Bytes 10-11: Temperature (uint16 LE × 1.6 = °F) ✓
  - Bytes 12-13: Pressure (uint16 LE × 0.0401463 = in/WC) ✓
- [x] **Device Info Characteristics (180a):**
  - `2a29`: Manufacturer = "WeatherFlow"
  - `2a24`: Model = "ABM-200"
  - `2a26`: Firmware = "9"
  - `2a27`: Hardware = "r1"
  - `2a28`: Software = "ca652e"
- [x] **Battery:** Service 180f, char 2a19 (100% in capture)
- [x] **Firebase Cloud Sync** - Sniff data syncs to `ble_sniff_logs` collection
- [x] **Implement DeviceProfile** - Created `abm_200` profile + `_parseAbm200()` in device_registry.dart ✓
- [x] **Airflow Screen UI** - Created airflow_screen.dart with full multi-sensor display ✓
  - Wired up to tools_hub_screen.dart navigation ✓
  - Added rawData to DeviceReading class ✓
  - Parses all 4 sensors: Velocity (FPM), Temp (°F), Humidity (%RH), Pressure ✓
  - Navigation from Devices screen to Airflow screen when tapping connected meter ✓
- [x] **HCI Snoop Commands Documented** - See `docs/BLE-Sniffing/README.md`

---

### ⏸️ iOS Build (Tabled Dec 18, 2025)
- [ ] **Enable Developer Mode** - iPhone requires Settings → Privacy & Security → Developer Mode
- [ ] **First iOS test run** - Xcode signing configured, needs device restart with dev mode enabled
- Note: Android build works fine, iOS tabled until needed

---

### ✅ SMS Auto-Responder (Dec 18, 2025)
- [x] **Native Android SMS BroadcastReceiver** - Intercepts incoming SMS without third-party packages
- [x] **SmsReceiver.kt** - Kotlin receiver with 1-hour cooldown per phone number
- [x] **MainActivity.kt** - MethodChannel bridge between Flutter and native Android
- [x] **Auto-Reply Hours** - Configurable business hours (replies OUTSIDE these hours)
- [x] **Custom Reply Text** - Editable auto-reply message in Settings
- [x] **Permission Request UI** - Grant SMS permissions with visual status indicator
- [x] **Send Test SMS** - Test button to verify functionality (defaults to 4796010711)
- [x] **Admin-Only** - Only visible for admin/tech roles
- [x] **Reply Counter** - Tracks total auto-replies sent
- [x] **No Firebase Required** - Works offline using native Android SMS


### ✅ Wey-Tek HD Scale BLE Protocol (Dec 18, 2025)
- [x] **BLE Protocol Reverse Engineering** - Captured via HCI snoop log
- [x] **Service UUID**: `E3B744F3-4309-4A3A-B877-CCACD9EFB97D`
- [x] **Data Characteristic**: Handle 0x0111 (single characteristic for read/write/notify)
- [x] **Init Sequence** (3 commands after enabling notifications):
  - Link: `aa aa aa aa 4c 00 00 00 00 00 00 4c 00`
  - Ack:  `aa aa aa aa 41 00 00 00 00 00 00 41 00`
  - Init: `aa aa aa aa 49 00 00 00 00 00 00 49 00`
- [x] **Data Format** (13-byte weight packets):
  - Bytes 0-3: `aa aa aa aa` (header)
  - Byte 4: Command (`0x57` = weight data, `0x5A` = tare response)
  - Byte 5: Flags (`0x02` = stable, `0x03` = settling)
  - Bytes 6-9: Weight (int32 LE, value in **grams** → divide by 28.3495 for oz)
  - Byte 10: Unit indicator (0x00=lb, 0x01=lb:oz, 0x02=kg, 0x03=oz)
  - Bytes 11-12: Checksum/status
- [x] **Tare Command**: `aa aa aa aa 4f 00 00 00 00 00 00 4f 00`
- [x] **Parsing Implementation** - Added to `device_registry.dart`
- [x] **Device Detection** - Added to `device_data_service.dart`
- [x] **Weight Parsing Fix** - Corrected grams→oz conversion (÷28.3495 not ÷1000) ✅ Tested 7oz accurate

### ✅ Testo Smart Probe BLE Protocol (Dec 18, 2025)
- [x] **BLE Protocol Reverse Engineering** - Captured Testo app's exact init sequence via HCI snoop log
- [x] **Device Init Commands** - Exact byte sequences with CRCs implemented:
  - Handshake: `56 00 03 00 00 00 0c 69 02 3e 81`
  - Start streaming: `20 01 00 00 00 00 3a bb`
  - Measurement requests: `11 03 00 00 00 00 47 5a`, `11 04 00 00 00 00 f2 9a`
- [x] **Independent Probe Operation** - Probes now stream data without requiring Testo app pre-priming
- [x] **Temperature Parsing** - T115i clamp probes reading accurately (68.8°F)
- [x] **Pressure Parsing** - T549i differential probe Int16/100 format (raw 20 = 0.2 PSI) ✅
- [x] **Unit Conversion** - mbar → PSI conversion (1 mbar = 0.0145038 psi)
- [x] **Sensor Assignment** - Tap pressure/temp windows to assign sensors to Hi/Low side or Suction/Liquid line
- [x] **Auto-Switch Logic** - When tapping a slot and selecting an already-assigned sensor, it auto-moves to new slot and clears old slot display
- [x] **Zero Sensor** - "Zero Sensor" button in pressure window picker stores offset and zeroes display
- [x] **Pressure Display** - Low/High side PSI with saturation temps from PT chart
- [x] **Gauge Screen Direct Connection** - Connect probes directly from gauge slot picker (Dec 18) ✅

### ⚠️ CRITICAL: BLE Connection Architecture (DO NOT BREAK)
**File: `lib/tools/services/auto_reconnect_service.dart`**

The `markConnected()` method MUST emit `ReconnectStatus.connected` for data subscriptions to work:
```dart
void markConnected(String remoteId, ble.BluetoothDevice device) {
  _connectedDeviceIds.add(remoteId);
  _pendingReconnects.remove(remoteId);
  _monitorDevice(device);
  // THIS LINE IS CRITICAL - DeviceDataService listens for this event!
  _reconnectStatusController.add(ReconnectStatus(
    state: ReconnectState.connected,
    message: 'Connected to ${device.platformName}',
    deviceId: remoteId,
  ));
}
```
**Why:** `DeviceDataService._subscribeToDevice()` is only triggered by `ReconnectState.connected` events.
Without the status emit, BLE connects but no data subscription → "Waiting for probe data..." forever.

**Connection Flow:**
1. Gauge screen → Sensor picker → Tap device to connect
2. `_SensorPickerSheet._connectAndAssign()` calls `bleService.connectToDevice()`
3. Then calls `reconnectService.markConnected(deviceId, device)` ← MUST emit status
4. `DeviceDataService` receives `ReconnectState.connected` event
5. `_subscribeToDevice()` discovers services, finds fff2 notify characteristic
6. Sends Testo init commands to wake probe (handshake/stream/measurement)
7. Probe starts streaming data → readings appear on gauge screen

### 🔧 TekTool Remaining BLE Tasks
- [x] **Scale Unit Selection** - Auto/oz/lb:oz/kg with auto-switch at 32oz (Dec 18) ✅
- [x] **Scale Tare/Zero** - Sends 0x4F command to zero scale (Dec 18) ✅
- [x] **Scale Connection Reliability** - Added retry logic with exponential backoff (1s, 2s, 4s) + GATT cache clear for Android 133 errors
- [x] **Scale Data Streaming** - Verified working (Dec 18) - 0.0 oz readings streaming at ~1Hz
- [x] **Battery level parsing** - Parses "BatteryLevel" packets from Testo probes, streams to UI (Dec 18) ✅
- [x] **Battery display on gauge screen** - Shows battery icon + percentage next to assigned pressure/temp sensors (Dec 18) ✅
- [x] **Scale auto-scan** - Automatically scans for Wey-Tek scales when scale screen opens (Dec 18) ✅
- [x] **Scale battery display** - Wey-Tek battery from Init response (0x49 byte 6, BCD encoded) shown on scale screen (Dec 18) ✅
- [x] **In-app BLE Discovery Mode** - Admin-only BLE Sniffer accessible from TekTool devices screen (Dec 18) ✅
  - Full GATT tree explorer with service/characteristic discovery
  - Read/Write/Notify operations with hex input
  - Data interpreter (int16, uint16, float32, ÷10, ÷100 formats)
  - Auto-scroll log with timestamps and color-coded entries
  - Profile generator: Creates DeviceProfile code templates for new devices
  - Export log to clipboard
- [x] **BLE Sniffer Auto-Subscribe** - Automatically subscribes to ALL notify/indicate characteristics on connect (Dec 19) ✅
- [x] **BLE Sniffer Auto-Read** - Automatically reads ALL readable characteristics on connect (Dec 19) ✅
- [x] **BLE Sniffer Cloud Sync** - Syncs captured data to Firebase `ble_sniff_logs` collection (Dec 19) ✅
- [x] **BLE Sniffer Local Persistence** - Auto-saves sessions to Hive local storage (Dec 19) ✅
- [x] **BLE Sniffer Session History** - View, load, delete, and sync past sessions (Dec 19) ✅
- [x] **BLE Sniffer Device Detection** - Manufacturer name from Bluetooth Company IDs, HVAC tool type guessing (Dec 19) ✅
- [x] **Tap-to-Calibrate** - Tap any reading to show calibration popup with ±offset adjustment (Dec 19) ✅
  - CalibrationService stores offsets in SharedPreferences
  - CalibrationPopup widget with up/down arrows and save/reset buttons
  - Implemented on Airflow Screen: velocity, temperature, humidity (NOT pressure - barometric)
  - NOT on scales/pressure gauges - they have hardware zero that works correctly
- [x] **Test zero offset persistence** - Verified offsets survive app restart (CalibrationService initialized in main.dart)
- [x] **Add calibration to Gauge Screen** - R22 confirmation dialog added for R22/drop-in refrigerant selection
- [ ] **High-pressure probe support** - T549i can be ±60 bar for high-side manifold use
- [ ] **Connection stability** - LINK_SUPERVISION_TIMEOUT causing T549i disconnects during extended use
- [ ] **Fix RenderFlex overflow** - Varies by orientation: 15px bottom (landscape), 57px bottom (portrait gauge), 2.5px right (scan)

---

## 🚀 MAJOR: Guided Job Workflow (Commissioning & Service Calls)

> **Goal:** Walk any technician (even beginners) through proper HVAC troubleshooting and commissioning with step-by-step prompts, automated data collection, and AI-assisted guidance.

### ✅ Foundation (Dec 21, 2025)
- [x] **Job Data Models** - Job, Equipment, JobStep models with Firestore integration
- [x] **Job Service** - Create, update, complete jobs and manage workflow steps
- [x] **Location Service** - GPS location and geocoding for job sites
- [x] **Workflow Screen** - Step-by-step progress indicator and navigation
- [x] **Floating Action Button** - "Start Job" button for techs and admins

### Phase 1: Job Launch Flow
- [x] **Post-Login Job Prompt** - Job launch screen with "Commissioning" or "Service Call" selection
- [x] **Location Permission on First Login** - Location service requests permission on first use
- [x] **Auto-Detect Job Location** - GPS-based location capture with manual edit option
- [x] **Customer/Location Name** - Customer info step prompts for name after location
- [x] **Job Type Branch:**
  - Service Call → Simplified flow to diagnostics with TekTool
  - Commissioning → Full workflow with equipment discovery

### Phase 2: Equipment Discovery (Commissioning)
- [x] **System Type Selection** - AC or Heat Pump selection step
- [x] **Camera Permission Request** - Camera permission requested in nameplate scan step
- [x] **Nameplate OCR Scanning** - Camera integration with manual entry fallback
  - Manual entry: Brand, Model, Serial
  - OCR integration placeholder (needs google_mlkit_text_recognition implementation)
- [x] **Split System Detection** - Equipment model supports multiple unit types (condenser, evaporator, air handler, furnace)
- [ ] **AHRI Lookup** - Match equipment combination to AHRI database (future enhancement)
- [ ] **Install Manual Fetching** - Find and parse manufacturer install docs (future enhancement)

### Phase 3: System Startup & Diagnostics
- [x] **Mode Selection** - AC or Heat mode selection step
- [x] **Gauge/Probe Connection** - Gauge connection step with instructions and device manager integration
- [x] **Stabilization Timer** - 20-minute countdown timer with visual indicator
  - Skip with warning option
  - Tips displayed during wait time
- [x] **Amp Draw Prompts:**
  - Blower motor amp draw (measured)
  - Condenser fan motor amp draw (measured)
  - Compressor amp draw (measured)
  - Skip option available
- [x] **Diagnostics Step** - Integration with TekTool for live gauge readings

### Phase 4: Interactive Gauge Guidance
- [x] **TekTool Integration** - Diagnostics step links to existing Tools Hub
- [ ] **Target Pressures Display** - Calculate and show target pressures (future enhancement)
- [ ] **Superheat/Subcool Targets** - Enhanced display with target comparison (future enhancement)
- [ ] **Refrigerant Guidance** - Real-time adjustment prompts (future enhancement)
- [ ] **AI Troubleshooting** - Context-aware diagnostic suggestions (future enhancement)

### Phase 5: Beginner Mode (AI Hand-Holding)
- [ ] **Zero-Knowledge Friendly** - Enhanced explanations and help text (future enhancement)
- [ ] **Aggressive Image Analysis** - AI verification of photos (future enhancement)
- [ ] **Plain English Explanations** - Tooltips and expanded descriptions (future enhancement)
- [ ] **Error Prevention** - Smart warnings and validations (future enhancement)

### Phase 6: Admin Customization
- [ ] **Web UI Config** - admin_dashboard.html Settings tab (future enhancement)
- [ ] **Mobile Admin Config** - App-based workflow configuration (future enhancement)
- [ ] **Step Templates** - Reusable commissioning checklists (future enhancement)
- [ ] **Per-Equipment Overrides** - Custom steps for specific brands/models (future enhancement)

### ✅ TekTool Core Infrastructure (Dec 18, 2025)
- [x] **BluetoothService** - Singleton BLE manager (`lib/bluetooth/bluetooth_service.dart`)
  - Scan, connect, disconnect, GATT discovery
  - Characteristic read/notify subscriptions
  - Connection state monitoring
- [x] **DeviceRegistry** - Known HVAC device profiles (`lib/tools/services/device_registry.dart`)
  - Weytek scale, CCS airflow, Testo temp/pressure probes
  - Placeholder UUIDs (needs BLE sniffing to get real values)
  - Device identification by service UUID or name pattern
- [x] **P/T Chart** - Full saturation tables (`lib/tools/utils/pt_chart.dart`)
  - R22, R410A, R407C, Nu-22, R32, R454B
  - Superheat/subcool calculations
  - Target superheat for fixed orifice
- [x] **RefrigerantDetector** - Auto-detect from pressure readings
  - R22 always prompts for confirmation (drop-in check)
  - R410A auto-sets from OCR nameplate
  - Confidence scoring with alternates
- [x] **GaugeZeroService** - Smart zero prompt logic
  - Only prompts when gauges show ~0 psig
  - Skips if pressure detected (BLE reconnect mid-job)

### ✅ TekTool Screens (Dec 18, 2025)
- [x] **Tools Hub Screen** (`lib/tools/screens/tools_hub_screen.dart`)
  - Live readings display (superheat/subcool)
  - Refrigerant picker (6 refrigerants)
  - Connected devices grid
  - Empty state with scan button
  - Support chat button
- [x] **Devices Screen** (`lib/tools/screens/devices_screen.dart`)
  - List of connected/paired devices
  - Connection status + battery indicators
  - Swipe to forget device
  - Reconnect functionality
  - **Device persistence** - Saves to SharedPreferences on connect
  - **Auto-load** - Loads saved devices on screen open
- [x] **Device Scan Screen** (`lib/tools/screens/device_scan_screen.dart`)
  - Filtered BLE scan (named devices only)
  - Signal strength indicators
  - "SUPPORTED" badge for known HVAC tools
  - One-tap connect
- [x] **BLE Sniffer Screen** (`lib/tools/screens/ble_sniffer_screen.dart`) - Admin only
  - Full BLE debugging for reverse-engineering device protocols
  - GATT service/characteristic explorer
  - Read and Subscribe buttons
  - Console log with timestamps
  - Copy/export functionality
  - **Data Interpreter** - Parse raw bytes as int8/16/32, float, string
  - **Save Profile** - Export device config for production use
  - **Write Value** - Send hex values to characteristics
- [x] **Storage Screen** (`lib/tools/screens/storage_screen.dart`)
  - View saved devices, connection history, ML patterns, custom profiles
  - 4 tabs: Devices, History, ML, Profiles
  - Export profile code for production integration
  - Clear all data option
  - Accessible from Settings

### ✅ Device Persistence & Auto-Reconnect (Dec 18, 2025)
- [x] **DeviceStorageService** (`lib/tools/services/device_storage_service.dart`)
  - Save/load devices to SharedPreferences (JSON)
  - Connection event history logging
  - ML learned patterns storage
  - Custom device profiles storage
  - Storage stats (device count, history count, size)
- [x] **AutoReconnectService** (`lib/tools/services/auto_reconnect_service.dart`)
  - Background scanning every 30 seconds
  - Auto-reconnect when known devices power on
  - Connection state monitoring
  - Reconnect status stream for UI updates
- [x] **Settings → Storage** - Storage tile in settings navigates to StorageScreen
- [x] **Platform Name Fallback** - Devices reconnect via platformName if not in storage
- [x] **Disconnect Notifications** - SnackBar alerts on gauge/scale screens when devices connect/disconnect

### ✅ Navigation Updated (Dec 18, 2025)
- [x] **Tools tab** - ToolsHubScreen for all users
- [x] **Devices tab** - DevicesScreen for all users
- [x] **3-tab layout** for regular users (Tools, Devices, Settings)
- [x] **4-tab layout** for techs (Tools, Devices, Inbox, Settings)
- [x] **Admin** retains existing tabs + BLE Sniffer in Admin panel

### 🔧 TekTool Next Steps
- [x] **BLE Sniff Testo Probes** - Captured exact init protocol via Android HCI snoop log ✅
  - [x] T115i temperature clamp - Working independently
  - [x] T549i differential pressure probe - Working independently
- [ ] **BLE Sniff Other Devices** - Use sniffer to capture actual UUIDs from:
  - [ ] Weytek refrigerant scale
  - [ ] CCS airflow meter
- [ ] **Update DeviceRegistry** - Replace placeholder UUIDs with real ones (non-Testo devices)
- [x] **Device Persistence** - Save device pairings with SharedPreferences ✅
  - [x] Store saved devices in JSON
  - [x] Store connection history
  - [x] Store ML learned patterns
  - [x] Store custom device profiles
- [ ] **Persist Zero Offsets** - Save pressure zeroing to SharedPreferences (Already implemented - GaugeZeroService persists to SharedPreferences)
- [ ] **Foreground Service** - Persistent BLE when app backgrounded
  - [ ] Live readings in Android notification
  - [ ] Keep connections alive during multitasking
- [ ] **OCR Equipment Scanning** - Capture equipment nameplates
  - [ ] Camera integration with MLKit text recognition
  - [ ] Parse brand/model/serial/refrigerant
  - [ ] Auto-set refrigerant from nameplate
- [ ] **Job Profile System** - Location + multi-unit support
  - [ ] GPS auto-detect job location
  - [ ] Equipment name auto-suggest
  - [ ] Save readings per unit
- [x] **Zero Prompt Integration** - Zero button in sensor picker ✅
- [x] **R22 Confirmation** - Show RefrigerantConfirmDialog when R22 or drop-in refrigerant selected (Dec 21) ✅
- [ ] **Device Detail Screen** - Expanded device info + calibration

---

## ✅ Payment System Implementation (Dec 21, 2025)
- [x] **Native Stripe Integration** - Replaced external web checkout with Flutter Stripe SDK
- [x] **Google Pay Integration** - One-tap checkout with Google Wallet/Google Pay
- [x] **Camera Card Scanning** - Secure ML-based card scanning using device camera
- [x] **PaymentService** - Centralized payment logic with proper error handling
- [x] **PaymentScreen** - Native payment UI with multiple payment methods
- [x] **Cloud Functions** - Server-side payment intent creation for security
- [x] **Transaction Logging** - All payments logged to Firestore with audit trail
- [x] **PCI Compliance** - Card data handled exclusively by Stripe SDK
- [x] **Test Mode Support** - Automatic test/live mode detection
- [x] **Documentation** - Complete setup guide and technical docs (PAYMENT_SETUP.md, QUICKSTART.md)
- [x] **Unit Tests** - PaymentService test coverage
- [x] **PaymentVerificationScreen** - Developer utility for testing setup

---

## ✅ Guided Job Workflow Implementation (Dec 21, 2025)
- [x] **Job Data Models** - Job, Equipment, JobStep models with Firestore integration
- [x] **JobService** - Complete CRUD operations and workflow management
- [x] **LocationService** - GPS location detection, geocoding, and address lookup
- [x] **JobLaunchScreen** - Entry point with Commissioning/Service Call selection
- [x] **JobWorkflowScreen** - Step-by-step orchestration with progress tracking
- [x] **Location Step** - GPS auto-detect with manual entry fallback
- [x] **Customer Info Step** - Customer name entry with validation
- [x] **System Type Step** - AC/Heat Pump selection
- [x] **Nameplate Scan Step** - Camera integration with manual entry fallback
- [x] **Mode Selection Step** - AC/Heat mode selection
- [x] **Gauge Connection Step** - Instructions and device manager integration
- [x] **Stabilization Timer** - 20-minute countdown with skip option and tips
- [x] **Amp Draw Step** - Motor amperage measurements with skip options
- [x] **Diagnostics Step** - TekTool integration for live gauge readings
- [x] **Completion Step** - Final notes and job completion
- [x] **Floating Action Button** - Quick job launch from main navigation
- [x] **Firestore Sync** - Real-time job persistence
- [x] **Camera Permissions** - Permission handling with user prompts
- [x] **Location Permissions** - GPS permission requests on first use

---

## 🚩 Previous Focus: Production Release & Paid Support System

---

### ✅ Paid Support System Implementation (Dec 17, 2025)
- [x] **Support Contact Screen** - New dedicated screen with phone/video options
- [x] **Dynamic Pricing** - Fetches from Firestore settings/pricing (Business Hours vs 24HR)
- [x] **WhatsApp-Only Routing** - All support channels (phone, video, text) route through WhatsApp Business
- [x] **Phone Number Hidden** - Removed direct phone number to prevent payment bypass
- [x] **Price Display** - Shows live pricing on support cards (Message/Phone/Video with time-based rates)
- [x] **Transaction Logging** - Logs to Firestore with userId, type, amount, timestamp
- [x] **CST Business Hours Detection** - Automatic detection on both web and app (9-5 CST Mon-Fri)
- [x] **App-Web Parity** - Support options identical on Flutter app and web UI
- [x] **Stripe Payment Integration** (web) - Payment modal with card entry, success logging, channel open
- [x] **SMS → WhatsApp Migration** - All SMS redirects to WhatsApp to avoid payment bypass

### ✅ Mark Session Complete Feature (Dec 16, 2025)
- [x] **Complete button in AppBar** - Green "Complete" button with checkmark icon
- [x] **Confirmation dialog** - Warns that customer needs to pay for next session
- [x] **Firestore update** - Sets status=completed, completedAt, completedBy, completedByUid
- [x] **System message** - Adds completion message to chat history
- [x] **Auto-navigate** - Returns to chat list after marking complete
- [x] **Success feedback** - Shows green snackbar confirmation

### 🔥 Priority 1: Production Readiness - Paid Support System
- [ ] **Test Stripe Payment Flow** - End-to-end test with real card (web only)
  - [ ] Initiate payment → Stripe modal → card entry → confirm → WhatsApp open
  - [ ] Verify transaction logged to Firestore with correct amount
  - [ ] Verify admin sees transaction in transaction logs
- [ ] **Test WhatsApp Routing** - Confirm all channels (text/phone/video) open WhatsApp
  - [ ] Web: Test on mobile browser (triggers native WhatsApp)
  - [ ] App: Test on Android device (uri_launcher opens WhatsApp)
  - [ ] Verify message pre-fills correctly based on support type selected
- [ ] **Test Business Hours Logic**
  - [ ] Verify correct pricing shows 9-5 CST Mon-Fri (business hours)
  - [ ] Verify correct pricing shows off-hours (24HR rates)
  - [ ] Test timezone accuracy across different device timezones
- [ ] **Test Price Updates** - Change pricing in Firestore and verify live update in both web/app
- [ ] **Verify No Phone Number Exposure** - Confirm phone number not visible anywhere in app/web
- [ ] **Test Payment Decline Flow** - What happens when card is declined? (error handling)
- [ ] **Admin Transaction Dashboard** - Build admin interface to view all support transactions
  - [ ] Filter by date, user, type, status
  - [ ] Export transactions (CSV)
  - [ ] Refund capability if needed

### 📱 Push Notifications (Dec 15, 2025) ✅
- [x] FCM client-side setup (`notification_service.dart`)
- [x] Token registration on user login
- [x] Foreground/background message handlers
- [x] Cloud Functions: `sendPushNotificationOnNewMessage` (admin alerts)
- [x] Cloud Functions: `sendPushNotificationOnAdminReply` (customer alerts)
- [ ] Test end-to-end push flow

### 📦 Production Deployment Checklist
- [ ] **Stripe Webhook Setup** - Configure webhook for payment confirmations (if needed)
- [ ] **Firestore Backup** - Enable automated backups in Firebase Console
- [ ] **Cloud Function Monitoring** - Set up alerts for payment function failures
- [ ] **Transaction Logging Audit** - Verify all transactions are being logged correctly
- [ ] **Security Rules** - Review Firestore rules for supportTransactions collection
  - [ ] Ensure users can only see their own transactions
  - [ ] Ensure admins can see all transactions
- [ ] **Web UI Deployment** - Already live at tekneck-support.web.app ✅
- [ ] **App Store Submission** - Build release APK and submit to Google Play Store
  - [ ] Screenshots showcasing support system
  - [ ] Privacy policy (payment data handling)
  - [ ] Support email in app settings
  - [ ] TestFlight beta first for user testing

### 1. Admin Dashboard Improvements
- [x] Mobile admin UI parity with web `admin_dashboard.html` (theme + functions)
  - [x] Overview stats (Jobs Today, Open Invoices)
  - [x] Customers tab with search
  - [x] Invoices tab with status badges
  - [x] Pricebook categories and items drilldown
  - [x] Settings toggles for admin preferences
  - [x] Role-based Admin tab visibility
- [x] Password autofill support (Samsung Pass, Google, NordPass, etc.)
- [ ] Add bulk job assignment and tech approval actions
- [ ] Integrate analytics (job completion rates, response times)
- [ ] Export data (CSV, PDF)
- [ ] Role management (promote/demote techs)
- [ ] View all support threads, jobs, and message logs


### 🚀 Nameplate Upload & ML-Driven Guide Sourcing
- [ ] **Nameplate Upload in Chat**
  - Enable paperclip/upload button in chat at any time
  - Allow users to upload nameplate photos (JPG/PNG)
- [ ] **Backend OCR Integration**
  - Use Firebase Function for OCR (Tesseract or similar)
  - Extract model, serial, brand, and other key fields from image
- [ ] **Data Parsing & Validation**
  - Parse OCR output for HVAC-specific fields
  - If extraction fails, prompt for manual entry
- [ ] **Guide Sourcing Logic**
  - Search official manufacturer sites and trusted sources for install guides
  - Log all fetch attempts and user feedback
- [ ] **ML-Driven Source Ranking**
  - Track source reliability, user ratings, and success rates
  - Use a simple ML model to rank and adapt source selection
  - Prefer official sources; fallback to others if needed
- [ ] **Feedback Loop**
  - Let users/techs rate or flag guides
  - Feed ratings into ML model for continuous improvement
- [ ] **Display Results**
  - Show extracted data and guide links in chat (user & tech/admin view)
  - Auto-fill or skip questionnaire if nameplate data is complete
- [ ] **Security & Privacy**
  - Securely store images and extracted data
  - Delete images after processing if not needed

#### Further Considerations
- Start with rule-based trust, layer ML as data grows
- Use open-source tools and libraries
- Prioritize top HVAC brands for initial guide sourcing

### 3. Privacy & Compliance (Dec 14, 2025)
- [WEB] Cookie consent banner and analytics gating now live (see web repo)
- [WEB] All analytics/trackers require explicit consent (GDPR/CCPA compliant)
- [WEB] DNT (Do Not Track) respected for analytics

### 4. Dispatch System Enhancements
- [x] Admins can assign jobs, mark complete

---

## 🛑 Do Not Touch
- welcome_screen.dart

---

## ✅ Next Steps
- Resolve Android build error: Kotlin cannot find FlutterActivity (tooling alignment done; re-run after cache cleanup)
- Verify mobile ↔ web Firestore sync for `jobDispatch`
- Verify mobile ↔ web Firestore sync for chats (`supportRooms`/`supportSessions`)
- Admin dashboard: bulk actions + CSV export
- Plan Phase 1 (CRM separation) kickoff: new Firebase project + data migration

---

## ℹ️ Build Status & Recent Fixes (Dec 15, 2025)
- ✅ Android builds successfully (AGP 8.1.1, Kotlin 1.8.22)
- ✅ Release APK signed: `build/app/outputs/flutter-apk/app-release.apk` (55MB)
- ✅ Release keystore: `android/app/upload-keystore.jks` (backed up!)
- ✅ **Website rebranded to TekNeck** - Modern dark theme, animated mesh gradient, new logo
- ✅ **Firebase deployed** - Live at airpronwa.com & tekneck-support.web.app
- ✅ Chat: "Claimed by [Tech Name]" display fixed
- ✅ Chat: All message history now shows (old + new admin messages)
- ✅ Firestore rules: Customers can read tech user profiles for display
- ✅ **Gradient theme styling** - Purple/cyan gradients matching website
- ✅ **RenderFlex overflow fixed** - Wrapped Row in Flexible
- ✅ **setState after dispose fixed** - Added mounted checks
- ✅ **FCM Push Notifications** - Full implementation complete
  - `lib/services/notification_service.dart` - Token management, handlers
  - Cloud Functions deployed for admin/customer push alerts
- ✅ **Message sync fix** - Admin screens now show customer messages in real-time
  - Removed `orderBy('createdAt')` to avoid missing messages with legacy `timestamp` field
  - Manual sorting in Dart handles both field names
  - Auto-scroll to newest message on update
- ✅ **Settings screen overflow fixed** - Changed Row to Wrap for auto-reply hours
- ⚠️ GoogleApiManager DEVELOPER_ERROR: Add SHA-1 fingerprint to Firebase console
- ⚠️ `flutter run` has path detection bug - APK builds but Flutter can't find it
- **Workaround:** Use manual install + attach:
	```bash
	adb install -r android/app/build/outputs/apk/debug/app-debug.apk
	adb shell am start -n com.tekneckjoe.tektool/.MainActivity
	flutter attach -d RFCY518ZA0Y
	```

---

> Update this file as features are completed or new priorities arise.
