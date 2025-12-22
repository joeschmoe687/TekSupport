# Professional-Grade BLE Sniffer - Feature Documentation

## 🎯 Overview

The BLE Sniffer has been transformed into a professional-grade tool that can accurately scan and decode data from **ANY** Bluetooth HVAC tool, even completely unknown brands. It now includes AI-powered analysis and one-click profile generation.

## 🆕 What's New

### 1. Smart Device Classification

Every device scanned gets automatically classified using multi-factor analysis:

- **Name Analysis**: Keywords like "temp", "pressure", "scale" etc.
- **Service UUIDs**: Known HVAC service patterns
- **Manufacturer Data**: Detects Fieldpiece (0x5046), Testo (0x02E1), etc.
- **MAC Address OUI**: Identifies chip manufacturers (TI, Nordic, ESP32)
- **Connectivity Type**: GATT vs Broadcast-only detection

**Result**: Confidence score + device category + specific model guess

**Visible in UI**: AI classification badge on every scanned device with confidence level

### 2. Automatic Data Pattern Recognition

Once connected, the sniffer automatically analyzes incoming data streams:

- **Tests 100+ interpretations** per packet (int16/int32/float32, LE/BE, all divisors)
- **Categorizes values** into sensor types (temp, pressure, humidity, airflow, etc.)
- **Scores by consistency** across multiple packets
- **Detects stability** (low variance = accurate reading)
- **Timing analysis** (frequency, jitter)
- **Checksum detection** (XOR, SUM, 2's complement)

**Result**: Top 5 parsing suggestions with confidence scores

**Visible in log**: 💡 Smart suggestions show up automatically after 5 packets

### 3. One-Click Profile Generation

The "Save Profile" button now generates production-ready code:

```dart
// BEFORE (old generator):
// - Generic template
// - Manual adjustments needed
// - Trial and error to find right format

// AFTER (smart generator):
// - Auto-detected manufacturer
// - Best parsing method selected
// - Alternative methods included
// - Integration guide generated
// - Confidence indicators
// - Ready to paste and use!
```

**What it generates**:
1. Complete `DeviceProfile` entry
2. Parsing function with correct byte offsets, endianness, divisor
3. Alternative parsing methods (top 3 suggestions)
4. Integration guide with step-by-step instructions
5. Troubleshooting tips

### 4. Real-Time Intelligence

While data streams, you see:

```
📡 DATA [961f0005-d2d6-43e3-a417-3bb8217e0e01]:
  Hex: 1A 04 00 00 ...
  Raw: [26, 4, 0, 0, ...]
  💡 Airflow Fpm: 1050.00 (92% confidence)
  💡 Temperature Fahrenheit: 68.50 (87% confidence)
  
🧠 SMART ANALYSIS: Detected int16_le_div1 with 92% confidence
   Best match: Airflow Fpm at Bytes [0-1]: uint16 LITTLE ENDIAN
   Update rate: 10.2 Hz (98 ms ± 3.2 ms)
   Checksum detected: XOR at byte 13
```

## 📚 New Services/Classes

### 1. `BlePatternAnalyzer`

**Purpose**: Analyzes data packets to find patterns

**Key Methods**:
- `analyzeDataStream(packets)` - Main analysis function
- `detectChecksum(packet)` - Find checksums
- `analyzeTiminginfo(timestamps)` - Frequency analysis

**Output**: `DataInterpretation` with suggestions ranked by confidence

### 2. `SmartDeviceClassifier`

**Purpose**: Identifies device type from advertisement data

**Key Methods**:
- `classifyDevice()` - Main classification function
- Returns `DeviceClassification` with category and confidence

**Categories Detected**:
- Temperature Probe
- Pressure Probe
- Refrigerant Scale
- Airflow Meter
- Clamp Meter
- Vacuum Gauge
- Manifold Gauge
- Psychrometer
- Thermal Imager

### 3. `ProfileGeneratorService`

**Purpose**: Generates production-ready code

**Key Methods**:
- `generateProfile()` - Basic profile code
- `generateProfileWithAlternatives()` - With alternative methods
- `generateIntegrationGuide()` - Complete documentation

**Output**: Ready-to-paste Dart code

## 🎨 UI Enhancements

### Scan Screen

- **AI Badge**: Shows classification with confidence (e.g., "AI: Temperature Probe (High)")
- **Color Coding**: 
  - Green = High confidence (≥70%)
  - Orange = Medium confidence (30-69%)
  - Hidden if confidence <30%

### Log Console

- **Smart Suggestions**: 💡 icons show live interpretations
- **Analysis Results**: 🧠 icons show pattern detection
- **Timing Info**: Update rates displayed automatically
- **Checksum Info**: Shows detected checksum types

### Profile Generator Modal

- **Pre-filled Fields**: Uses AI classification results
- **Smart Defaults**: Auto-selects manufacturer, type, unit
- **One-Click Copy**: Generates and copies complete code

## 🚀 Usage Guide

### For Known Devices

1. **Scan** → Device appears with AI classification badge
2. **Connect** → Automatic analysis starts
3. **Wait 10-20 seconds** → Let patterns stabilize
4. **Save Profile** → Get production-ready code
5. **Paste** into `device_registry.dart`
6. **Done!**

### For Unknown Devices

Same as above! The smart analysis works even better with unknown devices:

1. AI classification gives you a starting point
2. Pattern analysis finds the data automatically
3. Profile generator creates multiple parsing options
4. Integration guide tells you exactly what to do

### Best Practices

**For accurate analysis:**
- Let device stream data for at least 10-20 seconds
- Vary the reading if possible (change temp, apply pressure, etc.)
- More packets = better confidence scores
- Check the log for "SMART ANALYSIS" confirmations

**For unknown devices:**
- Pay attention to AI confidence level
- If <50%, try alternative parsing methods
- Use manufacturer data hex dump to verify patterns
- Compare with manufacturer's app readings

## 📊 Confidence Scoring

### Device Classification

| Score | Label | Meaning |
|-------|-------|---------|
| ≥80% | Very High | Almost certainly correct |
| 60-79% | High | Likely correct, verify readings |
| 40-59% | Medium | Possible, test thoroughly |
| 20-39% | Low | Uncertain, try alternatives |
| <20% | (hidden) | Not shown to user |

### Pattern Analysis

Similar scoring, but based on:
- **40%** Average confidence of value range matches
- **30%** Consistency across packets
- **30%** Stability (low variance)

## 🔧 Technical Details

### Pattern Detection Algorithm

1. **Extract Features**: For each packet, try all byte offsets
2. **Test Formats**: int16/int32/float32, LE/BE, ÷1/÷10/÷100/÷1000
3. **Categorize Values**: Check if value fits typical sensor ranges
4. **Score Confidence**: Gaussian distribution around typical values
5. **Group Results**: Combine same format across packets
6. **Rank by Score**: Consistency + stability + confidence

### Device Classification Algorithm

1. **Extract Features**:
   - Name keywords
   - Service UUIDs
   - Manufacturer IDs
   - MAC OUI
   - Connectivity type

2. **Calculate Scores**: Each category gets points from features
3. **Normalize**: Scale to 0-100%
4. **Select Top**: Highest scoring category (min 20% threshold)

### Checksum Detection

Tests 3 common types:
- **XOR**: All bytes XOR'd together
- **SUM**: Byte sum modulo 256
- **2's Complement**: (~sum + 1) & 0xFF

Returns type + position if confidence >80%

## 📝 Code Examples

### Using Pattern Analyzer

```dart
final analyzer = BlePatternAnalyzer();
final packets = [[0x1A, 0x04], [0x1B, 0x04], [0x1C, 0x04]];
final analysis = analyzer.analyzeDataStream(packets);

print('Confidence: ${analysis.confidence}');
print('Format: ${analysis.detectedFormat}');
for (final suggestion in analysis.suggestions) {
  print('${suggestion.categoryDisplay}: ${suggestion.value}');
  print('Code: ${suggestion.generateDartCode("parseReading")}');
}
```

### Using Smart Classifier

```dart
final classification = SmartDeviceClassifier.classifyDevice(
  deviceName: 'T115i',
  serviceUuids: [Guid('0000fff0-...')],
  manufacturerData: {0x02E1: [...]},
  macAddress: 'C7:16:86:...',
  connectable: true,
);

print(classification.summary); // "Testo AG Temperature Probe - High Confidence"
```

### Using Profile Generator

```dart
final code = ProfileGeneratorService.generateProfileWithAlternatives(
  profileKey: 'unknown_sensor',
  displayName: 'Unknown Sensor',
  classification: deviceClassification,
  serviceUuid: '0000fff0-...',
  dataCharUuid: '0000fff2-...',
  parseSuggestions: analysisResults.suggestions,
  unit: '°F',
);

print(code); // Ready-to-paste Dart code
```

## 🐛 Troubleshooting

### "Low confidence classification"

**Cause**: Device doesn't match known patterns
**Solution**: 
1. Check manufacturer data hex dump
2. Look for similar devices in device_registry.dart
3. Use alternative parsing methods
4. Capture more data packets

### "No smart analysis appearing"

**Cause**: Not enough packets captured yet
**Solution**: Wait for device to stream at least 5 packets

### "Generated code doesn't work"

**Cause**: Analysis chose wrong interpretation
**Solution**:
1. Check alternative parsing methods in generated code
2. Try different byte offsets
3. Verify endianness (LE vs BE)
4. Test different divisors

### "Wrong device type detected"

**Cause**: Similar advertisement patterns
**Solution**:
1. Check AI confidence level
2. Manually override in profile generator
3. Look at service UUIDs for clues

## 📈 Future Enhancements

- [ ] Wireshark export format
- [ ] CSV data export
- [ ] Capture replay for testing
- [ ] Auto-generated protocol docs
- [ ] Device knowledge base
- [ ] More checksum algorithms
- [ ] Packet structure visualization
- [ ] Multi-device comparison view

## 🎓 Learning Resources

**For understanding BLE protocols:**
- Bluetooth SIG specifications
- Nordic DevAcademy BLE course
- HCI snoop log analysis

**For HVAC sensor ranges:**
- Temperature: -50 to 200°F typical
- Pressure: -30 to 800 psig typical
- Humidity: 0 to 100% RH
- Airflow: 0 to 10000 FPM typical

**For common data formats:**
- Most HVAC tools use int16 little-endian
- Typical divisors: ÷10 or ÷100
- Float32 less common but occasionally used
- Checksums: XOR most common

## 💡 Tips & Tricks

1. **Maximize confidence**: Vary the reading during capture
2. **Debug faster**: Watch the log for live suggestions
3. **Verify accuracy**: Compare with manufacturer's app
4. **Save bandwidth**: Only sync important captures to Firebase
5. **Reuse profiles**: Check device_registry.dart before creating new ones

---

**Built with** ❤️ **for HVAC technicians**

Making device integration as easy as scan → connect → copy → paste!
