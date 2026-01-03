# iOS and macOS First Test Run Checklist

**Test Date:** January 2026  
**Tester:** Joey Keilbarth  
**Devices:**
- 8th Gen iPad (2020, iOS 15+)
- iPhone 15 Pro (iOS 17+)
- 2022 Mac with M1 Max chip (macOS 12+)

---

## Pre-Test Setup

### 1. Build Configuration
- [ ] Clean build directory: `flutter clean`
- [ ] Get dependencies: `flutter pub get`
- [ ] Run iOS pod install: `cd ios && pod install && cd ..`
- [ ] Run macOS pod install: `cd macos && pod install && cd ..`

### 2. iOS Build (iPad & iPhone)
```bash
# For physical device testing
flutter build ios --release

# For simulator testing (development)
flutter build ios --debug
```

**Expected Output:**
- Build completes without errors
- App bundle created in `build/ios/iphoneos/Runner.app`
- No deployment target warnings

### 3. macOS Build (M1 Max Mac)
```bash
# For release testing
flutter build macos --release

# For development testing
flutter build macos --debug
```

**Expected Output:**
- Build completes without errors
- App bundle created in `build/macos/Build/Products/Release/tektool.app`
- No architecture warnings (should build universal binary)

---

## Test Categories

## A. App Launch & Core Functionality

### iOS (iPad & iPhone)
- [ ] App launches without crashes
- [ ] Firebase initializes successfully
- [ ] No permission errors in console
- [ ] Welcome screen displays correctly
- [ ] Login/signup works
- [ ] Theme applies correctly (gradient purple/cyan)

### macOS
- [ ] App launches without crashes
- [ ] Firebase initializes successfully
- [ ] macOS-specific UI adjustments work
- [ ] Window resizing works properly
- [ ] Menu bar integration (if applicable)

---

## B. Bluetooth (BLE) Functionality

### iOS Testing
**Test on both iPad and iPhone:**

#### 1. Permission Handling
- [ ] Bluetooth permission prompt appears
- [ ] User can grant/deny Bluetooth access
- [ ] App handles denied permissions gracefully
- [ ] Background Bluetooth mode works

#### 2. Device Scanning
- [ ] Navigate to Tools → Scan
- [ ] Scanner finds nearby BLE devices
- [ ] Signal strength (RSSI) displays correctly
- [ ] "SUPPORTED" badge shows for known devices
- [ ] Unknown devices appear with generic icons

#### 3. Device Connection
**Test with each device type:**

- [ ] **Testo T115i** (Temperature Probe)
  - Connects successfully
  - Displays live temperature readings
  - Temperature updates in real-time
  - Probe assignment works (Low/High, Suction/Liquid)
  - Auto-reconnection after disconnect

- [ ] **Testo T549i** (Pressure Probe)
  - Connects successfully
  - Displays live pressure readings (PSI)
  - Pressure updates in real-time
  - Zero offset calibration works
  - PT chart calculations display correctly

- [ ] **Wey-Tek HD Scale** (Refrigerant Scale)
  - Connects successfully
  - Displays live weight readings (oz)
  - Tare function works
  - Unit switching works (lb, oz, kg)
  - Auto-reconnection after power cycle

- [ ] **ABM-200 Airflow Meter**
  - Connects successfully
  - Displays CFM readings
  - Temperature and humidity display (if available)
  - Data updates in real-time

- [ ] **Fieldpiece Devices** (Broadcast-only)
  - Scanner detects broadcast advertisements
  - Parses manufacturer data correctly
  - Displays measurements without connection

#### 4. Multi-Device Management
- [ ] Connect multiple devices simultaneously
- [ ] All devices stream data independently
- [ ] No conflicts between device connections
- [ ] Auto-reconnect works for all saved devices
- [ ] Device persistence across app restarts

#### 5. Background BLE Performance
- [ ] App backgrounds → BLE connections maintain
- [ ] Foreground service notification appears (Android)
- [ ] Return to app → data still streaming
- [ ] No excessive battery drain

### macOS BLE Testing
**Note:** macOS BLE may behave differently than iOS

- [ ] Bluetooth permission prompt appears
- [ ] Scanner finds BLE devices
- [ ] Can connect to test device
- [ ] Data streams correctly
- [ ] macOS system Bluetooth preferences don't conflict
- [ ] App works with Bluetooth turned off gracefully

---

## C. Firebase Integration

### All Platforms
- [ ] **Authentication**
  - Sign up with email/password
  - Login with existing account
  - Password reset works
  - Auto-login on app restart
  
- [ ] **Firestore**
  - Chat messages sync in real-time
  - User profile updates save correctly
  - Admin data only visible to admin role
  - Offline persistence works
  
- [ ] **Cloud Messaging (FCM)**
  - Push notification permissions granted
  - Notifications appear when app in background
  - Tapping notification opens relevant screen
  - Sound/badge works correctly
  
- [ ] **Cloud Functions**
  - TekMate proxy function responds (admin only)
  - Auto-response function triggers
  - Transaction logging works

---

## D. Camera & Image Features

### iOS (iPad & iPhone)
- [ ] Camera permission prompt appears
- [ ] Can take photo from camera
- [ ] Can select photo from library
- [ ] OCR text recognition works (equipment tags)
- [ ] Photos save to chat/job records
- [ ] Image quality is acceptable

### macOS
- [ ] Camera permission prompt appears
- [ ] Built-in FaceTime camera accessible
- [ ] Can capture images
- [ ] File picker works for image selection

---

## E. Location Services

### iOS (iPad & iPhone - Cellular models only)
- [ ] Location permission prompt appears
- [ ] Current location detected correctly
- [ ] Job site auto-detection works
- [ ] Geocoding converts address properly
- [ ] Background location updates (if enabled)

### macOS
- [ ] Location permission prompt appears
- [ ] Location services work (if available)
- [ ] Falls back gracefully if no location hardware

---

## F. UI/UX Testing

### iPad-Specific
- [ ] Landscape orientation supported
- [ ] Portrait orientation supported
- [ ] Split-screen multitasking works
- [ ] Slide Over mode works
- [ ] Keyboard shortcuts (if implemented)
- [ ] Apple Pencil input (if applicable)
- [ ] Proper spacing for larger screen

### iPhone-Specific
- [ ] Portrait mode primary
- [ ] Safe area insets respected (notch/Dynamic Island)
- [ ] Reachability considerations
- [ ] One-handed use patterns
- [ ] Gesture navigation works

### macOS-Specific
- [ ] Window resizing smooth
- [ ] Minimum window size enforced
- [ ] Maximum window size reasonable
- [ ] Keyboard shortcuts work
- [ ] Menu bar integration
- [ ] Trackpad gestures work
- [ ] Dark/Light mode switching

---

## G. Performance Testing

### All Devices
- [ ] App launch time < 3 seconds
- [ ] Smooth scrolling (60 FPS)
- [ ] No memory leaks over 30-minute session
- [ ] Battery usage acceptable
- [ ] No overheating during normal use
- [ ] BLE operations don't block UI

### M1 Mac-Specific
- [ ] Leverages Apple Silicon performance
- [ ] No Rosetta translation warnings
- [ ] Native ARM64 build
- [ ] Low CPU usage when idle
- [ ] Efficient memory usage

---

## H. Edge Cases & Error Handling

### All Platforms
- [ ] Airplane mode → graceful offline handling
- [ ] WiFi drops → Firebase reconnects automatically
- [ ] BLE device out of range → clear error message
- [ ] BLE device powered off → auto-reconnect when back
- [ ] Low battery → no crashes
- [ ] Background app kill → state restored on relaunch
- [ ] Rapid screen rotations → no crashes
- [ ] Permission denied → clear explanation

---

## I. Admin Features (Ghost Mode)

### All Platforms - Admin Login Required
- [ ] TekMate UI visible to admin only
- [ ] "Ask TekMate" button appears in chat
- [ ] TekMate suggestions generate correctly
- [ ] Confidence scores display
- [ ] Non-admin users see zero TekMate features
- [ ] No TekMate network calls for non-admins
- [ ] BLE Sniffer accessible (admin only)
- [ ] SMS auto-responder settings (admin only)

---

## J. Payment System (Stripe)

### iOS Only (Payment Sheet)
- [ ] Support options screen loads
- [ ] Pricing displays correctly (business hours vs 24HR)
- [ ] Payment sheet opens without errors
- [ ] Card input field works
- [ ] Google Pay available
- [ ] Apple Pay available
- [ ] Payment succeeds → Firestore logs transaction
- [ ] Payment fails → error message clear
- [ ] WhatsApp opens with correct message

### macOS
- [ ] Web-based payment flow (if implemented)
- [ ] Or disable payment on macOS gracefully

---

## K. Known Issues to Document

### During Testing, Note:
- Any crashes → capture logs
- Performance issues → note device and scenario
- UI glitches → screenshots
- BLE connection failures → note device model
- Permission issues → note exact steps
- Build warnings → capture and fix if critical

---

## Post-Test Actions

### 1. Collect Logs
```bash
# iOS device logs
idevicesyslog > ios_test_log.txt

# macOS app logs
log show --predicate 'process == "tektool"' --last 1h > macos_test_log.txt
```

### 2. Document Results
- [ ] Create `IOS_MACOS_TEST_RESULTS.md`
- [ ] List all passed tests
- [ ] List all failed tests
- [ ] Document device-specific issues
- [ ] Prioritize fixes

### 3. Fix Critical Issues
- [ ] Crashes (highest priority)
- [ ] Permission denials
- [ ] BLE connection failures
- [ ] Firebase sync issues

### 4. Optimize for Next Build
- [ ] Address performance bottlenecks
- [ ] Fix UI/UX issues
- [ ] Update deployment targets if needed
- [ ] Add missing platform-specific features

---

## Success Criteria

### Minimum for "Test Pass"
- ✅ App launches on all 3 devices
- ✅ Firebase connects and authenticates
- ✅ At least 1 BLE device connects and streams data
- ✅ Chat feature works
- ✅ No critical crashes during 15-minute test session
- ✅ All permissions grant successfully

### Ideal for "Production Ready"
- ✅ All core features work on all devices
- ✅ Multi-device BLE works flawlessly
- ✅ No UI glitches or layout issues
- ✅ Performance is smooth (60 FPS)
- ✅ Battery usage reasonable
- ✅ Admin features work correctly
- ✅ Payment system functional
- ✅ Error handling is user-friendly

---

## Quick Command Reference

```bash
# Clean build
flutter clean && flutter pub get

# iOS pod install
cd ios && pod install && cd ..

# macOS pod install
cd macos && pod install && cd ..

# Build for iOS
flutter build ios --release

# Build for macOS
flutter build macos --release

# Run on connected device
flutter run -d <device-id>

# List devices
flutter devices

# View logs
flutter logs

# Check for issues
flutter analyze
```

---

## Notes Section

**Tester Notes:**
(Add observations during testing here)

---

**Version:** 1.0.0  
**Last Updated:** January 3, 2026  
**Prepared for:** Joey Keilbarth
