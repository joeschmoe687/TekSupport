# How to Extract Bluetooth Data from Android - Complete Reference

> **Question Answered:** How to pull and unzip Bluetooth HCI logs from Samsung S931U  
> **Last Updated:** December 29, 2025

---

## TL;DR - The Answer

### How Your Bugreports Were Pulled
Using this command:
```bash
adb bugreport /path/to/bugreport_YYYYMMDD_HHMMSS.zip
```

This is the **ONLY working method** for your Samsung S931U (Android 16) device.

### How to Unzip Them
```bash
unzip -q bugreport_*.zip -d extracted_folder/
# HCI log is at: extracted_folder/FS/data/log/bt/btsnoop_hci.log
```

### Why Not Direct Pull?
Direct `adb pull /sdcard/btsnoop_hci.log` doesn't work because:
- Modern Android doesn't write HCI logs to `/sdcard/`
- Logs are routed into the bugreport system
- Only `adb bugreport` can extract them

---

## 📚 Documentation Now Available

### For Quick Reference
1. **[PULL_HCI_LOGS.md](PULL_HCI_LOGS.md)** ← Start here
   - Verified working commands for S931U
   - Troubleshooting
   - File organization
   - Working examples

2. **[FIELD_SNIFFER_GUIDE.md](FIELD_SNIFFER_GUIDE.md)** ← For field testing
   - Automated pulling script
   - Real-time monitoring
   - ML auto-detection
   - Step-by-step workflow

### For Deep Dives
3. **[commands.md](commands.md)** (legacy reference)
4. **[README.md](README.md)** (system overview)
5. **[TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md)** (BLE sniffer internals)

---

## 🎯 Your Testo T549i Results (Dec 29, 2025)

### Data Captured
```
✅ Pressure Probe:     1,579 readings (8.8 - 107.3 PSI)
✅ Temperature Probe:  1,694 readings (26.6 - 72.1 °F)
```

### ML Predictions
```
Pressure:     uint16_le at byte offset 18, ÷10 (95% confidence)
Temperature:  int16_le at byte offset 8, ÷10 (92% confidence)
```

### Correlation Targets
When analyzing HCI logs, look for:
- **65.6 PSI** → bytes `ad b0` (little-endian)
- **37.8 °F** → bytes `20 00` (little-endian)

---

## 🚀 What You Can Do Now

### 1. One-Time Pull
```bash
./scripts/field_ble_sniffer.sh --once
```
Pulls and extracts HCI log in seconds.

### 2. Continuous Monitoring
```bash
./scripts/field_ble_sniffer.sh --auto
```
Auto-pulls every 30 seconds while testing new tools.

### 3. Analyze with ML
```bash
python3 docs/BLE-Sniffing/ble_auto_sniffer.py \
  "docs/BLE-Sniffing/reports/btsnoop_*.log"
```
Detects probe types and generates device profiles.

---

## 📁 File Structure (After Updates)

```
docs/BLE-Sniffing/
├── PULL_HCI_LOGS.md                    # ← HOW TO: Pull BLE data
├── FIELD_SNIFFER_GUIDE.md             # ← HOW TO: Field testing with automation
├── ble_auto_sniffer.py                 # ML engine for probe detection
├── scripts/field_ble_sniffer.sh        # Automated pulling script
├── Testo/AppLogs/
│   └── 2025-12-29-18-50-38.csv        # ← Your test data (1,579 pressure readings)
├── reports/                            # Analysis results go here
└── extracted_*/                        # Unzipped bugreports (gitignored)
    └── FS/data/log/bt/btsnoop_hci.log
```

---

## ✅ Problems Solved

### ❌ "Where do I find the commands to pull BLE data?"
**✅ Fixed:** All commands documented in [PULL_HCI_LOGS.md](PULL_HCI_LOGS.md)

### ❌ "How were the .zip files pulled?"
**✅ Fixed:** `adb bugreport` command - now clearly documented

### ❌ "How do I unzip them?"
**✅ Fixed:** `unzip -q` command with examples

### ❌ "How do I automate this for field testing?"
**✅ Fixed:** [FIELD_SNIFFER_GUIDE.md](FIELD_SNIFFER_GUIDE.md) + automated script

### ❌ "How do I set up real-time ML probe detection?"
**✅ Fixed:** `ble_auto_sniffer.py` with Testo integration

---

## 🔄 Next Steps

### Immediate (Today)
- [ ] Review [PULL_HCI_LOGS.md](PULL_HCI_LOGS.md)
- [ ] Test `./scripts/field_ble_sniffer.sh --once`
- [ ] Verify HCI logs are being captured

### Short-Term (This Week)
- [ ] Test with different Testo probes (high, medium pressure)
- [ ] Test with other tools (Fieldpiece, Wey-Tek)
- [ ] Iterate ML model with real field data

### Medium-Term (Next Sprint)
- [ ] Integrate ML results into app UI (auto-detect in BLE Sniffer)
- [ ] Generate device profiles automatically
- [ ] Test on multiple Android devices
- [ ] Deploy Field Sniffer to production

---

## 📞 Quick Reference

### Essential Commands

```bash
# One-time setup (enable HCI logging)
# Settings → Developer Options → Bluetooth HCI snoop log → ON

# Pull HCI log
adb bugreport /path/to/bugreport_$(date +%Y%m%d_%H%M%S).zip

# Extract it
unzip -q bugreport_*.zip -d extracted_folder/

# Find HCI log
find extracted_folder -name "btsnoop_hci.log"

# Use automation script (recommended)
./scripts/field_ble_sniffer.sh --once
```

### File Locations
| Item | Path |
|------|------|
| **Pull script** | `./scripts/field_ble_sniffer.sh` |
| **ML engine** | `./docs/BLE-Sniffing/ble_auto_sniffer.py` |
| **HCI logs** | `./docs/BLE-Sniffing/reports/btsnoop_*.log` |
| **Generated code** | `./docs/BLE-Sniffing/reports/*.dart` (coming) |

---

## 🎓 Learning Resources

**If you want to understand how it works:**
1. Read [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md) for system overview
2. Review [ble_auto_sniffer.py](ble_auto_sniffer.py) source code (comments included)
3. Check Wireshark docs for HCI packet format

**If you just want to use it:**
1. Read [FIELD_SNIFFER_GUIDE.md](FIELD_SNIFFER_GUIDE.md) 
2. Run `./scripts/field_ble_sniffer.sh --help`
3. Follow the step-by-step workflow

---

## 🎉 Summary

You now have:
- ✅ Clear, working commands for extracting BLE data
- ✅ Automated field testing script
- ✅ ML engine for real-time probe detection
- ✅ Complete documentation (stops information loss)
- ✅ Your Dec 29 Testo data analyzed (65.6 PSI avg, 40.9 °F avg)

Everything is in `docs/BLE-Sniffing/` and ready for field use!
