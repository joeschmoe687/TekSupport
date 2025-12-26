# Changelog

All notable changes to the TekTool HVAC Support App.

## [Unreleased] - 2025-12-23

### Added
- ProGuard configuration for Stripe payment compatibility
  - Enhanced ProGuard rules with AppCompat and Stripe keep rules
  - Enabled minification in release builds
- User Verification Debug Screen (`lib/screens/debug/user_verification_screen.dart`)
  - Shows Firebase Auth status
  - Displays Firestore user document
  - Shows Stripe configuration
  - Copy-to-clipboard functionality for debugging
- Enhanced payment logging throughout payment flow
  - Detailed Stripe error logging with error codes and types
  - Payment flow visualization with emoji markers (💳 ✅ ❌ ⚠️)
  - Stack trace logging for unexpected errors

### Changed
- Updated `support_contact_screen.dart` with loading state and null safety
  - Added `_isPricingLoaded` flag to prevent premature button taps
  - Added Firebase Auth verification before payment
  - Enhanced error handling with user-friendly messages
- Updated `payment_service.dart` with comprehensive logging
  - Added initialization status checks
  - Added detailed error reporting
- Updated README.md
  - Fixed GitHub repo reference (joeschmoe687 → TekNeck-LLC)
  - Updated status dates (Dec 19 → Dec 23, 2025)
  - Added Stripe debugging commands section

## [Dec 18, 2025] - TekTool Universal Bluetooth Hub

### Added
- **TekTool - Universal HVAC Bluetooth Hub**
  - `lib/bluetooth/bluetooth_service.dart` - Singleton BLE manager
  - `lib/tools/services/device_registry.dart` - Known HVAC device profiles
  - `lib/tools/services/refrigerant_detector.dart` - Auto-detect refrigerant
  - `lib/tools/services/gauge_zero_service.dart` - Smart zero prompt logic
  - `lib/tools/utils/pt_chart.dart` - P/T saturation tables (6 refrigerants)
  - `lib/tools/models/connected_device.dart` - Device data model
  - `lib/tools/screens/tools_hub_screen.dart` - Main dashboard
  - `lib/tools/screens/devices_screen.dart` - Device management
  - `lib/tools/screens/device_scan_screen.dart` - BLE scanning
  - `lib/tools/screens/ble_sniffer_screen.dart` - Admin debugging tool
  - `lib/tools/widgets/zero_prompt_dialog.dart` - Zero gauges modal
  - `lib/tools/widgets/refrigerant_confirm_dialog.dart` - R22 confirmation
  - `lib/screens/main_navigation_screen.dart` - Added Tools + Devices tabs
  - Updated Android/iOS permissions for Bluetooth + background

## [Dec 17, 2025] - Paid Support System

### Added
- **Paid Support System Implementation**
  - `lib/screens/support_contact_screen.dart` - New screen with pricing display
    - Dynamic price fetching from Firestore `settings/pricing`
    - CST business hours detection with time display
    - Phone/Video options route through WhatsApp Business (no direct phone number)
    - Transaction logging with correct pricing for each service type
    - UI: 4 service cards (Text Chat, Phone Call, Video Call, Direct Info)
  - `lib/screens/chat_screen.dart` - Added phone icon button in header
    - Navigates to SupportContactScreen
    - Always-accessible support option from any chat
  - `USERS/pages/chat.html` (Web) - Support modal with Stripe integration
    - Fetches pricing from same Firestore document (app-web parity)
    - Shows business hours indicator and current CST time
    - Payment flow: Select service → Stripe modal → Card entry → WhatsApp opens
    - All support channels (text/phone/video/whatsapp) route through WhatsApp Business
    - Transaction logging to Firestore on successful payment

### Changed
- **Phone Number Protection** - Removed direct phone number exposure
  - No phone number displayed in app or web UI
  - All support routes exclusively through WhatsApp
  - Prevents users from calling directly to bypass payment

### Deployed
- Flutter app: Compiled and running on device ✅
- Web UI: Deployed to Firebase hosting ✅

## [Dec 16, 2025] - Session Completion

### Added
- **Mark Session Complete Feature**
  - `lib/screens/tech_reply_screen.dart` - Added complete button and function
    - Green "Complete" button in AppBar with checkmark icon
    - Confirmation dialog before marking complete
    - Updates Firestore: status=completed, completedAt, completedBy, completedByUid
    - Adds system message to chat history
    - Shows success snackbar and navigates back to chat list
  - Matches web admin dashboard "Mark Complete" functionality
  - Supports pay-per-issue business model

## [Dec 15, 2025] - FCM Push Notifications & Gradient Theme

### Added
- **FCM Push Notifications**
  - `lib/services/notification_service.dart` - Full FCM implementation
    - Token registration on login (saved to Firestore `users/{uid}.fcmToken`)
    - Foreground message display
    - Background message handling
    - Notification tap navigation
  - Cloud Functions deployed:
    - `sendPushNotificationOnNewMessage` - Alerts admins when customer sends message
    - `sendPushNotificationOnAdminReply` - Alerts customer when admin replies
  - Auto-cleanup of invalid FCM tokens

- **Gradient Theme Styling**
  - `lib/widgets/gradient_scaffold.dart` - Reusable gradient components
    - `AppColors` - Consistent color constants (primaryCyan, primaryPurple, etc.)
    - `GradientScaffold` - Dark gradient background matching website
    - `GradientButton` - Styled buttons with gradient
    - `AppCard` - Consistent card styling
  - Updated screens: welcome, main_navigation, chat to use gradient theme

### Fixed
- Fixed RenderFlex overflow in admin_chat_detail_screen.dart
- Fixed setState() after dispose() in dispatch_screen.dart
- Fixed settings screen overflow (changed Row to Wrap for auto-reply hours)

### Changed
- **Message Sync Fix**
  - Admin chat screens now receive customer messages in real-time
  - Removed `orderBy('createdAt')` from Firestore queries (caused missing messages)
  - Manual sorting in Dart handles both `createdAt` and legacy `timestamp` fields
  - Auto-scroll to newest message when new messages arrive
  - Updated screens: `admin_chat_detail_screen.dart`, `tech_reply_screen.dart`

## [Dec 14, 2025] - Chat Improvements

### Fixed
- **Chat Fixes**
  - Session status badge shows "Claimed by [Tech Name]" instead of generic "Claimed"
  - Fixed admin messages not appearing in chat history
    - Added manual message sorting by `createdAt` or `timestamp` (handles both old and new messages)
    - Updated `chat_detail_screen.dart` to support legacy `timestamp` field
    - Admin messages now sync seamlessly from web UI to mobile app
  - Updated Firestore rules to allow customers to read tech user profiles

### Previous Updates
- Admin dashboard with 6 tabs (Overview, Dispatch, Customers, Invoices, Pricebook, Settings)
- Password autofill support via `AutofillGroup` and `AutofillHints`
- Pricebook categories/items drilldown navigation
- Dark theme alignment (#1A1A1A background, #4EC7F3 accent)
- `android/app/build.gradle`: using `dev.flutter.flutter-gradle-plugin`; namespace fixed to `com.tekneckjoe.tektool`
- `android/app/src/main/res/values/colors.xml`: added `ic_launcher_background`
- `lib/screens/dispatch_screen.dart`: `DateFormat` usage, filter chips, color API updated

## Production Readiness

### Completed ✅
- Paid support system with dynamic pricing
- WhatsApp-only routing (no direct phone exposure)
- Business hours logic (9-5 CST vs 24HR)
- Transaction logging to Firestore
- App-web feature parity
- Stripe payment (web)
- Firebase deployment
- Android build configured
- FCM push notifications
- Mark session complete feature
- Gradient theme styling
- Password autofill support

### Still Needed 🚀
- Test Stripe Payment Flow (end-to-end with real card)
  - Verify payment → Firestore logging → WhatsApp open
  - Test card decline error handling
  - Verify transaction amounts are correct
- Test WhatsApp Routing (all channels)
  - Web on mobile browser
  - App on Android device
  - Verify messages pre-fill correctly
- Business Hours Logic Validation
  - Test pricing shows correctly at different times
  - Verify CST timezone accuracy
- Firestore Security Rules Review
  - Users can only view own transactions
  - Admins can view all transactions
- Admin Transaction Dashboard (to be built)
  - View all support transactions
  - Filter by date/user/type/status
  - Export functionality
  - Refund capability
- Google Play Store Submission
  - Screenshots (support system, chat, dispatch)
  - Privacy policy update
  - Test on multiple device types
- Crash Reporting (Firebase Crashlytics integration)
- Monitoring & Alerting (Cloud Function failures, payment errors)
- User Documentation (FAQ, support process)
