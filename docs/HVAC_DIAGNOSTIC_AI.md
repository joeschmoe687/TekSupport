# HVAC Diagnostic AI & Machine Learning System

## Overview
The HVAC Diagnostic AI system provides real-time intelligent analysis of HVAC system readings, alerts technicians to potential issues, and guides them through troubleshooting with step-by-step instructions.

## Architecture

### Core Components

#### 1. Data Collection (`MLDataService`)
**Location:** `lib/tools/services/ml_data_service.dart`

Collects and uploads diagnostic readings to Firebase for ML training.

**Features:**
- Batch readings during jobs
- Privacy controls (opt-in/opt-out)
- Automatic data anonymization
- "Before" and "after" reading capture
- Firebase sync on job completion

**Usage:**
```dart
final mlService = MLDataService();
await mlService.init();

// Capture a reading
final reading = mlService.captureReading(
  systemType: JobType.airConditioning,
  refrigerant: Refrigerant.r410a,
  suctionPressure: 120.0,
  dischargePressure: 380.0,
  superheat: 12.5,
  subcool: 10.2,
);

// Upload immediately or batch
await mlService.uploadReading(reading);
// OR
await mlService.uploadPendingReadings(); // Upload all batched
```

#### 2. Knowledge Base (`HvacKnowledgeBase`)
**Location:** `lib/tools/services/hvac_knowledge_base.dart`

Industry-standard expected ranges for different HVAC systems.

**Supported Systems:**
- Residential AC (R-410A, R-22, R-407C)
- Heat Pumps (R-410A, R-22)
- Walk-in Coolers (R-404A, R-134A)
- Walk-in Freezers (R-404A)
- Ice Machines (R-404A)

**Features:**
- Expected pressure ranges (low/high side)
- Expected superheat ranges (TXV vs fixed orifice)
- Expected subcool ranges
- Ambient temperature compensation
- Metering device detection (TXV vs fixed)

**Usage:**
```dart
final kb = HvacKnowledgeBase();

// Get expected pressure range
final pressureRange = kb.getExpectedPressureRange(
  systemType: JobType.airConditioning,
  refrigerant: Refrigerant.r410a,
  isHighSide: true,
  ambientTemp: 95.0, // Optional
);
// Returns: PressureRange(min: 350, max: 425, target: 385)

// Get expected superheat
final superheatRange = kb.getExpectedSuperheat(
  systemType: JobType.airConditioning,
  isFixedOrifice: false, // TXV system
);
// Returns: SuperheatRange(min: 10, max: 15, target: 12)
```

#### 3. Diagnostic Engine (`DiagnosticEngine`)
**Location:** `lib/tools/services/diagnostic_engine.dart`

Real-time analysis of system readings with intelligent alerts.

**Features:**
- Out-of-range detection (critical/warning/normal)
- Contextual alert messages
- Possible cause identification
- Combined symptom analysis (pattern recognition)
- Smart troubleshooting recommendations

**Alert Levels:**
- 🟢 **Normal**: Within expected range
- 🟡 **Warning**: 10-20% deviation - needs attention
- 🔴 **Critical**: >20% deviation - likely system fault

**Detected Patterns:**
- Low charge (low pressures + high superheat + low subcool)
- Overcharge (high pressures + low superheat + high subcool)
- TXV flooding (high suction + very low superheat)
- Restricted metering device (low suction + very high superheat)

**Usage:**
```dart
final engine = DiagnosticEngine();

final result = engine.analyze(
  systemType: JobType.airConditioning,
  refrigerant: Refrigerant.r410a,
  suctionPressure: 95.0, // PSI
  dischargePressure: 380.0, // PSI
  superheat: 25.0, // °F
  subcool: 4.0, // °F
);

// Check results
if (result.hasIssues) {
  print('Overall status: ${result.overallStatus}');
  for (final alert in result.alerts) {
    print('Alert: ${alert.message}');
    print('Possible causes:');
    for (final cause in alert.possibleCauses) {
      print('  - $cause');
    }
  }
  
  // Advanced pattern recognition
  if (result.combinedDiagnostic != null) {
    print('Pattern detected: ${result.combinedDiagnostic}');
  }
}
```

## UI Components

### 1. Diagnostic Card
**Location:** `lib/tools/widgets/diagnostic_card.dart`

Displays current system status with color-coded alerts.

**Features:**
- Green: System normal
- Yellow: Warning - needs attention
- Red: Critical issue detected
- Shows top 3 possible causes per alert
- "Fix" button opens troubleshooting guide
- Combined diagnostic display for pattern recognition

### 2. Troubleshooting Sheet
**Location:** `lib/tools/widgets/troubleshooting_sheet.dart`

Bottom sheet with step-by-step troubleshooting guidance.

**Features:**
- **Beginner Mode**: Detailed explanations with tooltips
- **Expert Mode**: Concise bullet points
- Checkable steps (track progress)
- Caution warnings where applicable
- Dynamic troubleshooting paths based on symptoms

**Troubleshooting Paths:**
1. **Low Charge Path**: Leak detection → repair → charging
2. **Overcharge Path**: Recovery → monitoring
3. **TXV Flooding Path**: Sensing bulb → adjustment → replacement
4. **General Path**: Documentation → basics → specific fixes

### 3. Settings Integration
**Location:** `lib/screens/settings_screen.dart`

Privacy controls for ML data sharing.

**Features:**
- Toggle ML data sharing on/off
- Privacy information display
- Persists preference across sessions

### 4. Gauge Screen Integration
**Location:** `lib/tools/screens/gauge_screen.dart`

Full integration of diagnostic system into main gauge screen.

**Features:**
- Real-time diagnostic card at top of screen
- Updates automatically when readings change
- "Capture Reading" floating action button
- One-tap access to troubleshooting guide

## Data Model

### HvacReading
**Location:** `lib/tools/models/hvac_reading.dart`

```dart
class HvacReading {
  final String id;
  final String? jobId;
  final String? technicianId; // Anonymized if privacy enabled
  final DateTime timestamp;
  
  // System info
  final JobType systemType;
  final Refrigerant refrigerant;
  final String? equipmentInfo; // Nameplate data
  final bool? isFixedOrifice;
  
  // Readings
  final double? suctionPressure; // PSI
  final double? dischargePressure; // PSI
  final double? suctionLineTemp; // °F
  final double? liquidLineTemp; // °F
  final double? supplyAirTemp; // °F
  final double? returnAirTemp; // °F
  final double? ambientTemp; // °F
  final double? superheat; // °F
  final double? subcool; // °F
  
  // Outcome
  final ReadingOutcome? outcome; // pass/adjusted/failed/unknown
  final String? technicianNotes;
  final List<String>? adjustmentsMade;
  
  final bool isAnonymized; // Always true
}
```

## Firebase Structure

### Collection: `ml_hvac_readings`

**Document Structure:**
```json
{
  "jobId": "optional_job_id",
  "technicianId": "anonymized_or_null",
  "timestamp": "2024-12-21T10:30:00Z",
  "systemType": "airConditioning",
  "refrigerant": "r410a",
  "equipmentInfo": "Carrier 24ACC6",
  "isFixedOrifice": false,
  "suctionPressure": 120.5,
  "dischargePressure": 380.2,
  "suctionLineTemp": 55.3,
  "liquidLineTemp": 95.8,
  "supplyAirTemp": 58.2,
  "returnAirTemp": 78.5,
  "ambientTemp": 95.0,
  "superheat": 12.5,
  "subcool": 10.2,
  "outcome": "pass",
  "technicianNotes": "System operating normally",
  "adjustmentsMade": [],
  "isAnonymized": true
}
```

**Security Rules:**
```javascript
// In Firebase Console -> Firestore -> Rules
match /ml_hvac_readings/{reading} {
  allow read: if request.auth != null && 
              (request.auth.token.role == 'admin' || 
               request.auth.token.role == 'tech');
  allow create: if request.auth != null && 
                request.resource.data.isAnonymized == true;
}
```

## Usage Examples

### Example 1: Capturing a Reading on Gauge Screen
```dart
// User opens gauge screen
// Bluetooth sensors connected and streaming data
// Diagnostic card shows real-time status

// User taps "Capture" button
await _captureReadingForML();
// → Reading saved to Firebase (if sharing enabled)
// → Snackbar confirms upload
```

### Example 2: Detecting Low Charge
```dart
// System readings:
// Suction: 95 PSI (expected: 118-145)
// Discharge: 320 PSI (expected: 350-425)
// Superheat: 25°F (expected: 10-15)
// Subcool: 3°F (expected: 8-12)

final result = diagnosticEngine.analyze(...);
// → result.overallStatus = ReadingStatus.critical
// → result.combinedDiagnostic = "Classic LOW CHARGE pattern..."
// → result.alerts contains 4 alerts (suction, discharge, superheat, subcool)

// User taps "Fix" button
// → TroubleshootingSheet opens with low charge steps
// → Step 1: Verify symptoms
// → Step 2: Check for leaks
// → Step 3: Recover and weigh charge
// → Step 4: Add refrigerant slowly
// → Step 5: Verify final readings
```

### Example 3: Before/After Charging
```dart
// Capture "before" reading
final beforeReading = mlService.recordBeforeReading(
  systemType: JobType.airConditioning,
  refrigerant: Refrigerant.r410a,
  suctionPressure: 95.0,
  dischargePressure: 320.0,
  superheat: 25.0,
  subcool: 3.0,
);

// Technician adds refrigerant...

// Capture "after" reading
final afterReading = mlService.recordAfterReading(
  systemType: JobType.airConditioning,
  refrigerant: Refrigerant.r410a,
  suctionPressure: 130.0,
  dischargePressure: 385.0,
  superheat: 12.0,
  subcool: 10.0,
  adjustmentsMade: ['Added 2.5 lbs R-410A'],
  outcome: ReadingOutcome.adjusted,
);

// Upload both readings
await mlService.uploadPendingReadings();
```

## Privacy & Anonymization

**What Gets Stored:**
✅ Technical readings (pressures, temps, calculations)
✅ System type and refrigerant
✅ Equipment model (from nameplate)
✅ Timestamp
✅ Adjustments made (technical actions only)

**What NEVER Gets Stored:**
❌ Customer names
❌ Customer addresses
❌ Job locations (GPS coordinates)
❌ Phone numbers
❌ Personal identifiable information

**User Control:**
- Settings → "Share Diagnostic Data for ML"
- Toggle on/off at any time
- Preference persists across app sessions
- When disabled, readings are saved locally only

## Future Enhancements

### Phase 5: Advanced Learning
1. **Feedback Loop**
   - "Was this diagnosis correct?" prompt
   - Track technician corrections
   - Improve model based on real-world outcomes

2. **Regional Variations**
   - Learn patterns from different climates
   - Florida AC vs Minnesota heat pump behaviors
   - High altitude adjustments

3. **Equipment-Specific Profiles**
   - "Carrier 24ACC always runs 10 PSI higher"
   - Brand/model quirks database
   - Aggregate learning from fleet data

4. **Firebase ML Integration**
   - Train custom TensorFlow Lite model
   - On-device inference for faster diagnostics
   - Cloud training with aggregated data

### Phase 6: Enhanced UI
1. **History Graph**
   - Line chart showing readings over time during job
   - Visualize charging progress
   - Identify trends

2. **Before/After Comparison**
   - Side-by-side pressure comparison
   - Delta calculations
   - Visual confirmation of improvements

## Testing

### Manual Testing Checklist

**ML Data Collection:**
- [ ] Toggle ML sharing in Settings → verify persistence
- [ ] Capture reading on gauge screen → verify Firebase upload
- [ ] Disable ML sharing → verify no Firebase upload
- [ ] Check Firestore console for proper data structure

**Diagnostic Engine:**
- [ ] Low charge pattern (low pressures, high superheat, low subcool)
- [ ] Overcharge pattern (high pressures, low superheat, high subcool)
- [ ] TXV flooding (high suction, low superheat)
- [ ] Normal readings (all green)

**UI Components:**
- [ ] Diagnostic card displays correct status colors
- [ ] Troubleshooting sheet opens from "Fix" button
- [ ] Beginner/Expert mode toggle works
- [ ] Step checkboxes work
- [ ] Capture button appears when readings present

## Troubleshooting

### Issue: Diagnostic card not showing
**Solution:** Ensure readings are being received from Bluetooth sensors. Diagnostic card only appears when `_hasReceivedData = true`.

### Issue: ML readings not uploading
**Solution:** 
1. Check ML sharing is enabled in Settings
2. Verify Firebase connection (check other Firestore operations)
3. Check console for error messages
4. Verify `ml_hvac_readings` collection exists in Firestore

### Issue: Incorrect diagnostic alerts
**Solution:**
1. Verify refrigerant type is correct
2. Check job type matches actual system
3. Ensure sensors are properly calibrated
4. Ambient temp compensation requires ambient sensor

## Performance Considerations

- Diagnostic analysis runs on every reading update (~1x per second)
- Analysis is lightweight (no network calls)
- Firebase uploads are async and non-blocking
- Batch uploads on job completion to minimize network traffic
- Local caching of privacy preferences

## Security Considerations

- All ML data is anonymized before storage
- Technician IDs are optional and obfuscated
- No customer PII ever transmitted
- Firebase security rules enforce data privacy
- Users can opt-out at any time

## Support

For issues or questions:
1. Check this documentation
2. Review inline code comments
3. Check Firebase console for data
4. Contact development team

---

**Last Updated:** December 21, 2024
**Version:** 1.0.0
**Author:** TekNeck Development Team
