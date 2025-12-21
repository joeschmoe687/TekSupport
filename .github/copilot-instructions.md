# TekNeck HVAC Support App (TekTool)

## Tech Stack
- Flutter/Dart mobile app
- Firebase (Firestore, Cloud Functions, FCM)
- BLE device integration (Testo, Fieldpiece, Wey-Tek, ABM-200)
- **TekMate AI** - Backend AI for guidance, training, device setup

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
- auto_reconnect_service.dart: markConnected() must emit status
- device_registry.dart: Device profiles and parsing logic

## File Locations
- BLE services: lib/tools/services/
- Screens: lib/tools/screens/
- Utils: lib/tools/utils/