# Quick Start: Complete TODO Tasks 1 & 2

**Status:** Code ready, awaiting manual deployment

---

## 🚀 Quick Commands

### Task 1: Deploy TekMate Function (5 min)
```bash
cd /home/runner/work/hvac_support_app/hvac_support_app
./scripts/deploy-tekmate.sh
```

### Task 2: Test TekMate Backend (2 min)
```bash
./scripts/test-tekmate-backend.sh
```


# 1. Clean rebuild with ProGuard protection
cd android && ./gradlew clean && cd ..
flutter clean && flutter pub get
flutter build apk --release

# 2. Install fresh build
adb install -r android/app/build/outputs/apk/release/app-release.apk

# 3. Monitor payment flow with emoji filters
adb logcat -s flutter 2>&1 | grep -E "💳|✅|❌|⚠️"

# 4. Open app and test: 
#    - User Verification screen (verify your account)
#    - Text Chat (should show payment screen)
#    - Phone Call (should complete payment)
#    - Video Call (should complete payment)
---

## ✅ What's Already Done

- ✅ Fixed all code errors
- ✅ Installed dependencies  
- ✅ Created deployment scripts
- ✅ Validated syntax
- ✅ Documentation complete

---

## ⚠️ What You Need to Do

1. **Authenticate Firebase** (first time only)
   ```bash
   firebase login
   ```

2. **Run deployment script**
   ```bash
   ./scripts/deploy-tekmate.sh
   ```
   
3. **Test backend** (from machine with internet)
   ```bash
   ./scripts/test-tekmate-backend.sh
   ```

4. **Configure Firestore** (in Firebase Console)
   - Collection: `settings`
   - Document: `tekmate`
   - Fields:
     - `apiUrl`: "https://tekmate.tekneck.net/api/personality-chat"
     - `apiKey`: [your_key]

---

## 📖 Detailed Guides

- **DEPLOYMENT_INSTRUCTIONS.md** - Complete deployment guide
- **TASK_COMPLETION_REPORT.md** - What was done and why
- **TODO.md** - Original task list

---

## 🆘 Troubleshooting

### "Not authenticated with Firebase"
```bash
firebase login
```

### "DNS lookup failed"
- Run backend test from local machine, not CI
- Or SSH to joloserve and check services:
  ```bash
  ssh jolo@192.168.1.117
  systemctl status tekmate
  ```

### "Function deployment failed"
- Check `functions/index.js` syntax: `node -c functions/index.js`
- Check `functions/package.json`: `cat functions/package.json | python3 -m json.tool`
- Reinstall dependencies: `cd functions && npm install`

---

**Total Time Required:** 10-15 minutes
