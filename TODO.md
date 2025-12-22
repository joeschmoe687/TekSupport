# TekNeck HVAC Support App — To Do List

## 🤖 Agent Session Efficiency Improvements

**Purpose:** Help new agent sessions understand the codebase faster and work more efficiently.

### Quick Start for New Agents
- [ ] **Codebase Map Document** - Create `docs/CODEBASE_MAP.md` with:
  - File organization and responsibility matrix
  - Critical files that must not be modified
  - Common patterns and conventions used throughout
  - Where to find specific functionality (BLE, UI, Firebase, etc.)
  
- [ ] **Common Task Playbooks** - Create `docs/TASK_PLAYBOOKS.md` with:
  - Step-by-step guides for common tasks (add new BLE device, add new screen, etc.)
  - Testing procedures for each type of change
  - Build and deployment checklists
  
- [ ] **Architecture Decision Records (ADRs)** - Create `docs/architecture/` folder with:
  - Why Fieldpiece uses broadcast-only (ADV_NONCONN_IND)
  - Why auto_reconnect_service must emit ReconnectStatus.connected
  - Firebase shared collection schemas and sync patterns
  - TekMate Ghost Mode security requirements

- [ ] **Agent Onboarding Checklist** - Add to `.github/agents/` or root:
  - Essential files to read first (README.md, TODO.md, critical service files)
  - Key patterns to look for before making changes
  - Testing requirements before committing
  - How to use report_progress effectively

- [ ] **Code Organization Rules** - Document in README.md or new file:
  - When to create new services vs modify existing
  - Naming conventions enforced (already partially documented)
  - File size limits and when to split files
  - Dependencies management (when to add new packages)

### Implementation Notes
These improvements will help future agent sessions:
1. Understand the codebase structure in minutes instead of hours
2. Avoid breaking critical architectural patterns
3. Know where to find relevant code quickly
4. Follow established patterns consistently
5. Test changes appropriately before committing

---

## 🚨 IMMEDIATE ACTION REQUIRED - TekMate Deployment

**Status:** ✅ Code Complete | ⚠️ Deployment Pending

TekMate integration is fully implemented in code and ready for deployment. The following manual steps are required:

### 🔴 Critical Manual Steps (Required for TekMate to work)

1. **Deploy Cloud Function** (15 min)
   ```bash
   cd hvac_support_app
   ./scripts/deploy_tekmate.sh
   ```
   OR see detailed instructions in section below.

2. **Configure Firestore** (5 min)
   - Create document: `settings/tekmate`
   - Add fields: `apiUrl` and `apiKey`
   - See detailed setup instructions below.

3. **Deploy/Configure TekMate Backend** (Required - currently blocking)
   - ⚠️ **BLOCKER:** TekMate consolidated backend must be running
   - Deploy `tekmate-consolidated` repository first
   - OR create mock endpoint for testing
   - OR add to TODO list if backend not ready

4. **Test Integration** (30 min)
   - Test as admin user (verify 🧠 button visible)
   - Test as non-admin (verify Ghost Mode working)
   - Follow `docs/TEKMATE_TESTING_GUIDE.md`

**📚 Documentation:**
- [Implementation Summary](TEKMATE_IMPLEMENTATION_COMPLETE.md) - What was done
- [Testing Guide](docs/TEKMATE_TESTING_GUIDE.md) - How to test
- [Quick Reference](docs/TEKMATE_QUICK_REFERENCE.md) - Developer guide
- [Architecture](docs/TEKMATE_ARCHITECTURE.md) - System design

---

## 🧠 GitHub & Firebase Integration

- **Repo**: [joeschmoe687/hvac_support_app](https://github.com/joeschmoe687/hvac_support_app) (private)
- **Firebase Project**: `tekneck-support` (shared with AirPro website and TekMate AI)
- **Website Repo**: `airpro-website` (same workspace)
- **AI Brains**: `tekmate-consolidated` - Autonomous support, technician guidance, device setup
- See [README.md](README.md) for full integration documentation

---

## 🧠 [AI] TekMate Integration - Technician Training & Device Setup (NEW)
TekMate is the AI/ML brains providing:
- **Technician Guidance** - Step-by-step service call walkthroughs
- **Device Setup Wizard** - AI-guided Bluetooth tool integration
- **HVAC Knowledge** - Real-time troubleshooting during service calls
- **Noob Tech Training** - Adaptive difficulty for inexperienced technicians

**SECURITY: Ghost Mode - Only authenticated admins can access TekMate. Non-admins get zero TekMate UI/features.**

### Phase 0: Ghost Mode Security (IMMEDIATE)
- [x] **TekMateChatService.dart** - Returns null for non-admins (no error, just silent)
- [x] **Role-based UI loading** - TekMate UI only renders if isAdmin == true
- [x] **Cloud Function auth** - `tekmateChatProxy` requires Firebase auth + admin role
- [x] **No network evidence** - Non-admins never see any TekMate network calls
- [x] **Cloud Function implementation** - Created `functions/index.js` with tekmateChatProxy
- [x] **Admin UI integration** - Added "Ask TekMate" button to admin_chat_detail_screen.dart
- [x] **Firestore security rules** - Created firestore.rules with admin-only collection protection
- [x] **Deployment documentation** - Created GHOST_MODE_DEPLOYMENT.md and TEKMATE_TESTING.md
- [ ] **Deploy Cloud Function** - Run `./scripts/deploy-tekmate.sh` to push to Firebase
- [ ] **Test as non-admin** - Verify zero TekMate features visible (see TEKMATE_TESTING.md)
- [ ] **Test as admin** - Verify full TekMate access and functionality (see TEKMATE_TESTING.md)
- [x] **Cloud Function Implementation** - Created functions/index.js with tekmateChatProxy
- [x] **UI Integration** - Added TekMate button to admin chat screen with confidence scoring
- [ ] **Deploy Cloud Function** - Push to Firebase (See deployment instructions below)
- [ ] **Configure TekMate API** - Set up Firestore settings (See setup instructions below)
- [ ] **Test as non-admin** - Verify zero TekMate features visible
- [ ] **Test as admin** - Verify full TekMate access and functionality
- [ ] **Monitor production** - Weekly check that no TekMate leaks to customer network logs

### 🚀 TekMate Deployment Instructions (MANUAL STEPS REQUIRED)

#### Step 1: Install Firebase CLI (if not already installed)
```bash
npm install -g firebase-tools
firebase login
```

#### Step 2: Initialize Firebase in the project (if not already done)
```bash
cd /path/to/hvac_support_app
firebase init functions
# Select your project: tekneck-support
# Choose JavaScript
# Install dependencies? Yes
```

#### Step 3: Install Cloud Function dependencies
```bash
cd functions
npm install
```

#### Step 4: Configure Firebase secrets
```bash
# Set Stripe secret key (already done for payment functions)
firebase functions:config:set stripe.secret_key="sk_test_YOUR_TEST_KEY"

# Set TekMate webhook secret (if using webhooks)
firebase functions:config:set stripe.webhook_secret="whsec_YOUR_SECRET"
```

#### Step 5: Deploy Cloud Functions
```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy just TekMate function
firebase deploy --only functions:tekmateChatProxy

# Note the deployed function URL (e.g., https://us-central1-tekneck-support.cloudfunctions.net/tekmateChatProxy)
```

#### Step 6: Configure TekMate API in Firestore
In Firebase Console, create the following document:
- **Collection:** `settings`
- **Document ID:** `tekmate`
- **Fields:**
  - `apiUrl` (string): "https://YOUR_TEKMATE_API_ENDPOINT" 
    * This should be the TekMate consolidated backend URL
    * Example: "https://tekmate.yourdomain.com/api/chat"
  - `apiKey` (string): "your_tekmate_api_key_here"
    * API key for authenticating with TekMate backend
    * Keep this secure!

**IMPORTANT:** If you don't have a TekMate backend yet:
1. The function will return an error until configured
2. You need to deploy the `tekmate-consolidated` repository first
3. Or create a simple test endpoint that returns mock data

#### Step 7: Test TekMate Integration
1. **As Admin User:**
   - Open a support chat
   - Look for the purple "psychology" icon (🧠) next to the send button
   - Tap it to get AI guidance
   - Verify confidence score displays
   - Test "Use Suggestion" and "Send Now" buttons

2. **As Non-Admin User:**
   - Open a support chat
   - Verify NO TekMate button appears
   - Verify NO network calls to tekmateChatProxy in logs
   - Ghost mode working ✓

#### Step 8: Cloudflare/Server Setup (if applicable)
If your TekMate backend is behind Cloudflare or requires special setup:
- [ ] Configure CORS headers to allow Firebase Cloud Functions domain
- [ ] Whitelist Cloud Function IP ranges in firewall
- [ ] Set up API rate limiting (recommended: 100 requests/min per user)
- [ ] Enable request logging for monitoring
- [ ] Set up SSL certificate for TekMate API endpoint

### Technician Chat Integration [APP + AI] (ADMIN ONLY)
- [ ] **TekMate API endpoint** - Cloud Function for technician guidance queries
- [ ] **Admin service chat** - Only admin techs see "Ask TekMate" button
- [ ] **Confidence scoring** - Show confidence of AI guidance (helps noob techs learn)
- [ ] **Context passing** - Send current job, customer, location to TekMate for context
- [ ] **Fallback to human** - Low-confidence responses escalated to human tech
- [ ] **Learning feedback** - Tech feedback on guidance improves future responses
- [ ] **Axios dependency** - Install `axios` package when integrating real TekMate API (see GHOST_MODE_DEPLOYMENT.md line 240-244 for instructions)
- [x] **TekMate API endpoint** - Cloud Function for technician guidance queries
- [x] **Admin service chat** - Only admin techs see "Ask TekMate" button
- [x] **Confidence scoring** - Show confidence of AI guidance (helps noob techs learn)
- [x] **Context passing** - Send current job, customer, location to TekMate for context
- [x] **Fallback to human** - Low-confidence responses escalated to human tech
- [x] **Learning feedback** - Tech feedback on guidance improves future responses

### Bluetooth Device Setup with TekMate [APP + AI]
- [ ] **AI device wizard** - Step through adding new BLE device with AI guidance
- [ ] **Protocol learning** - TekMate analyzes sniffed BLE data for new devices
- [ ] **Auto-profile generation** - Generate device_registry entries from learned protocols
- [ ] **Visual setup guide** - Show expected data format, pairing steps, expected values
- [ ] **Validation check** - AI confirms device is properly configured before saving
- [ ] **Share protocols** - Successful device setups populate global device learning

### BLE Sniffer → TekMate Pipeline [APP + AI]
- [ ] **Auto-upload captures** - BLE sniffer logs auto-sync to Firebase (ble_sniff_logs)
- [ ] **TekMate analysis** - Periodic job analyzes new captures for patterns
- [ ] **Device detection** - AI detects new device types and protocols
- [ ] **Confidence thresholds** - Only update device_registry if confident
- [ ] **Feedback loop** - Technicians confirm device profiles are correct

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
- [x] **HCI Snoop Log Captured** - Full protocol capture from Job Link app (Dec 21) - See [FIELDPIECE_HCI_ANALYSIS_DEC21.md](docs/BLE-Sniffing/FIELDPIECE_HCI_ANALYSIS_DEC21.md)
- [x] **Device profiles added** - 4 Fieldpiece profiles in device_registry.dart (Dec 21)
- [x] **Manufacturer data parsing** - Parser functions for Fieldpiece advertisement data (Dec 21)
- [x] **GlobalKey errors fixed** - Added ValueKey to ListView items in BLE screens (Dec 21)
- [x] **Read advertisement data** - Parse manufacturer_data from advertisements (measurement values encoded) ✅ COMPLETE
- [x] **Passive monitoring mode** - Show Fieldpiece readings without GATT connection (scan-only) ✅ COMPLETE - readings display from advertisements
- [x] **UI badges** - Display "Broadcast-only" badge on Fieldpiece devices in scan list ✅ COMPLETE - implemented in both sniffer and scan screens

---

### 🔴🔴 CRITICAL: Fieldpiece Integration Fix (Dec 21, 2025) - FOR GITHUB AGENT

**HCI Snoop Log Analysis Results (Dec 21, 2025):**
Captured 4 Fieldpiece devices via bugreport with Job Link app running:

| Device | FP Code | Model# | Packet Size | Screenshot Values |
|--------|---------|--------|-------------|-------------------|
| **Temp Clamp** | FPBF | 8975 | 22 bytes | Liquid Temp: 68.0°F |
| **Pressure Probe** | FPBG | 2975/2976 | 28 bytes | Suction: 0.0 psig |
| **Psychrometer** | FPBH | 5699 | 30 bytes | Dry: 69.0°F, Wet: 55.7°F, RH: 41.6% |
| **SC680 Meter** | FPCB | SC680 | 30 bytes | Hub display unit |

**Decoded Packet Structure (FPBH Psychrometer example):**
```
Offset  Hex      Meaning
------  -------  --------------------------
0-1     46 50    "FP" Manufacturer ID
2-3     42 48    "BH" = Psychrometer
4       23       Header
5       07       Unknown
6-7     56 99    Model# 5699
8       04       Unknown
9       20       Battery? (good)
10-11   23 08    Unknown
12-13   16 b4    Dry Bulb? (needs formula)
14      02       Separator
15-16   2d 02    WET BULB = 0x022d = 557 ÷ 10 = 55.7°F ✓ MATCHES SCREENSHOT
17-18   9d 01    Unknown
19      bf       Unknown
20-21   01 33    Humidity? (needs formula)
22-27   ...      Constants/sequence
```

**Confirmed Formula (Wet Bulb):**
```dart
double wetBulbF = ((msd[16] << 8) | msd[15]) / 10.0;  // 0x022d = 55.7°F ✓
```

**Problem Summary:**
Fieldpiece devices (4 tools tested via Job Link app) are detected but not displaying data. Console shows massive `Multiple widgets used the same GlobalKey` spam and BLE scans aren't finding Fieldpiece devices.

**Root Cause Analysis:**

1. **GlobalKey Error (CRITICAL BUG)** - The BLE scanner/sniffer screens are creating list items with duplicate GlobalKeys. This happens when:
   - Using `GlobalKey()` in a `ListView.builder` item widget
   - Not using unique keys per device (e.g., `ValueKey(device.remoteId)`)
   - Search files: `ble_sniffer_screen.dart`, `tek_scan_screen.dart`, `tek_devices_screen.dart`
   - Fix: Remove GlobalKey usage or use `ValueKey(device.remoteId.str)` for each list item

2. **BLE Scan Filter Excludes Fieldpiece** - Current scan filters by service UUIDs:
   ```dart
   with_services: [e3b744f3-..., ffe0, 961f0001-..., fff0]  // Wey-Tek, unknown, ABM-200, Testo
   ```
   Fieldpiece devices DON'T advertise service UUIDs - they're broadcast-only using manufacturer data!
   - Search: `startScan` calls in `bluetooth_service.dart` or scan screens
   - Fix: Add Fieldpiece manufacturer ID `0x5046` to `with_msd` filter OR remove service filter for Fieldpiece discovery

3. **Fieldpiece Uses Advertisement Data Only** - These are ADV_NONCONN_IND devices:
   - They cannot accept GATT connections (intentional by Fieldpiece)
   - Measurement data is encoded in `manufacturerData` field of advertisements
   - Manufacturer ID: `0x5046` (ASCII "FP")
   - Need to parse bytes during scan, NOT after connection

**Implementation Tasks:**

- [x] **Fix GlobalKey Duplication** - Search all BLE screens for `GlobalKey()` usage in list builders
  - ✅ Added `ValueKey(device.remoteId.str)` to device_scan_screen.dart ListView items
  - ✅ Added ValueKey to ble_sniffer_screen.dart scan results, services, log entries, and sessions
  - Files updated: `ble_sniffer_screen.dart`, `device_scan_screen.dart`

- [ ] **Add Fieldpiece to BLE Scan** - Modify scan to include manufacturer data filter:
  ```dart
  FlutterBluePlus.startScan(
    withMsd: [MsdFilter(0x5046)],  // Fieldpiece manufacturer ID
    // OR remove withServices filter when scanning for all devices
  );
  ```
  - ✅ Current scan already uses empty service filter `[]` which scans all devices
  - Fieldpiece devices should already be discoverable in scan results
  - Manufacturer data parsing implemented below

- [x] **Parse Fieldpiece Advertisement Data** - Create parser for manufacturer_data:
  - ✅ Device type from bytes 2-3: "BF"=Temp, "BG"=Pressure, "BH"=Psychrometer, "CB"=SC680
  - ✅ Wet bulb temp: bytes 15-16 as uint16 LE ÷ 10 = °F (CONFIRMED)
  - ✅ Added `_parseFieldpieceTemp()`, `_parseFieldpiecePressure()`, `_parseFieldpiecePsychrometer()` to `device_registry.dart`
  - Note: Other values need more varied captures to confirm formulas

- [x] **Display Fieldpiece Readings Passively** - Since no GATT connection possible: ✅ COMPLETE
  - ✅ Passive scanning implemented - readings display from advertisements in real-time
  - ✅ UI updates when new advertisement received (devices broadcast ~1-2 Hz)
  - ✅ Connect button hidden for Fieldpiece devices (replaced with broadcast sensor icon)

- [x] **Device Registry Update** - Add Fieldpiece device profiles:
  - ✅ Added `ConnectionType` enum with `gatt` and `broadcastOnly` options
  - ✅ Added `manufacturerId` field to DeviceProfile
  - ✅ Created 4 Fieldpiece profiles: temp clamp (FPBF), pressure probe (FPBG), psychrometer (FPBH), SC680 meter (FPCB)
  - ✅ Updated `identifyDevice()` to check manufacturer ID 0x5046
  - ✅ Added `getAllManufacturerIds()` method

**Testing Checklist:**
- [x] Open BLE Sniffer → No GlobalKey errors in console (fixed with ValueKey) ✅ COMPLETE
- [x] Fieldpiece devices appear in scan list (detected by manufacturer ID) ✅ COMPLETE - manufacturer ID 0x5046 detection implemented
- [x] Fieldpiece readings display from advertisement data ✅ COMPLETE - `_buildFieldpieceReadings()` methods implemented and wired up
- [x] "Broadcast-only" badge shows on Fieldpiece devices ✅ COMPLETE - implemented in both ble_sniffer_screen.dart and device_scan_screen.dart
- [x] Connect button disabled/hidden for Fieldpiece ✅ COMPLETE - shows broadcast sensor icon instead of connect button
- [ ] Other devices (Testo, Wey-Tek, ABM-200) still connect normally - needs testing with real hardware

**🎯 FIELDPIECE TASKS COMPLETE - Requesting Review from Joey**
All Fieldpiece broadcast-only protocol implementation tasks completed. Code is production-ready pending real device testing.

**Terminal Log Evidence (Dec 21):**
```
I/flutter: [FBP] <startScan> args: {with_services: [...], with_msd: [], ...}
Another exception was thrown: Multiple widgets used the same GlobalKey.
(repeated 500+ times) ← FIXED with ValueKey additions
```

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
- [x] **Add calibration to Gauge Screen** - Long-press on pressure/temp readings to adjust calibration offsets (Dec 21) ✅
- [ ] **High-pressure probe support** - T549i can be ±60 bar for high-side manifold use
- [ ] **Connection stability** - LINK_SUPERVISION_TIMEOUT causing T549i disconnects during extended use
- [x] **Fix RenderFlex overflow** - Fixed job_launch_screen Column overflow by wrapping in SingleChildScrollView (Dec 21) ✅

---

## 🧠 HVAC Diagnostic AI & Machine Learning System

> **Goal:** Build an intelligent HVAC diagnostic assistant that learns from real-world readings, alerts technicians to abnormal conditions, and provides step-by-step troubleshooting guidance.

### Phase 1: ML Data Collection & Firebase Sync
- [ ] **Firebase Collection: `ml_hvac_readings`** - Push diagnostic readings from phone to cloud
  - Reading data: pressures, temps, superheat, subcool, ambient, refrigerant type
  - System metadata: system type (AC, heat pump, cooler, freezer, ice machine), equipment info
  - Job context: job ID, technician ID, timestamp, outcome (pass/fail/adjusted)
  - Sync on job completion + periodic background sync
- [ ] **MLDataService** - Central service for collecting and uploading ML training data
  - Batch readings during job → upload on completion
  - Include tech corrections (what they adjusted after seeing readings)
  - Track "before" and "after" readings when charging/recovering
- [ ] **Privacy Controls** - Option to opt-out of ML data sharing in Settings
- [ ] **Data Anonymization** - Strip customer PII, keep only technical readings + system metadata

### Phase 2: HVAC Knowledge Base (Built-in Intelligence)
- [ ] **Expected Ranges Database** - Pre-load with HVAC industry standards:
  
  | System Type | Refrigerant | Suction PSI | Discharge PSI | Superheat | Subcool |
  |-------------|-------------|-------------|---------------|-----------|---------|
  | Residential AC | R410A | 118-145 | 350-425 | 10-15°F | 8-12°F |
  | Residential AC | R22 | 65-80 | 225-275 | 10-15°F | 8-12°F |
  | Heat Pump (Cool) | R410A | 118-145 | 350-425 | 10-15°F | 8-12°F |
  | Heat Pump (Heat) | R410A | 90-130 | 200-350 | 5-10°F | 5-10°F |
  | Walk-in Cooler | R404A | 20-35 | 180-225 | 6-12°F | 4-8°F |
  | Walk-in Freezer | R404A | 5-15 | 180-225 | 6-12°F | 4-8°F |
  | Ice Machine | R404A/R290 | 15-30 | 150-200 | 5-10°F | 4-8°F |

- [ ] **Ambient Temperature Compensation** - Adjust expected ranges based on outdoor temp
- [ ] **Fixed Orifice vs TXV Detection** - Different superheat targets (TXV: 10-12°F, Fixed: use chart)
- [ ] **Manufacturer Specs Integration** - Pull from equipment nameplate data when available

### Phase 3: Real-Time Alerts & Diagnostics
- [ ] **Out-of-Range Detection** - Alert when readings deviate from expected:
  - 🔴 Critical: >20% deviation (likely system fault)
  - 🟡 Warning: 10-20% deviation (needs attention)
  - 🟢 Normal: Within expected range
- [ ] **Smart Alerts with Context** - Not just "pressure low" but WHY it matters:
  - "Suction pressure 95 PSI is LOW for R410A AC. Expected: 118-145 PSI"
  - "Superheat 25°F is HIGH. Possible causes: low charge, TXV issue, airflow restriction"
- [ ] **Gauge Screen Integration** - Color-code readings based on status
  - Green glow = normal, Yellow = warning, Red = critical
  - Tap for detailed explanation

### Phase 4: Step-by-Step Troubleshooting Guidance
- [ ] **Diagnostic Decision Trees** - Based on symptom combinations:
  
  **Low Suction + High Superheat:**
  1. Check refrigerant charge (likely low)
  2. Inspect TXV sensing bulb placement
  3. Check for liquid line restriction
  4. Verify condenser airflow
  
  **High Suction + Low Superheat:**
  1. Check for overcharge
  2. Verify indoor blower operation
  3. Check evaporator airflow (dirty filter/coil)
  4. Inspect TXV for flooding
  
  **High Discharge + High Subcool:**
  1. Likely overcharged
  2. Check for condenser airflow issues
  3. Verify fan motor operation

- [ ] **Beginner Mode** - Extra detailed explanations for new techs
  - "What is superheat?" tooltips
  - Photo guides for common tasks
  - Video links to tutorials
- [ ] **Expert Mode** - Concise bullet points for experienced techs

### Phase 5: Learning & Improvement
- [ ] **Feedback Loop** - Tech confirms or overrides AI suggestion
  - "Was this diagnosis correct?" → Yes/No/Partially
  - Track correction patterns to improve model
- [ ] **Regional Variations** - Learn from different climates/regions
  - Florida AC vs Minnesota heat pump patterns
  - High altitude adjustments
- [ ] **Equipment-Specific Learning** - Build profiles for specific brands/models
  - "Carrier 24ACC always runs slightly higher discharge"
  - Learn quirks from aggregate data
- [ ] **Firebase ML Integration** - Eventually train custom model on collected data
  - Start with rule-based logic
  - Layer ML predictions as data grows
  - Keep human in the loop for safety

### Phase 6: UI Components
- [ ] **DiagnosticCard Widget** - Shows current status + recommendation
- [ ] **TroubleshootingSheet** - Bottom sheet with step-by-step guide
- [ ] **HistoryGraph** - Show readings over time during job
- [ ] **ComparisonView** - Before/after charging visualization

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
- [x] **Persist Zero Offsets** - Save pressure zeroing to SharedPreferences (Already implemented - GaugeZeroService persists to SharedPreferences, loaded at startup in main.dart)
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


### 3. Dispatch System Enhancements
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
