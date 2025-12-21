# UI Updates - Light Theme, Analog Gauges, and Scale Integration

## Overview
This document describes the major UI updates implemented for outdoor usability and enhanced user experience.

## 1. Light Theme (Outdoor Visibility Mode)

### Purpose
When working outdoors on condensers, bright sunlight makes dark themes difficult to read. The new light theme provides maximum contrast and visibility in bright conditions.

### Features
- **High Contrast Design**: Dark text on white/light gray backgrounds
- **Clean, Modern Aesthetic**: Subtle gradients with professional appearance
- **Rugged Feel**: Strong borders and clear typography designed for field work
- **Automatic Theme Persistence**: Your theme preference is saved between sessions

### Color Scheme
- **Background**: Light gray (#F5F5F5) with subtle blue-gray gradient
- **Cards/Surfaces**: Pure white (#FFFFFF) for maximum readability
- **Text**: Near-black (#1A1A1A) for primary text, dark gray for secondary
- **Accents**: Darker cyan (#0891B2) and purple remain vibrant
- **Borders**: Light gray borders (#E2E8F0) for clear separation

### How to Switch
Tap the theme toggle button in the app settings or any screen with theme support. The app will remember your preference.

## 2. Analog Gauge Display Mode

### Purpose
Classic analog gauges provide a familiar interface for technicians who prefer traditional dial-style instruments. The needle movement provides quick visual feedback.

### Features
- **Round Dial Design**: Classic circular gauge with 240° sweep
- **Animated Needle**: Red needle indicates current reading
- **Tick Marks**: Major and minor tick marks for precise reading
- **Color-Coded**: Low side (cyan) and High side (red) match digital mode
- **Easy Toggle**: Switch between digital and analog modes instantly

### Technical Details
- **Low Side Range**: -30 to 150 PSI (suitable for suction pressure and vacuum)
- **High Side Range**: 0 to 500 PSI (suitable for discharge pressure)
- **Custom Painter**: Efficient rendering using Flutter's CustomPainter
- **Theme Aware**: Tick marks and rings adapt to light/dark theme

### How to Use
1. Open the Gauges screen
2. Tap the gauge icon in the app bar (looks like a speedometer)
3. Gauges will switch between digital boxes and analog dials
4. Your preference is saved automatically

## 3. Scale Auto-Display on Gauge Screen

### Purpose
When charging refrigerant, techs need to see both gauge readings and scale weight simultaneously. The scale automatically appears when connected, eliminating the need to switch screens.

### Features
- **Auto-Show/Hide**: Scale widget automatically appears when scale connects
- **Smart Positioning**: Overlays at the bottom, doesn't block gauge readings
- **Connection Status**: Shows signal strength bars (cellular icon)
- **Battery Level**: Displays scale battery percentage and icon
- **Weight Memory**: Remembers last known weight when disconnected
- **Seamless Reconnection**: Restores connection when back in range
- **Visual Feedback**: Gradient background indicates connection status
  - Full color: Connected and live
  - Grayed out: Disconnected, showing last known weight

### Information Displayed
- **Scale Name**: Identifies which scale is connected (e.g., "Wey-Tek HD")
- **Current Weight**: Large, easy-to-read weight in ounces
- **Connection Icon**: Signal strength indicator
- **Battery Status**: Icon and percentage
- **Last Known Weight Label**: Shows when displaying cached weight

### Technical Details
- **Automatic Detection**: Listens for scale connections via Bluetooth
- **Weight Preservation**: Stores last weight in memory (not persistent storage)
- **Calibration Handling**: Weight accuracy maintained across disconnections
- **Multi-Scale Support**: Works with all supported scale types (Wey-Tek, etc.)

### Usage Scenario
1. Open Gauges screen while working on a unit
2. Turn on your Bluetooth scale
3. Scale widget automatically appears at bottom
4. Walk inside to check evaporator - scale disconnects but shows last weight
5. Walk back outside - scale reconnects and updates weight
6. No need to switch screens or manually connect

## Implementation Details

### Files Modified
1. **lib/widgets/gradient_scaffold.dart**
   - Added light theme colors
   - Implemented dynamic color system
   - Added theme update methods

2. **lib/main.dart**
   - Updated theme loading to refresh AppColors
   - Ensures immediate theme application

3. **lib/tools/screens/gauge_screen.dart**
   - Added GaugeDisplayMode enum
   - Implemented analog gauge widget
   - Added scale overlay widget
   - Created custom painter for analog dial
   - Integrated scale connection listeners

### State Management
- **Theme**: Stored in SharedPreferences ('isDarkTheme')
- **Gauge Mode**: Stored in SharedPreferences ('gaugeDisplayMode')
- **Scale Weight**: Stored in memory during session
- **Scale Connection**: Real-time via BluetoothService

### Performance Considerations
- Analog gauge uses efficient CustomPainter
- Scale overlay only renders when scale is connected or recently disconnected
- Theme colors updated via static methods (no widget rebuilds)
- Minimal battery impact from Bluetooth listeners

## User Benefits

### For Outdoor Work
- **Light Theme**: Easily read screen in bright sunlight on roof or by condenser
- **High Contrast**: No squinting to see pressure readings
- **Quick Glance**: Analog gauges provide instant visual feedback

### For Refrigerant Charging
- **One Screen**: See gauges and scale simultaneously
- **No Navigation**: Scale appears automatically when needed
- **Work Freely**: Move around without losing scale connection status
- **Memory**: Last weight preserved when briefly out of range

### For Traditional Techs
- **Familiar Interface**: Analog gauges match physical manifolds
- **Visual Movement**: Needle sweep indicates pressure changes
- **Instant Recognition**: No learning curve for dial-style gauges

## Future Enhancements
- Signal strength from actual RSSI values (currently simulated)
- Scale unit conversion (oz/lb/kg) in overlay
- Tare function accessible from overlay
- Analog gauge color zones (normal/warning/danger)
- Scale target weight indicator on overlay
- Sound alerts for scale disconnect/reconnect
