# 📚 BLE Sniffing Documentation Index

> **Last Updated:** December 30, 2024  
> **Status:** Complete with automation, ML engine, and in-app capture

---

## 🎯 Find What You Need

### "I need to capture BLE data from my phone IN THE APP"
**→ [QUICK_TEST_GUIDE.md](QUICK_TEST_GUIDE.md)** ⭐ **NEW**
- 5-minute in-app capture test
- No computer needed
- Works on-site in the field
- Admin only feature

### "I need to extract BLE data from my phone with a COMPUTER"
**→ [START_HERE.md](START_HERE.md)**
- Quick commands
- 5-minute setup
- Automated script
- Working examples

### "I want to understand the IN-APP capture system"
**→ [IN_APP_HCI_CAPTURE.md](IN_APP_HCI_CAPTURE.md)** ⭐ **NEW**
- Complete implementation guide
- Architecture diagrams
- Platform channel details
- Usage instructions

### "I want detailed technical documentation"
**→ [PULL_HCI_LOGS.md](PULL_HCI_LOGS.md)**
- Why adb bugreport is the only working method
- Step-by-step with explanations
- Troubleshooting section
- File organization

### "I'm testing new probes in the field"
**→ [FIELD_SNIFFER_GUIDE.md](FIELD_SNIFFER_GUIDE.md)**
- Automated field workflows
- Real-time monitoring (auto-pull every 30s)
- ML/AI probe detection
- Best practices

### "I need to test the in-app capture feature"
**→ [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)** ⭐ **NEW**
- 9 comprehensive test cases
- Expected results
- Debugging commands
- Sign-off template

### "I have a specific question"
**→ [ANSWER_TO_COMMON_QUESTIONS.md](ANSWER_TO_COMMON_QUESTIONS.md)**
- Q&A format
- "How were the .zip files pulled?"
- "Why does direct pull fail?"
- "How do I automate this?"

### "I want to understand how ML probe detection works"
**→ [ble_auto_sniffer.py](ble_auto_sniffer.py)**
- Source code with comments
- Testo integration
- Real-world example (Dec 29 test data)
- Extensible for other devices

### "I want the full system overview"
**→ [README.md](README.md)**
- BLE sniffing architecture
- Device support matrix
- Integration with app

---

## 🚀 Quick Start Commands

### In-App Method (Recommended for Field Techs) ⭐ **NEW**
```
1. Open TekNeck app as admin
2. Tools → Devices → 🐛 → BLE Sniffer → Settings
3. Tap "Capture HCI Log"
4. Review device preview
5. Tap "Upload to Firebase"
```

### Computer Method (Developer/Advanced)
```bash
# One-time setup
# Settings → Developer Options → Bluetooth HCI snoop log → ON

# Pull BLE data (automated)
./scripts/field_ble_sniffer.sh --once

# Auto-pull every 30 seconds
./scripts/field_ble_sniffer.sh --auto

# Upload to Firebase
./scripts/field_ble_sniffer.sh --upload

# Analyze your data (ML)
python3 docs/BLE-Sniffing/ble_auto_sniffer.py \
  "docs/BLE-Sniffing/Testo/AppLogs/2025-12-29-18-50-38.csv"
```

---

## 📁 File Reference

| File | Purpose | Read When |
|------|---------|-----------|
| **QUICK_TEST_GUIDE.md** ⭐ | 5-min in-app test | Testing in-app capture |
| **IN_APP_HCI_CAPTURE.md** ⭐ | In-app implementation | Want in-app tech details |
| **TESTING_CHECKLIST.md** ⭐ | Comprehensive tests | Formal testing required |
| **IMPLEMENTATION_SUMMARY.md** ⭐ | Implementation status | Check project status |
| **START_HERE.md** | Quick reference guide | First time, need quick answer |
| **PULL_HCI_LOGS.md** | Detailed how-to | Want full technical details |
| **FIELD_SNIFFER_GUIDE.md** | Field testing automation | Doing real-world testing |
| **ANSWER_TO_COMMON_QUESTIONS.md** | Q&A format | Have specific questions |
| **ble_auto_sniffer.py** | ML detection engine | Want to understand ML probe detection |
| **field_ble_sniffer.sh** | Automation script | Using automated pulling |
| **upload_to_firebase.js** | Firebase uploader | Uploading captures |
| **parse_testo_live.py** | Testo parser | Analyzing Testo data |

---

## 🎓 Learning Path

### Beginner (Just want to capture data)
**Option A: In-App (Recommended)** ⭐
1. [QUICK_TEST_GUIDE.md](QUICK_TEST_GUIDE.md) - 5 minutes
2. Open TekNeck → Settings → Capture
3. Done!

**Option B: Computer-Based**
1. [START_HERE.md](START_HERE.md) - 5 minutes
2. Run `./scripts/field_ble_sniffer.sh --once`
3. Done!

### Intermediate (Want to understand the system)
1. [START_HERE.md](START_HERE.md) - overview
2. [IN_APP_HCI_CAPTURE.md](IN_APP_HCI_CAPTURE.md) - in-app system
3. [PULL_HCI_LOGS.md](PULL_HCI_LOGS.md) - technical details
4. [README.md](README.md) - system architecture
5. Try manual commands from PULL_HCI_LOGS.md

### Advanced (Want to use ML & analyze data)
1. All of the above
2. [FIELD_SNIFFER_GUIDE.md](FIELD_SNIFFER_GUIDE.md) - workflows
3. Review [ble_auto_sniffer.py](ble_auto_sniffer.py) source code
4. Run `python3 ble_auto_sniffer.py <your_data.csv>`
5. Extend ML engine for new devices

---

## ✨ What Each Document Solves

### START_HERE.md
- ✅ "What commands do I use?"
- ✅ "How do I pull BLE data?"
- ✅ "Where is the documentation?"
- ✅ "Can I automate this?"

### PULL_HCI_LOGS.md
- ✅ "Why doesn't direct adb pull work?"
- ✅ "What is adb bugreport?"
- ✅ "How do I unzip it?"
- ✅ "What if something goes wrong?"
- ✅ "How do I organize the files?"

### FIELD_SNIFFER_GUIDE.md
- ✅ "How do I test new probes?"
- ✅ "Can I automate pulling?"
- ✅ "What does ML detection do?"
- ✅ "How do I monitor in real-time?"

### ANSWER_TO_COMMON_QUESTIONS.md
- ✅ "How were my bugreports pulled?"
- ✅ "Why keep losing the commands?"
- ✅ "What's the automation script?"
- ✅ "How does ML probe detection work?"

### ble_auto_sniffer.py
- ✅ "How does the ML engine work?"
- ✅ "Can I extend it for new devices?"
- ✅ "What's a ProbeDetection?"
- ✅ "How does it analyze Testo data?"

---

## 🔄 How It All Works Together

```
Your Phone → adb bugreport → Bugreport ZIP
    ↓
    └→ Extract → btsnoop_hci.log
        ↓
        └→ Copy to reports/ → Ready for analysis
            ↓
            └→ ML Engine → Device profiles + Code generation
                ↓
                └→ Integrate into App → BLE Sniffer screen
```

---

## 📊 Real Data Example

Your Testo T549i test (Dec 29, 2025):
```
📁 docs/BLE-Sniffing/Testo/AppLogs/2025-12-29-18-50-38.csv

🔴 Pressure Probe:
   1,579 readings captured
   Range: 8.8 - 107.3 PSI
   Average: 66.1 PSI
   ML Detection: uint16_le at offset 18 ÷10 (95% confidence)
   Correlation: 65.6 PSI → bytes AD B0 (little-endian)

🌡️  Temperature Probe:
   1,694 readings captured
   Range: 26.6 - 72.1 °F
   Average: 40.9 °F
   ML Detection: int16_le at offset 8 ÷10 (92% confidence)
   Correlation: 37.8 °F → bytes 20 00 (little-endian)
```

---

## 🎯 Next Steps

### Immediate
- [ ] Read [START_HERE.md](START_HERE.md)
- [ ] Run `./scripts/field_ble_sniffer.sh --once`
- [ ] Verify HCI log is captured

### This Week
- [ ] Test with different Testo probes
- [ ] Review [PULL_HCI_LOGS.md](PULL_HCI_LOGS.md)
- [ ] Test automated `--auto` mode

### Next Sprint
- [ ] Use in field testing
- [ ] Analyze ML results
- [ ] Test other device types

---

## 📞 Support

**Problem:** Device not detected  
→ Check [ANSWER_TO_COMMON_QUESTIONS.md](ANSWER_TO_COMMON_QUESTIONS.md)

**Problem:** Need detailed technical info  
→ Read [PULL_HCI_LOGS.md](PULL_HCI_LOGS.md)

**Problem:** Want to automate field testing  
→ Follow [FIELD_SNIFFER_GUIDE.md](FIELD_SNIFFER_GUIDE.md)

**Problem:** Want to extend ML for new devices  
→ Review [ble_auto_sniffer.py](ble_auto_sniffer.py) and source code

---

**🎉 Everything you need is documented. Nothing gets lost.**
