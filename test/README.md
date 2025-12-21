# TekTool - Test Suite Documentation

## Overview

This directory contains comprehensive tests for the TekTool HVAC Support App, covering unit tests, widget tests, and integration tests.

## Test Structure

```
test/
├── widget_test.dart              # Legacy widget test (HomeScreen)
├── services/                     # Service layer tests
│   └── notification_service_test.dart
├── screens/                      # Screen widget tests
│   └── welcome_screen_test.dart
└── tools/                        # TekTool-specific tests
    ├── services/                 # BLE service tests
    │   ├── device_registry_test.dart
    │   └── refrigerant_detector_test.dart
    └── utils/                    # Utility tests
        └── pt_chart_test.dart

integration_test/
├── app_test.dart                 # Comprehensive UI integration tests
└── test_driver.dart              # Integration test driver
```

## Running Tests

### Unit Tests (Fast)

Run all unit tests:
```bash
flutter test
```

Run specific test file:
```bash
flutter test test/tools/utils/pt_chart_test.dart
```

Run with coverage:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Widget Tests

Widget tests are included in the standard test suite:
```bash
flutter test test/screens/
flutter test test/widget_test.dart
```

### Integration Tests (Requires Device/Emulator)

**Note:** Integration tests require Flutter to be installed. In CI environments without Flutter, these tests are skipped.

Run integration tests on connected device:
```bash
# List available devices
flutter devices

# Run on specific device
flutter test integration_test/app_test.dart --device-id=<device_id>

# Run with driver for report generation
flutter drive \
  --driver=integration_test/test_driver.dart \
  --target=integration_test/app_test.dart
```

The integration test suite will:
- Navigate through all app screens
- Test all buttons and interactive elements
- Generate a detailed test report
- Save report to `integration_test_report.txt`

## Test Coverage

### ✅ Unit Tests (Do Not Require Device)

- **PTChart** - Refrigerant pressure-temperature calculations
  - Saturation temperature calculations
  - Saturation pressure calculations
  - Superheat/subcool calculations
  - Target superheat for fixed orifice systems
  
- **DeviceRegistry** - BLE device profiles
  - Device profile lookup by UUID
  - Device detection by name
  - Supported manufacturers and device types
  
- **RefrigerantDetector** - Auto-detection logic
  - Refrigerant detection from pressure readings
  - Confidence scoring
  - Alternate refrigerant suggestions

- **NotificationService** - FCM push notifications
  - Singleton pattern
  - Required methods present

### ✅ Widget Tests

- **WelcomeScreen** - Initial app screen
  - Welcome message display
  - Feature bullets visible
  - Logo display
  - Start Chat button interaction

- **HomeScreen** - Main dashboard (legacy test)
  - Welcome text display
  - Chat button presence
  - Image display

### ✅ Integration Tests (Comprehensive UI Flow)

The integration test suite (`integration_test/app_test.dart`) provides production-ready testing of:

1. **Welcome Screen**
   - Screen renders correctly
   - Feature bullets visible
   - Logo display
   - Start Chat button functionality

2. **Authentication Flow** (if not logged in)
   - Email/password input fields
   - Toggle between login/signup
   - Form validation

3. **Main Navigation** (if logged in)
   - Bottom navigation bar
   - Tab switching (Tools, Devices, Settings)
   - Role-based tabs (Admin, Tech Inbox)

4. **Tools Hub Screen**
   - Tool cards display
   - Gauge navigation
   - Scale navigation
   - Airflow navigation
   - Support contact button

5. **Device Management**
   - Device list display
   - Scan button
   - Connection status
   - BLE sniffer (admin only)

6. **Settings Screen**
   - Settings list display
   - Theme toggle
   - Storage navigation
   - Scale unit settings
   - Auto-responder (admin/tech)
   - Logout button

7. **Storage Screen**
   - Device storage
   - Connection history
   - ML patterns
   - Device profiles

## Test Report Format

Integration tests generate a detailed report with:
- Test execution time
- Pass/fail/skip counts
- Results grouped by screen
- Error details for failed tests

Example report snippet:
```
═══════════════════════════════════════════════════════════
  TekTool - Integration Test Report
═══════════════════════════════════════════════════════════

📅 Test Date: 2025-12-21T04:00:00.000Z
⏱️  Duration: 45 seconds

───────────────────────────────────────────────────────────
  SUMMARY
───────────────────────────────────────────────────────────
  ✅ Passed:  42
  ❌ Failed:  0
  ⏭️  Skipped: 8
  📊 Total:   50

───────────────────────────────────────────────────────────
  📱 Welcome Screen
───────────────────────────────────────────────────────────
  ✅ Renders
      Welcome screen loaded successfully
  ✅ Feature Bullets
      All feature bullets visible
  ✅ Logo
      Logo image loaded
  ✅ Start Chat Button
      Start Chat button tapped successfully
```

## Test Best Practices

1. **Unit Tests**
   - Test business logic in isolation
   - No UI dependencies
   - Fast execution (< 1 second each)
   - Mock external dependencies

2. **Widget Tests**
   - Test individual widgets
   - Verify UI rendering
   - Test user interactions
   - Use `pumpWidget` for rendering

3. **Integration Tests**
   - Test complete user flows
   - Verify navigation
   - Test with real Firebase (test project)
   - BLE tests skip when no devices connected

## CI/CD Integration

### GitHub Actions Workflow (Example)

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Analyze code
        run: flutter analyze
      
      - name: Run unit tests
        run: flutter test --coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: coverage/lcov.info
```

## Known Test Limitations

1. **BLE Device Tests**
   - Cannot test actual BLE connections without hardware
   - BLE-dependent tests are skipped in CI
   - Protocol parsing tests use mock data

2. **Firebase Auth Tests**
   - Integration tests require valid test credentials
   - Tests skip if not authenticated

3. **Platform-Specific Tests**
   - SMS auto-responder (Android only)
   - Native platform features tested manually

## Manual Testing Checklist

For production releases, perform manual testing of:

- [ ] BLE device connections (Testo, Weytek, ABM-200)
- [ ] Real-time gauge readings with connected devices
- [ ] Firebase chat synchronization with web dashboard
- [ ] Push notifications (admin alerts, customer replies)
- [ ] SMS auto-responder (Android, off-hours)
- [ ] WhatsApp routing for support channels
- [ ] Stripe payment flow (web)
- [ ] Theme switching (light/dark)
- [ ] Permission requests (BLE, location, notifications, SMS)
- [ ] Offline functionality
- [ ] Background BLE reconnection

## Updating Tests

When adding new features:

1. Add unit tests for business logic (`test/`)
2. Add widget tests for UI components (`test/screens/`, `test/widgets/`)
3. Update integration test suite (`integration_test/app_test.dart`)
4. Update this README with test coverage

## Questions?

See project documentation:
- [README.md](../README.md) - Project overview
- [TODO.md](../TODO.md) - Feature roadmap
- [docs/](../docs/) - Technical documentation

For CI/CD issues, check `.github/workflows/` configuration.
