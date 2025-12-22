# Web UI for Live Device Monitoring

## Overview

The TekTool app now includes a web UI that allows you to view live BLE device data from your Mac or any desktop browser. The interface is clean, modern, and uses the same dark gradient theme as the mobile app.

## Features

### For All Users
- **Real-time device monitoring** - See live readings from all connected BLE devices
- **Auto-refresh** - Data updates automatically as measurements stream in
- **Color-coded status** - Devices show green (active), yellow (recent), or red (stale) based on data freshness
- **Battery indicators** - Visual battery level for supported devices
- **Responsive layout** - Adapts to different screen sizes (1-3 columns)
- **Dark theme** - Matches the mobile app's purple/cyan gradient aesthetic

### For Admin Users
- **Multi-user viewing** - Switch between different users' devices via dropdown
- **Admin badge** - Visual indicator showing admin access level
- **Device ID display** - Shows truncated device IDs for debugging

## How to Use

### Viewing Your Own Devices

1. **Connect devices in mobile app**
   - Open the TekTool mobile app on your phone
   - Go to Tools → Devices
   - Connect your Bluetooth HVAC devices (Testo, Fieldpiece, Wey-Tek, ABM-200, etc.)

2. **Open web UI on your Mac**
   - Build and deploy the web version: `flutter build web`
   - Or use Firebase hosting: `firebase deploy --only hosting`
   - Navigate to the web URL in your browser
   - Sign in with the same account you use in the mobile app

3. **View live data**
   - The web UI will automatically display all connected devices
   - Each device card shows:
     - Device name and type
     - Current reading (large display)
     - Unit of measurement
     - Battery level (if available)
     - Last update timestamp
     - Connection status (colored dot)

### Admin Multi-User Viewing

If you're an admin:

1. Sign in with your admin account
2. Look for the user dropdown in the app bar (next to refresh button)
3. Select "My Devices" to see your own devices
4. Or select another user's name to view their connected devices
5. Use the refresh button to reload the user list if needed

## Status Indicators

- **🟢 Green dot** - Device is actively streaming (< 5 seconds old)
- **🟡 Yellow dot** - Device recently updated (< 30 seconds old)
- **🔴 Red dot** - Device data is stale (> 30 seconds old)

## Device Types Supported

All mobile app device types are displayed:
- **Refrigerant Gauge** - Pressure readings (PSI, bar, kPa)
- **Temperature Probe** - Temperature readings (°F, °C)
- **Refrigerant Scale** - Weight measurements (oz, lb, kg)
- **Airflow Meter** - Air velocity (FPM, CFM)
- **Pressure Probe** - Pressure readings
- **Clamp Meter** - Electrical measurements
- **Vacuum Gauge** - Vacuum pressure

## Technical Details

### Data Flow
```
Mobile App (BLE) → DeviceDataService → LiveDataSyncService → Firestore
                                                                ↓
Web Browser ← Firestore Realtime Listener ← LiveDataWebScreen
```

### Firestore Structure
```
live_device_data/
  {userId}/
    readings/
      {deviceId}/
        - deviceId: string
        - deviceName: string
        - type: string (e.g., "refrigerantGauge")
        - value: number
        - unit: string (e.g., "PSI")
        - timestamp: timestamp
        - batteryLevel: number (0-100, optional)
        - batteryUpdatedAt: timestamp (optional)
```

### Security
- Users can only read/write their own data
- Admins can read all users' data
- Enforced via Firestore security rules

## Building for Web

### Development
```bash
flutter run -d chrome
```

### Production Build
```bash
# Build web assets
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### Configuration
The web app uses the same Firebase configuration as the mobile app:
- Project: `tekneck-support`
- Configuration: `lib/firebase_options.dart`

## Troubleshooting

### No devices showing?
1. Make sure devices are connected in the mobile app
2. Check that you're signed in with the same account on web and mobile
3. Try the refresh button in the web UI
4. Verify the mobile app is running and has an active internet connection

### Data not updating?
1. Check the timestamp under "Live Device Monitor" title
2. Verify the status dot color (green = active)
3. Ensure the mobile app is in foreground and actively reading from devices
4. Check your internet connection on both mobile and web

### Admin can't see other users?
1. Verify you have `role: 'admin'` in your Firestore user document
2. Check that other users actually have active device connections
3. Try the refresh button to reload the user list

## Future Enhancements

Potential additions:
- Historical data charts
- Device comparison view
- Alert notifications for out-of-range values
- Export data as CSV
- Full-screen mode for single device
- Custom refresh intervals
- Dark/light theme toggle persistence

## Support

For issues or questions:
- Check the mobile app logs for sync errors
- Verify Firestore security rules are deployed
- Test with Firebase emulator suite locally
- Contact TekNeck support via in-app chat
