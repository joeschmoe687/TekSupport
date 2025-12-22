# BLE Sniffer Quick Reference

## 🚀 Quick Start

### Adding a New Unknown Device (5 Minutes!)

1. **Open BLE Sniffer** (TekTool → Devices → 🛠️ icon)
2. **Tap SCAN** → Find your device
3. **Look for AI badge** → Green = high confidence, Orange = medium
4. **Tap device** → Auto-connects and analyzes
5. **Wait 10-20 seconds** → Let data stream (vary reading if possible)
6. **Tap Save Profile button** (💾 top-right)
7. **Fill in name** → Generator pre-fills everything else
8. **Tap Generate & Copy** → Production code copied!
9. **Paste into** `lib/tools/services/device_registry.dart`
10. **Done!** Device now works in app

## 🎯 Understanding The UI

### During Scan

```
┌─────────────────────────────────────┐
│ [Icon] Device Name          RSSI -45│
│ AA:BB:CC:DD:EE:FF                   │
│ Mfr: Testo AG                       │
│ [AI: Temp Probe (High)] ← Smart!   │
│ Services: fff0, 180a                │
└─────────────────────────────────────┘
```

### During Connection

```
Console Log:
📡 DATA [fff2]:              ← Raw packet
  Hex: 1A 04 00 00
  💡 Temperature F: 68.5     ← Live suggestion!
  💡 (87% confidence)
  
🧠 SMART ANALYSIS:           ← Every 5 packets
   Detected int16_le_div10
   Best match: Temp at bytes [0-1]
   Update rate: 10.2 Hz
```

## 🎨 Visual Indicators

### AI Classification Badges

| Badge | Meaning |
|-------|---------|
| 🟢 AI: Type (Very High) | 80-100% confident - trust it! |
| 🟢 AI: Type (High) | 60-79% - likely correct |
| 🟠 AI: Type (Medium) | 40-59% - verify readings |
| 🟠 AI: Type (Low) | 20-39% - test alternatives |
| (no badge) | <20% - uncertain |

### Log Icons

| Icon | Type | Meaning |
|------|------|---------|
| 📡 | DATA | Raw packet received |
| 💡 | SUGGESTION | Live interpretation |
| 🧠 | ANALYSIS | Pattern detected |
| ✅ | SUCCESS | Action completed |
| ⚠️ | WARNING | Attention needed |
| ❌ | ERROR | Something failed |

## 🔧 Common Workflows

### Workflow 1: Verify Known Device

**Goal**: Check if existing profile works correctly

```
1. Scan → Find device
2. Connect → Auto-analysis starts
3. Watch console → Look for matching values
4. Compare with device display
5. ✅ Matches? Done!
6. ❌ Wrong? Generate new profile
```

### Workflow 2: Debug Wrong Readings

**Goal**: Fix incorrect parsed values

```
1. Connect to device
2. Watch smart suggestions
3. Note highest confidence suggestion
4. Save Profile → Check alternatives
5. Try different parsing method
6. Test with real device
7. Update device_registry.dart
```

### Workflow 3: Identify Mystery Device

**Goal**: Figure out what unknown device is

```
1. Scan → Check AI badge
2. Note manufacturer data (if present)
3. Connect → Watch data patterns
4. Look for value ranges:
   - 0-100? → Humidity or battery
   - 30-90? → Temperature F
   - -30 to 800? → Pressure psig
5. Use smart suggestions
6. Generate profile
```

## 📊 Reading Confidence Scores

### What They Mean

| Score | Classification | Pattern Analysis |
|-------|---------------|------------------|
| 90-100% | Almost certain | Use immediately |
| 70-89% | Very likely | Test, should work |
| 50-69% | Good guess | Verify first |
| 30-49% | Possible | Try alternatives |
| <30% | Uncertain | Manual work needed |

### How They're Calculated

**Classification Confidence**:
- Brand match: +30-40 points
- Service UUID match: +25-35 points
- Name keywords: +15-30 points
- MAC OUI match: +10-15 points
- Connectivity type: +5-10 points

**Pattern Confidence**:
- Value in typical range: 40%
- Consistent across packets: 30%
- Low variance (stable): 30%

## 🎓 Pro Tips

### Maximize Accuracy

✅ **DO**:
- Let device stream for 20+ seconds
- Vary the reading during capture
- Use manufacturer's app side-by-side
- Check multiple interpretation methods

❌ **DON'T**:
- Trust low confidence (<50%)
- Use first 2-3 packets only
- Ignore alternative methods
- Skip comparison with actual device

### Debugging Steps

1. **Check AI badge** → Is classification reasonable?
2. **Watch first 5 packets** → See smart analysis appear
3. **Note highest confidence** → That's your best bet
4. **Try it first** → Generate and test
5. **Use alternatives** → If first doesn't work
6. **Check manufacturer data** → Look for clues

### Speed Hacks

⚡ **Fast Device Add**:
```
Scan → Connect → Wait 10s → Save → Copy → Paste → Done
Total time: ~2 minutes
```

⚡ **Quick Verification**:
```
Connect → Watch console → Compare values → Disconnect
Total time: 30 seconds
```

## 🔍 Troubleshooting

### Problem: No AI badge shows

**Causes**:
- Consumer device (phone, earbuds)
- No identifying features
- Too many services (>10)

**Solution**: Not an HVAC tool, ignore

### Problem: Wrong device type

**Causes**:
- Similar advertisement patterns
- Generic service UUIDs
- Low distinguishing features

**Solution**: 
- Check confidence level
- Manually select correct type
- Use manufacturer data

### Problem: Pattern analysis never shows

**Causes**:
- Device not streaming data
- Connected but no notifications
- Wrong characteristic subscribed

**Solution**:
- Check if notify enabled
- Verify correct characteristic
- Try manual subscribe

### Problem: Generated code doesn't work

**Causes**:
- Wrong byte offset
- Wrong endianness
- Wrong divisor
- Checksum included in value

**Solution**:
1. Try alternative methods (in generated code)
2. Check byte offset (±1 or ±2)
3. Switch LE ↔ BE
4. Try divisors: ×1, ÷10, ÷100, ÷1000
5. Check for checksums

## 📱 Screenshots Guide

### What You Should See

**1. Scan Results**
- List of devices sorted by signal strength
- AI badges on HVAC tools
- Manufacturer info displayed
- Signal strength color-coded

**2. Connection Log**
- Auto-subscribe messages
- Data packets streaming
- Smart suggestions appearing
- Analysis results every 5 packets

**3. Profile Generator**
- Pre-filled device name
- Auto-selected type/unit
- Detected UUIDs shown
- One-click generate button

## 🎯 Success Criteria

### You're Ready When

✅ AI badge confidence ≥ 60%
✅ Pattern analysis shows results
✅ Smart suggestions appear in log
✅ Values match expected range
✅ Generated code has high confidence
✅ Update rate detected (Hz shown)

### Red Flags

🚩 Confidence < 30%
🚩 Values wildly out of range
🚩 No pattern detected after 20s
🚩 Update rate = 0 Hz
🚩 Checksum failures

## 📞 Getting Help

### What to Include

When asking for help, provide:

1. **Device info**:
   - Name from scan
   - MAC address
   - Manufacturer ID (if shown)
   - AI classification & confidence

2. **Capture data**:
   - 5-10 raw packets (hex)
   - Smart analysis output
   - Expected vs actual values
   - Manufacturer's app reading

3. **What you tried**:
   - Which parsing method
   - Alternative methods tested
   - Manual adjustments made

### Where to Look

1. **Console log** - Most info here
2. **AI badge** - Quick classification
3. **Manufacturer data** - Device fingerprint
4. **Service UUIDs** - Protocol clues

---

**Remember**: The goal is 5-minute device integration. If it takes longer, something's wrong - check this guide!

## 🎉 Success Stories

*"Added unknown Chinese pressure sensor in 3 minutes!"* ⭐⭐⭐⭐⭐

*"AI correctly identified Fieldpiece tool just from advertisement"* ⭐⭐⭐⭐⭐

*"Pattern analyzer found the parsing method I spent hours looking for"* ⭐⭐⭐⭐⭐
