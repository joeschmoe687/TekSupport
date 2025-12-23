# BLE Sniffing Data Repository

> **Central location for all Bluetooth Low Energy protocol analysis and device discovery**
> 
> **Primary Test Device:** Samsung SM S931U (RFCY518ZA0Y) • Android 16 (API 36)

---

## Quick Start (Samsung S931U)

```bash
cd hvac_support_app

# Pull HCI snoop log
./scripts/pull_ble_logs.sh s931u

# Pull + export to CSV
./scripts/pull_ble_logs.sh s931u --csv

# Pull + full bugreport
./scripts/pull_ble_logs.sh s931u --full
```

See [QUICK_START.sh](QUICK_START.sh) for full command reference.

---

## Quick Commands - HCI Snoop Log Pull (Legacy)

```bash
cd docs/BLE-Sniffing

# Pull bugreport from Android phone
adb bugreport bugreport_$(date +%Y%m%d_%H%M%S).zip

# Extract
unzip -o bugreport_*.zip -d extracted_folder/

# HCI log location after extraction:
# extracted_folder/FS/data/log/bt/btsnoop_hci.log

# Parse ABM-200 data
python3 parse_abm200.py extracted_folder/FS/data/log/bt/btsnoop_hci.log
```

---

## Purpose

This folder contains all BLE sniffing captures, analysis scripts, and extracted protocol data for HVAC tools. Use this as the reference when implementing new device support or debugging existing connections.

## Folder Structure

> **⚠️ IMPORTANT:** ALL BLE sniff-related files MUST go in `docs/BLE-Sniffing/`. 
> This includes bugreports, extracts, phone data, scripts, and any exported Firebase data.

```
docs/BLE-Sniffing/
├── README.md                    # This file (central docs)
├── scripts/                     # Analysis and comparison scripts
│   ├── pull_ble_logs.sh         # Automated HCI log extraction & CSV export
│   └── compare-firebase-sync.mjs  # Firebase vs local data comparison
├── phone-data/                  # Data pulled from phone via ADB
│   ├── btsnoop_hci_*.log        # Raw Bluetooth HCI packets (binary)
│   └── bugreport_*.zip          # Full Android bugreports
├── extracted_YYYY-MM-DD_*/      # Unzipped bugreport contents
│   └── FS/data/log/bt/btsnoop_hci.log
├── reports/                     # Human-readable exports & summaries
│   ├── hci_packets_*.csv        # CSV from tshark (HCI packet export)
│   ├── 2025-12-23-testo_*.tjf   # Testo device measurements (.tjf format)
│   └── *_BG_*.csv               # Fieldpiece device measurements (.csv format)
├── parse_[device].py            # Per-device analysis scripts
├── ABM-200/                     # Device-specific protocol docs
├── Testo/                       # Device-specific protocol docs
├── Fieldpiece/                  # Device-specific protocol docs
└── commands.md                  # Historical commands reference
```

### File Naming Conventions
- Bugreports: `bugreport_YYYYMMDD_HHMMSS.zip`
- Extracted folders: `extracted_YYYYMMDD_HHMMSS/` or `[device]_extracted/`
- HCI logs: `btsnoop_hci_YYYYMMDD_HHMMSS.log` (device tag: `s931u`)
- Phone exports: `ble_sniff_sessions.hive`

---

## Test Device Setup

### Primary Test Device: Samsung SM S931U
**Device ID:** RFCY518ZA0Y  
**OS:** Android 16 (API 36)  
**HCI Log Path:** `/sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log`

**Enable HCI Logging:**
1. Settings → About phone → Build number (tap 7× to unlock Developer Options)
2. Developer Options → **Bluetooth HCI snoop log** (toggle ON)
3. Reproduce BLE session (connect device, measure with Testo/Fieldpiece/ABM-200)
4. Pull logs using: `./scripts/pull_ble_logs.sh s931u`

**Verify Device Connected:**
```bash
adb devices
# Should show: RFCY518ZA0Y    device
```

**Check HCI Logging Status:**
```bash
adb shell getprop persist.bluetooth.hcidump  # Should return "1"
adb shell getprop ro.build.version.release   # Should return "16"
```

---

## Supported Devices

| Device | Status | Protocol Docs |
|--------|--------|---------------|
| Wey-Tek HD Scale | ✅ Complete | See `parse_weytek*.py` |
| Testo T115i (Temp) | ✅ Complete | Service fff0, chars fff1/fff2 |
| Testo T549i (Pressure) | ✅ Complete | Same as T115i |
| ABM-200 Airflow Meter | ✅ Captured | See below |
| CCS Airflow Meter | 🔄 Pending | Need capture |

### ABM-200 Airflow Meter (WeatherFlow / AAB / CPS)
**Verified Dec 19, 2025 via HCI Snoop Log Analysis (Samsung S931U)**

- **Manufacturer:** WeatherFlow (rebranded as AAB/CPS ABM-200)
- **Sensors:** Airflow velocity (FPM), Temperature, Humidity, Pressure
- **Data Service:** `961f0001-d2d6-43e3-a417-3bb8217e0e01`
- **Live Data Char:** `961f0005-d2d6-43e3-a417-3bb8217e0e01` (notify, ~10Hz)
- **14-byte packet format (VERIFIED):**
  ```
  Bytes 0-1:   Airflow velocity (uint16 LE, direct FPM)
  Bytes 2-3:   Unknown (garbage when velocity > 0)
  Bytes 4-5:   Unknown (garbage when velocity > 0)
  Bytes 6-7:   Unknown
  Bytes 8-9:   Humidity (uint16 LE ÷ 5.29 = %RH)
  Bytes 10-11: Temperature (uint16 LE × 1.6 = °F)
  Bytes 12-13: Pressure (uint16 LE × 0.0401463 = in/WC)
  ```
- **Device Info (180a):**
  - Manufacturer: "WeatherFlow"
  - Model: "ABM-200"
  - Firmware: "9"
  - Hardware: "r1"
- **Battery (180f):** Standard BLE battery service, char 2a19
- **Observed behavior:** Bytes 0-1 change 0→4800 when blowing on fan

## How to Capture BLE Data

### On Android Phone:
1. **Enable HCI Snoop Log:**
   - Settings → Developer Options → Enable Bluetooth HCI snoop log
   - Toggle Bluetooth off/on to start fresh capture

2. **Perform the capture:**
   - Open the manufacturer's app (Wey-Tek, Testo, etc.)
   - Connect to device and let it stream data
   - Interact with all features (tare, unit change, etc.)

3. **Generate bugreport:**
   ```bash
   adb bugreport bugreport.zip
   ```

4. **Extract HCI log:**
   ```bash
   unzip bugreport.zip -d extracted/
   # Log is at: extracted/FS/data/log/bt/btsnoop_hci.log
   ```

## Protocol Documentation

### Wey-Tek HD Scale
- **Service UUID:** `E3B744F3-4309-4A3A-B877-CCACD9EFB97D`
- **Data Handle:** 0x0111 (single char for read/write/notify)
- **Packet Format:** `aa aa aa aa [cmd] [flags] [data...] [checksum] 00`
- **Commands:**
  - `0x4C` (L) - Link/start streaming
  - `0x41` (A) - Acknowledge
  - `0x49` (I) - Init (response contains battery at byte 6, BCD encoded)
  - `0x4F` (O) - Tare/Zero ✅ Implemented
  - `0x55` (U) - Unit change
  - `0x57` (W) - Weight data
- **Battery:** In 0x49 response, byte 6 is BCD (0x82 = 82%)
- **App Features:**
  - Auto unit display: oz < 32oz, lb:oz ≥ 32oz
  - User-selectable: Auto/oz/lb:oz/kg
  - Zero/tare button sends 0x4F command

### Testo Smart Probes
- **Service UUID:** `0000fff0-0000-1000-8000-00805f9b34fb`
- **Write Char:** fff1 (commands)
- **Notify Char:** fff2 (data + battery)
- **Init Sequence:** Handshake → Stream → Measurement commands
- **Battery:** Sent as "BatteryLevel" ASCII string + value

---

## Device Export Formats

### Testo Tools (`.tjf` format)
**Source:** Testo app export  
**Content:** Binary device measurement format (vendor-specific)  

**Contains:**
- Timestamp (YYYY-MM-DD HH:MM:SS)
- Temperature (°C or °F)
- Pressure (psig, bar, or Pa depending on tool)
- Humidity (if applicable)
- Device ID/Serial
- Refrigerant type and color indicator

**Example metadata:**
```
Start Date: 12/23/2025
Start Time: 12:32:00 AM
Tool ID: 2975
Duration: 30 minutes
Interval: 1 min
Measurements: Time, Pressure(psig), Vapor Saturation(°F)
```

**How to export:**
1. Open Testo app
2. Select session/measurement
3. Export → Share → Save as file
4. Move to `docs/BLE-Sniffing/reports/`

---

### Fieldpiece Tools (`.csv` format)
**Source:** Fieldpiece app or device SD card  
**Content:** Human-readable comma-separated values  

**Contains:**
- Metadata header: Start/End dates, duration, interval, Tool ID, refrigerant type
- Columns: Time, Pressure (psig), Vapor Saturation (°F)
- Data rows: 1-minute intervals

**Example export:**
```
Start Date,12/23/2025,,Tool ID,2975
Start Time,12:32:00 AM
End Date,12/23/2025,,Red/Blue Indicator,Blue
End Time,01:02:00 AM,,Refrigerant Type,R-404A
Duration,30minutes
Interval,1min

Time,Pressure(psig),Vapor Saturation(°F)
12:32:00 AM,86.8,40.5
12:33:00 AM,88.0,41.2
...
```

**How to export:**
1. Open Fieldpiece app or device
2. Select measurement session
3. Export → CSV
4. Move to `docs/BLE-Sniffing/reports/`

---

### Android HCI Snoop Log (`.log` format)
**Source:** Android system Bluetooth logs  
**Content:** Binary HCI (Host Controller Interface) packets  

**Contains:**
- Frame timing and direction (host→controller, controller→host)
- HCI command opcodes and event codes
- Bluetooth addresses (src/dst)
- Service UUIDs and manufacturer data
- Raw packet payload

**How to enable on device:**
1. Settings → Developer Options
2. Enable "Bluetooth HCI snoop log"
3. Reproduce your BLE session
4. Run `./scripts/pull_ble_logs.sh <device>`

**File locations on device:**
- Modern path: `/sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log`
- Older path: `/sdcard/btsnoop_hci.log`

---

### Exported CSV (tshark output)
**Generated by:** `./scripts/pull_ble_logs.sh <device> --csv`

**Columns:**
| Column | Example | Notes |
|--------|---------|-------|
| frame.time | 2025-12-23 12:32:45.123456 | Packet timestamp |
| frame.len | 34 | Packet size in bytes |
| bluetooth.hci_command_opcode | 0x0413 | HCI command type |
| bluetooth.hci_event_code | 0x05 | HCI event type |
| bluetooth.src | 00:1A:7D:DA:71:13 | Source Bluetooth address |
| bluetooth.dst | AA:BB:CC:DD:EE:FF | Dest Bluetooth address |
| bluetooth.uuid | 0000180A-0000-1000-8000-00805F9B34FB | Service UUID |
| bluetooth.manufacturer_data | 5046AAAA... | Mfg data (e.g., Fieldpiece 0x5046) |

---

## Automated Log Extraction

Use the provided script to automate pulling, extracting, and exporting BLE logs:

```bash
cd hvac_support_app

# Pull HCI snoop log with device tag
./scripts/pull_ble_logs.sh pixel

# Pull HCI log + export to CSV
./scripts/pull_ble_logs.sh pixel --csv

# Pull HCI log + full bugreport
./scripts/pull_ble_logs.sh pixel --full
```

**Output locations:**
- Raw HCI logs: `docs/BLE-Sniffing/phone-data/`
- Extracted bugreports: `docs/BLE-Sniffing/extracted_YYYY-MM-DD_*/`
- Reports (CSV, .tjf, summaries): `docs/BLE-Sniffing/reports/`

---

## ✅ In-App BLE Sniffer (Implemented Dec 18, 2025)

**Location:** TekTool → Devices screen → 🛠️ Developer Mode icon (top-right, admin-only)

### Features:

1. **Device Scanner**
   - Scan for all nearby BLE devices
   - RSSI signal strength indicators (color-coded)
   - Device name and MAC address display
   - One-tap connect

2. **GATT Tree Explorer**
   - Full service/characteristic discovery
   - Property badges: Read, Write, WriteNoResp, Notify, Indicate
   - Long-press UUID to copy to clipboard

3. **Data Operations**
   - **Read:** Fetch current characteristic value
   - **Write:** Hex byte input dialog (space-separated)

4. **Auto-Capture (Dec 19, 2025)** ✅
   - **Auto-Subscribe:** Connects and subscribes to ALL notify/indicate characteristics
   - **Auto-Read:** Reads ALL readable characteristics after service discovery
   - **Live Data Logging:** Streams all incoming data with interpretations

5. **Data Persistence (Dec 19, 2025)** ✅
   - **Local Storage:** Auto-saves sessions to Hive DB (survives app close)
   - **Cloud Sync:** Uploads captured data to Firebase `ble_sniff_logs` collection
   - **Session History:** Load, delete, and re-sync past captures

6. **Device Identification (Dec 19, 2025)** ✅
   - **Expanded Manufacturer Detection:** 25+ HVAC tool manufacturer IDs
   - **HVAC Tool Detection:** Recognizes Testo, Fieldpiece, Wey-Tek, CPS, ABM-200, Navac, Yellow Jacket, etc.
   - **ABM-200 UUID Detection:** Auto-identifies by `961f0001` service UUID
   - **Signal Sorting:** Results sorted by RSSI (strongest first)

7. **Real Device Names (Dec 19, 2025)** ✅ NEW
   - **Device Information Service (0x180a):** Auto-reads manufacturer/model/serial/firmware
   - **Displays Real Name:** Shows actual device name from Device Info chars
   - **Supported Characteristics:**
     - `0x2a29`: Manufacturer Name
     - `0x2a24`: Model Number  
     - `0x2a25`: Serial Number
     - `0x2a26`: Firmware Revision
     - `0x2a27`: Hardware Revision

8. **Expanded Manufacturer ID Lookup** ✅ NEW
   HVAC-specific Bluetooth Company IDs now recognized:
   - `0x02E1`: Testo AG
   - `0x038F`: Fieldpiece
   - `0x0310`: Yellow Jacket
   - `0x02B3`: Supco
   - `0x05A7`: CPS Products (ABM-200)
   - `0x089A`: Navac
   - `0x0806`: Wey-Tek/Inficon
   - `0x0A55`: WeatherFlow
   - `0x07D5`: Parker Sporlan
   - `0x08A3`: Mastercool
   - `0x0B2C`: JB Industries
   - `0x0C11`: Robinair
   - `0x0C9E`: Bacharach
   - `0x0D27`: UEi Test
   - `0x0E14`: REFCO

9. **Data Interpreter**
   - Auto-parses raw bytes as: uint8, int16, uint16, int32, float32
   - ÷10 and ÷100 interpretations for sensor data
   - Hex, ASCII, and raw byte array views
   - Toggle on/off with analytics icon

10. **Profile Generator**
    - Creates `DeviceProfile` code template for new devices
    - Dropdown selectors: device type, unit
    - Auto-populates detected service/characteristic UUIDs
    - Copies generated code to clipboard

11. **Logging & Export**
    - Auto-scroll log with timestamps
    - Color-coded entries: info, action, success, warning, error, data
    - Export full log to clipboard
    - Clear log option

### Cloud Sync - Accessing Sniffed Data

When you use "Sync to Cloud", data is uploaded to Firebase Firestore:

**Collection:** `ble_sniff_logs`
**Document ID:** `sniff_{timestamp}`

**Contents (Updated Dec 19, 2025):**
```json
{
  "id": "session_1766180360475",
  "timestamp": 1766180370793,
  "date": "2025-12-19T15:39:30.793661",
  "syncedAt": "server timestamp",
  "connectedDevice": { "name": "...", "mac": "..." },
  "deviceCount": 72,
  "logCount": 3,
  "devices": [
    {
      "name": "Device Name",
      "localName": "Advertised Name",
      "mac": "AA:BB:CC:DD:EE:FF",
      "rssi": -45,
      "txPower": -12,
      "connectable": true,
      "services": ["fff0", "180a"],
      "manufacturerData": { "76": "0f05..." },
      "serviceData": { "180f": "64" }
    }
  ],
  "logs": [
    {
      "time": "2025-12-19T15:38:29.206269",
      "type": "data|info|error|action",
      "msg": "log entry text"
    }
  ]
}
```

**Key Fields for HVAC Device Analysis:**
- `manufacturerData`: Map of company ID → hex data (e.g., `"20550": "4246..."` = Fieldpiece)
- `serviceData`: Map of service UUID → hex data
- `connectable`: Whether device accepts GATT connections
- `txPower`: Transmission power (helps estimate distance)
- `localName`: The advertised name (may differ from platform name)

**Known HVAC Manufacturer IDs:**
| ID (decimal) | ID (hex) | Manufacturer |
|--------------|----------|--------------|
| 20550 | 0x5046 | Fieldpiece (confirmed) |
| 737 | 0x02E1 | Testo AG |
| 784 | 0x0310 | Yellow Jacket |
| 1447 | 0x05A7 | CPS Products |
| 2202 | 0x089A | Navac |
| 2054 | 0x0806 | Wey-Tek/Inficon |
| 76 | 0x004C | Apple (filter these out) |

**To view on desktop:**
1. Go to Firebase Console → Firestore
2. Navigate to `ble_sniff_logs` collection
3. Filter by `date` or sort by `timestamp`

### How to Use:

1. Open TekTool → Devices screen
2. Tap 🛠️ icon (visible only to admins)
3. Tap **Scan** to find BLE devices
4. Devices sorted by signal strength (best first)
5. Look for device type icons and manufacturer info
6. Tap device to connect
7. Explore services and characteristics
8. Subscribe to notify chars to stream data
9. Use **⋮ menu → Sync to Cloud** to upload to Firebase
10. Use **Save Profile** button to generate code
11. Paste generated code into `device_registry.dart`

---

## Analysis Scripts (Desktop)

### scripts/compare-firebase-sync.mjs
Compares local Hive DB export with Firebase to verify sync completeness.
```bash
cd docs/BLE-Sniffing
node scripts/compare-firebase-sync.mjs
```

### parse_weytek.py
Extracts weight readings from btsnoop log, identifies packet structure.

### parse_weytek_commands.py
Documents command bytes and their meanings.

### parse_weytek_init.py
Traces init sequence for replication in app.

### parse_weytek_uuid.py
Identifies service and characteristic UUIDs.

---

## Contributing New Device Support

1. Capture BLE data using steps above
2. Create `parse_[device].py` script
3. Document protocol in this README
4. Add `DeviceProfile` to `device_registry.dart`
5. Test with real device
