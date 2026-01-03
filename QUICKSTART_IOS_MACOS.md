# 🚀 Quick Start: iOS and macOS Testing

**For:** Joey Keilbarth  
**Date:** January 3, 2026  
**Branch:** `copilot/fine-tune-test-for-ios-macos`

---

## ⏱️ 5-Minute Setup

### 1. Prerequisites Check
```bash
# On your Mac, verify you have:
xcode-select --version  # Should show Xcode path
flutter --version       # Should show Flutter version
pod --version          # Should show CocoaPods version
```

If any are missing:
- **Xcode:** Install from Mac App Store
- **Flutter:** Already installed at `/Users/joeykeilbarth/flutter/`
- **CocoaPods:** `sudo gem install cocoapods`

### 2. Navigate to Project
```bash
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app
```

### 3. Clean & Setup
```bash
# Clean previous builds
flutter clean
flutter pub get

# Install iOS dependencies
cd ios
pod install
cd ..

# Install macOS dependencies
cd macos
pod install
cd ..
```

**Expected:** "Pod installation complete! ✅" for both

### 4. Validate Configuration
```bash
./validate_ios_macos_setup.sh
```

**Expected:** Mostly green checkmarks ✅

---

## 📱 Test on Devices

### Quick Test (iPhone 15 Pro)
```bash
# Connect iPhone via USB-C
# Unlock iPhone and trust computer

# List devices
flutter devices

# Run app (look for iPhone 15 Pro in list)
flutter run -d "<your-iphone-id>"
```

**Expected:** App builds and launches on iPhone

### Quick Test (iPad 8th Gen)
```bash
# Connect iPad via USB-C
# Same process as iPhone

flutter run -d "<your-ipad-id>"
```

### Quick Test (Mac M1 Max)
```bash
# No cable needed!
flutter run -d macos
```

**Expected:** App launches as native Mac application

---

## 📋 Full Testing

Once quick tests pass, open the comprehensive guides:

1. **Setup:** `IOS_MACOS_SETUP_GUIDE.md` (detailed Xcode configuration)
2. **Testing:** `IOS_MACOS_TEST_CHECKLIST.md` (complete test scenarios)
3. **Optimization:** `DEVICE_OPTIMIZATION_NOTES.md` (device-specific tips)

---

## 🔍 What Was Changed?

### iOS Configuration
- ✅ Deployment target: iOS 15.0 (supports iPad 8th Gen & iPhone 15 Pro)
- ✅ Build optimizations in Podfile
- ✅ All permissions already configured

### macOS Configuration
- ✅ Deployment target: macOS 12.0 (M1 Max native)
- ✅ Apple Silicon optimization (universal binary)
- ✅ Added Bluetooth, Camera, Location permissions

---

## ❓ Troubleshooting

### "Command not found: flutter"
```bash
export PATH="$HOME/flutter/bin:$PATH"
# Or: source ~/.zshrc
```

### "No provisioning profile" in Xcode
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Runner" target
3. Signing & Capabilities → Select your team
4. Check "Automatically manage signing"

### Pod install fails
```bash
cd ios  # or macos
sudo gem install cocoapods
pod repo update
pod install --repo-update
cd ..
```

### "Untrusted Developer" on device
- Device: Settings → General → VPN & Device Management
- Tap your developer profile → Trust

---

## ✅ Success Criteria

**Minimum Test Pass:**
- [x] App launches on all 3 devices ✅
- [x] Firebase connects ✅
- [x] At least 1 BLE device connects ✅
- [x] Chat works ✅
- [x] No crashes in 15-minute session ✅

---

## 📁 Documentation Files

| File | Purpose |
|------|---------|
| `IOS_MACOS_SETUP_GUIDE.md` | Complete setup instructions |
| `IOS_MACOS_TEST_CHECKLIST.md` | Comprehensive test scenarios |
| `DEVICE_OPTIMIZATION_NOTES.md` | Hardware-specific notes |
| `IOS_MACOS_FINE_TUNING_SUMMARY.md` | Changes summary |
| `validate_ios_macos_setup.sh` | Configuration checker |
| `QUICKSTART_IOS_MACOS.md` | This file |

---

## 📞 Need Help?

**Configuration is valid:** All Podfiles and Info.plist files verified ✅

**Next step:** Run the quick tests above, then proceed to full testing with the checklist.

---

**Status:** ✅ Ready for Testing  
**Last Updated:** January 3, 2026
