# iOS and macOS Setup Guide for First Test Run

**Target Devices:**
- 8th Gen iPad (2020, iOS 15+)
- iPhone 15 Pro (iOS 17+)
- 2022 Mac with M1 Max chip (macOS 12+)

---

## Prerequisites

### Development Machine Setup
1. **Xcode 15+** installed on Mac
2. **Flutter SDK** installed and in PATH
3. **CocoaPods** installed: `sudo gem install cocoapods`
4. **Apple Developer Account** (for device testing)
5. **Firebase CLI** installed: `npm install -g firebase-tools`

---

## Part 1: iOS Setup (iPad & iPhone)

### Step 1: Configure Xcode Project
```bash
# Navigate to project
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app

# Clean previous builds
flutter clean
flutter pub get

# Install iOS dependencies
cd ios
pod install
cd ..
```

### Step 2: Open Xcode Project
```bash
open ios/Runner.xcworkspace
```

**In Xcode:**

1. **Select "Runner" project** in left sidebar
2. **Select "Runner" target** under TARGETS
3. **Go to "Signing & Capabilities" tab**

### Step 3: Configure Signing
- [ ] Team: Select your Apple Developer Team
- [ ] Bundle Identifier: `com.tekneckjoe.tektool`
- [ ] Check "Automatically manage signing"
- [ ] Provisioning Profile: Let Xcode manage

### Step 4: Set Deployment Target
- [ ] In "General" tab → Deployment Info
- [ ] Set "Minimum Deployments" to **iOS 15.0**
- [ ] Device: **iPhone** and **iPad**

### Step 5: Verify Capabilities
Check that these are enabled in "Signing & Capabilities":
- [x] Background Modes
  - [x] Background fetch
  - [x] Remote notifications
  - [x] Uses Bluetooth LE accessories
- [x] Push Notifications
- [x] Access WiFi Information

### Step 6: Connect Physical Devices

#### For iPad (8th Gen)
1. Connect iPad via USB-C cable
2. On iPad: Trust the computer when prompted
3. In Xcode: Select iPad from device dropdown
4. Verify "iPad (Your Name's iPad)" appears

#### For iPhone (15 Pro)
1. Connect iPhone via USB-C cable
2. On iPhone: Trust the computer when prompted
3. In Xcode: Select iPhone from device dropdown
4. Verify "iPhone (Your Name's iPhone)" appears

### Step 7: Build and Install

**Option A: Build in Xcode**
1. Select device from dropdown (iPad or iPhone)
2. Click "Play" button (▶️) or press Cmd+R
3. Wait for build to complete
4. App installs and launches on device

**Option B: Build with Flutter CLI**
```bash
# For specific device
flutter run -d <device-id>

# To get device ID
flutter devices

# Example output:
# Found 3 devices:
#   Joey's iPad (mobile) • 00008101-001A1234567890AB • ios • iOS 15.7.1
#   Joey's iPhone (mobile) • 00008110-001C1234567890CD • ios • iOS 17.2
```

### Step 8: Grant Permissions on Device
When app first launches, grant these permissions:
1. **Bluetooth** - Required for BLE devices
2. **Camera** - Required for equipment tag scanning
3. **Location** - Required for job site detection
4. **Notifications** - Required for push alerts

---

## Part 2: macOS Setup (M1 Max Mac)

### Step 1: Configure macOS Project
```bash
# Navigate to project
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app

# Clean previous builds
flutter clean
flutter pub get

# Install macOS dependencies
cd macos
pod install
cd ..
```

### Step 2: Open Xcode Project
```bash
open macos/Runner.xcworkspace
```

**In Xcode:**

1. **Select "Runner" project** in left sidebar
2. **Select "Runner" target** under TARGETS
3. **Go to "Signing & Capabilities" tab**

### Step 3: Configure Signing
- [ ] Team: Select your Apple Developer Team
- [ ] Bundle Identifier: `com.tekneckjoe.tektool`
- [ ] Check "Automatically manage signing"

### Step 4: Set Deployment Target
- [ ] In "General" tab → Deployment Info
- [ ] Set "Minimum Deployments" to **macOS 12.0**
- [ ] Architecture: **Standard Architectures (arm64, x86_64)**

### Step 5: Configure Entitlements
In "Signing & Capabilities", add these entitlements:

**Click "+ Capability" and add:**
- [x] **Bluetooth** - For BLE device connectivity
- [x] **Camera** - For equipment scanning
- [x] **Location** - For job site features
- [x] **Network** - For Firebase/API access
- [x] **App Sandbox** (should be enabled by default)
  - [x] Incoming Connections (Server)
  - [x] Outgoing Connections (Client)

### Step 6: Verify App Sandbox Settings
In "App Sandbox" section:
- [x] Network: Incoming/Outgoing Connections
- [x] Hardware: Camera, Bluetooth, Location
- [x] File Access: User Selected File (Read/Write)

### Step 7: Build and Run

**Option A: Build in Xcode**
1. Select "My Mac (Designed for iPad)" from device dropdown
2. Click "Play" button (▶️) or press Cmd+R
3. Wait for build to complete
4. App launches on Mac

**Option B: Build with Flutter CLI**
```bash
# Build macOS app
flutter run -d macos

# Or build release bundle
flutter build macos --release

# App bundle location:
# build/macos/Build/Products/Release/tektool.app
```

### Step 8: First Launch Permissions
On first launch, grant these permissions:
1. **Bluetooth** - System prompt
2. **Camera** - System prompt
3. **Location** - System prompt
4. **Network** - May appear in System Preferences → Security

**If permissions denied:**
- Go to **System Preferences → Security & Privacy**
- Select each category (Camera, Bluetooth, Location)
- Check the box next to "tektool.app"

---

## Part 3: Troubleshooting

### Issue: "Untrusted Developer" on iOS
**Solution:**
1. On device: Settings → General → VPN & Device Management
2. Find developer profile
3. Tap "Trust [Developer Name]"

### Issue: "App is not open because it is from an unidentified developer" on macOS
**Solution:**
1. System Preferences → Security & Privacy → General
2. Click "Open Anyway" button
3. Confirm in popup

### Issue: Build fails with "Signing for Runner requires a development team"
**Solution:**
1. Open Xcode project
2. Select Runner target
3. Signing & Capabilities → Team: Select your team
4. If no team: Add Apple ID in Xcode → Preferences → Accounts

### Issue: CocoaPods error "Unable to find a specification for..."
**Solution:**
```bash
cd ios  # or macos
pod repo update
pod install --repo-update
cd ..
```

### Issue: "No provisioning profile found" in Xcode
**Solution:**
1. Xcode → Preferences → Accounts
2. Select Apple ID
3. Click "Download Manual Profiles"
4. Return to project and try again

### Issue: macOS build fails with architecture error
**Solution:**
```bash
# Clean and rebuild
cd macos
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter build macos --release
```

### Issue: BLE permissions not working on macOS
**Solution:**
1. Check Info.plist has NSBluetoothAlwaysUsageDescription
2. Verify App Sandbox → Hardware → Bluetooth is checked
3. System Preferences → Security → Privacy → Bluetooth → Check app

---

## Part 4: Verification Tests

### Quick Smoke Test (5 minutes)
Run on each device:
1. [ ] App launches without crash
2. [ ] Login/signup screen appears
3. [ ] Can create account or login
4. [ ] Home screen loads
5. [ ] Navigate to Tools → Scan
6. [ ] BLE scanner finds devices

### Full Test
Follow the complete [IOS_MACOS_TEST_CHECKLIST.md](./IOS_MACOS_TEST_CHECKLIST.md)

---

## Part 5: Build Artifacts

### iOS Build Outputs
```
# Debug build (for testing)
build/ios/iphoneos/Runner.app

# Release build (for distribution)
build/ios/iphoneos/Runner.app
```

### macOS Build Outputs
```
# Debug build
build/macos/Build/Products/Debug/tektool.app

# Release build
build/macos/Build/Products/Release/tektool.app
```

---

## Part 6: Hot Reload Setup (Development)

For faster iteration during testing:

### iOS (Connected Device)
```bash
# Start with hot reload enabled
flutter run -d <ios-device-id> --verbose

# In terminal, press:
# r - Hot reload
# R - Hot restart
# q - Quit
```

### macOS
```bash
# Start with hot reload enabled
flutter run -d macos --verbose
```

---

## Command Quick Reference

```bash
# List all devices
flutter devices

# Clean project
flutter clean

# Get dependencies
flutter pub get

# iOS pod install
cd ios && pod install && cd ..

# macOS pod install
cd macos && pod install && cd ..

# Build iOS
flutter build ios --release

# Build macOS
flutter build macos --release

# Run on specific device
flutter run -d <device-id>

# View logs
flutter logs

# Check for issues
flutter analyze

# Open Xcode workspace
open ios/Runner.xcworkspace
open macos/Runner.xcworkspace
```

---

## Next Steps

After setup is complete:
1. ✅ Proceed to [IOS_MACOS_TEST_CHECKLIST.md](./IOS_MACOS_TEST_CHECKLIST.md)
2. ✅ Document all findings
3. ✅ Address critical issues
4. ✅ Prepare for production release

---

**Version:** 1.0.0  
**Last Updated:** January 3, 2026  
**Prepared for:** Joey Keilbarth
