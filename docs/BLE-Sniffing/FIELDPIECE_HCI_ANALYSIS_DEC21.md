# Fieldpiece HCI Snoop Log Analysis - December 21, 2025

## Source Data
- **Log File:** `fieldpiece_bugreport/FS/data/log/bt/btsnoop_hci.log` (3.2MB)
- **Backup Log:** `fieldpiece_bugreport/FS/data/log/bt/btsnoop_hci.log.last` (6.8MB)
- **Capture Date:** December 21, 2025 (via Job Link app)

---

## Devices Captured

| Device Type | FP Code | Model# | Packet Length | Description |
|-------------|---------|--------|---------------|-------------|
| Temp Clamp | **FPBF** | 8975 | 22 bytes (0x16) | Pipe/Line Temperature Clamp |
| Pressure Probe | **FPBG** | 2975/2976 | 28 bytes (0x1C) | Refrigerant Pressure Probe |
| Psychrometer | **FPBH** | 5699 | 30 bytes (0x1E) | Wet/Dry Bulb + RH |
| SC680 Meter | **FPCB** | SC680 | 30 bytes (0x1E) | Main Display Unit |

---

## Manufacturer Data Format

All Fieldpiece devices use **ADV_NONCONN_IND** (non-connectable advertisements) with manufacturer-specific data:
- **Manufacturer ID:** `0x5046` (little-endian "FP" = Fieldpiece)
- **Packet Type:** `0x10` (ADV_NONCONN_IND)

### Common Header Structure
```
Byte 0-1:  0xFF 0x46 0x50  = Manufacturer data flag + "FP" (Fieldpiece)
Byte 2-3:  Device Type Code (e.g., "BH" = 0x42 0x48 for psychrometer)
Byte 4:    Unknown (0x22 or 0x23 observed)
Byte 5:    Unknown (varies)
Byte 6-7:  Model Number (e.g., 0x5699 for psychrometer)
Byte 8:    Unknown (0x04 observed - maybe version?)
Byte 9:    Battery level? (0x20 = good?)
Byte 10-11: Unknown
```

---

## FPBF - Temperature Clamp (Model 8975)

**Packet Length:** 22 bytes (0x16ff)

### Sample Packets
```
4650 4246 2212 8975 0320 2211 28a8 0210 f303 0b17
4650 4246 2212 8975 0220 2211 28a8 0210 f303 0b18
```

### Byte Analysis
| Offset | Hex | Interpretation |
|--------|-----|----------------|
| 0-1 | 46 50 | "FP" Manufacturer ID |
| 2-3 | 42 46 | "BF" Device Type |
| 4 | 22 | Header byte |
| 5 | 12 | Unknown |
| 6-7 | 89 75 | Model: 8975 |
| 8 | 03/02 | Unknown (varies) |
| 9 | 20 | Battery? (good) |
| 10-11 | 22 11 | Unknown |
| 12-13 | 28 a8 | **TEMPERATURE DATA?** (0xa828 = 43048 / 1000 = 43°C = 109°F?) |
| 14 | 02 | Unknown |
| 15 | 10 | Unknown |
| 16-17 | f3 03 | Unknown (constant) |
| 18 | 0b | Unknown |
| 19 | 17/18 | Sequence counter? |

**Temperature Hypothesis:**
- Bytes 12-13: `28 a8` → little-endian uint16 = 0xa828 = 43048
- Divide by 1000 → 43.048°C = ~109°F
- OR divide by 100 → 430.48 (unlikely)
- Need more varied readings to confirm

---

## FPBG - Pressure Probe (Model 2975/2976)

**Packet Length:** 28 bytes (0x1Cff)

### Sample Packets
```
4650 4247 2212 2975 1420 2211 2877 008b 058e 0000 0010 ff03 1523
4650 4247 2212 2975 1420 2211 2876 008b 058e 0000 0010 ff03 1524
```

### Byte Analysis
| Offset | Hex | Interpretation |
|--------|-----|----------------|
| 0-1 | 46 50 | "FP" Manufacturer ID |
| 2-3 | 42 47 | "BG" Device Type |
| 4 | 22 | Header byte |
| 5 | 12 | Unknown |
| 6-7 | 29 75 | Model: 2975 |
| 8 | 14 | Unknown |
| 9 | 20 | Battery? |
| 10-11 | 22 11 | Unknown |
| 12-13 | 28 77/76 | **PRESSURE DATA?** (varies slightly - ~0 PSI when static?) |
| 14-15 | 00 8b | Unknown |
| 16-17 | 05 8e | Unknown |
| 18-21 | 00 00 00 10 | Padding? |
| 22-23 | ff 03 | Unknown constant |
| 24 | 15 | Unknown |
| 25 | 23/24 | Sequence counter |

**Pressure Hypothesis:**
- From screenshot: Suction Pressure = 0.0 psig
- Bytes 12-13 = 0x2877 = 10359 decimal
- If this is offset from 0, the zero point might be ~10359
- Need readings with actual pressure to confirm formula

---

## FPBH - Psychrometer (Model 5699)

**Packet Length:** 30 bytes (0x1Eff)

### Sample Packets (with variations)
```
4650 4248 2307 5699 0420 2308 16b4 022d 029d 01bf 0133 0910 f403 131b
4650 4248 2307 5699 0420 2308 16b3 022d 029f 01c0 0133 0910 f403 131c
4650 4248 2307 5699 0420 2308 16a9 0227 02a6 01bb 010f 0910 f403 132f
```

### Byte Analysis (MOST COMPLETE)
| Offset | Hex | Interpretation |
|--------|-----|----------------|
| 0-1 | 46 50 | "FP" Manufacturer ID |
| 2-3 | 42 48 | "BH" Device Type (Psychrometer) |
| 4 | 23 | Header byte |
| 5 | 07 | Unknown |
| 6-7 | 56 99 | Model: 5699 |
| 8 | 04 | Unknown |
| 9 | 20 | Battery? |
| 10-11 | 23 08 | Unknown |
| **12-13** | **16 b4** | **DRY BULB TEMP** (0xb416 = 46102 → /1000 = 46.1°C = 115°F? OR raw °F×100?) |
| 14 | 02 | Separator? |
| **15-16** | **2d 02** | **WET BULB TEMP?** (0x022d = 557 → 55.7°F matches screenshot!) |
| 17-18 | 9d 01 / 9f 01 | Unknown (varies slightly) |
| 19 | bf / c0 | Unknown |
| **20-21** | **01 33** | **HUMIDITY?** (0x3301 = 13057... or 0x133 = 307 → 30.7%? Screenshot shows 41.6%) |
| 22 | 09 | Unknown |
| 23 | 10 | Unknown |
| 24-25 | f4 03 | Unknown constant |
| 26 | 13 | Unknown |
| 27 | 1b/1c | Sequence counter |

### Screenshot Comparison (Dec 21, 2025)
From Fieldpiece Job Link app screenshot:
- **Return Dry Bulb:** 69.0°F
- **Return Wet Bulb:** 55.7°F
- **Return Relative Humidity:** 41.6%
- **Liquid Temperature:** 68.0°F
- **Suction Pressure:** 0.0 psig

**Correlation Analysis:**
- Wet Bulb `55.7°F` → Bytes 15-16 should encode this
  - `0x022d` = 557 → ÷10 = **55.7°F** ✓
- Dry Bulb `69.0°F` → Bytes 12-13 should encode this
  - `0x16b4` = 5812 → ÷10 = 581.2? (No)
  - `0xb416` = 46102 → ÷100 = 461? (No)
  - Likely different format or offset

---

## FPCB - SC680 Meter

**Packet Length:** 30 bytes (0x1Eff)

### Sample Packets
```
4650 4342 2209 0169 1320 2209 0600 0001 1a00 00d0 8a02 1900 00...
4650 4342 2209 0169 1320 2209 06ff 7f01 1100 00fa 0800 00...
4650 4342 2209 0169 1320 2209 0617 0001 0200 00...
```

### Byte Analysis
| Offset | Hex | Interpretation |
|--------|-----|----------------|
| 0-1 | 46 50 | "FP" Manufacturer ID |
| 2-3 | 43 42 | "CB" Device Type (SC680) |
| 4 | 22 | Header |
| 5 | 09 | Unknown |
| 6-7 | 01 69 | Model variant? (0x6901 = 26881) |
| 8 | 13 | Unknown |
| 9 | 20 | Battery? |
| 10-11 | 22 09 | Unknown |
| 12+ | Variable | Active channel data |

**Note:** SC680 acts as display/hub and broadcasts aggregated data from connected probes.

---

## Key Findings for Implementation

### 1. Detection Method
```dart
// Scan for manufacturer data with Fieldpiece ID
FlutterBluePlus.startScan(
  withMsd: [MsdFilter(0x5046)],  // "FP" manufacturer ID
);
```

### 2. Device Type Identification
```dart
String getFieldpieceDeviceType(List<int> msd) {
  if (msd.length < 4) return 'Unknown';
  String code = String.fromCharCodes([msd[2], msd[3]]);
  switch (code) {
    case 'BF': return 'Temp Clamp (8975)';
    case 'BG': return 'Pressure Probe (2975)';
    case 'BH': return 'Psychrometer (5699)';
    case 'CB': return 'SC680 Meter';
    default: return 'Unknown ($code)';
  }
}
```

### 3. Temperature Parsing (Needs Verification)
```dart
// For psychrometer wet bulb (bytes 15-16)
double wetBulbF = ((msd[16] << 8) | msd[15]) / 10.0;

// For temp clamp (bytes 12-13) - NEEDS MORE DATA
double tempF = ((msd[13] << 8) | msd[12]) / ???;  // divisor unknown
```

### 4. Humidity Parsing (Needs Verification)
```dart
// For psychrometer - exact byte position TBD
double humidity = ???;  // Need more varied readings
```

---

## Next Steps

1. **Capture more varied readings** - Need temperature changes to confirm byte positions
2. **Test pressure readings** - Capture with actual refrigerant pressure
3. **Confirm humidity encoding** - Current hypothesis doesn't match screenshot
4. **Implement passive scanner** - Add `withMsd` filter to BLE scan
5. **Create device registry entries** - Add Fieldpiece profiles with broadcast-only flag

---

## Raw Packet Examples (for reference)

### FPBF (Temp Clamp)
```
16ff 4650 4246 2212 8975 0320 2211 28a8 0210 f303 0b17
```

### FPBG (Pressure)
```
1cff 4650 4247 2212 2975 1420 2211 2877 008b 058e 0000 0010 ff03 1523
```

### FPBH (Psychrometer)
```
1eff 4650 4248 2307 5699 0420 2308 16b4 022d 029d 01bf 0133 0910 f403 131b
```

### FPCB (SC680)
```
1eff 4650 4342 2209 0169 1320 2209 0600 0001 1a00 00d0 8a02 1900
```
