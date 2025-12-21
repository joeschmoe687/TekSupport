# TekNeck HVAC Support App

## Tech Stack
- Flutter/Dart mobile app
- Firebase (Firestore, Cloud Functions, FCM)
- BLE device integration (Testo, Fieldpiece, Wey-Tek, ABM-200)

## Shared Firebase Backend
This app shares Firebase project `tekneck-support` with the AirPro website (airpronwa.com).

**Shared Collections:**
- `chats` - Customer support conversations
- `users` - User profiles
- `customers` - CRM data
- `jobs` - Dispatch/work orders
- `ble_sniff_logs` - BLE protocol captures (written by app, read by web)

**When modifying Firestore:**
- Check impact on web dashboard
- Don't change security rules without testing both platforms
- Keep collection schemas compatible

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
- auto_reconnect_service.dart: markConnected() must emit status
- device_registry.dart: Device profiles and parsing logic

## File Locations
- BLE services: lib/tools/services/
- Screens: lib/tools/screens/
- Utils: lib/tools/utils/