# TekNeck HVAC Support App (TekTool) - TODO

> **Last Updated:** December 23, 2025  
> **Status:** Code Complete ✅ | TekMate Deployment Pending ⚠️

---

## 🎯 TASK LEGEND

| Icon | Meaning | Action |
|------|---------|--------|
| 👤 | **Joey Only** - Manual task requiring dashboard/hardware access | Agent: Skip, inform Joey |
| 🤖 | **Agent Task** - Can be done autonomously by AI | Agent: Execute fully |
| 🤝 | **Collab Task** - Requires Joey + Agent working together | Agent: Ask if Joey is available |

---

## 🤖 AGENT TASKS (Numbered by Priority)

> **For AI Agents:** When asked "handle the most important task" or "do task #X", execute these in order.
> **Task 1 = highest priority.** Skip 👤 tasks and inform user they're manual.

---

### 🤖 Task 1: Deploy TekMate Cloud Function
**Priority:** CRITICAL  
**Time:** 15 min

**Pre-check:** Verify Firebase CLI is available:
```bash
firebase --version
firebase projects:list | grep tekneck
```

**Steps:**
1. Navigate to project:
   ```bash
   cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app
   ```

2. Install function dependencies:
   ```bash
   cd functions
   npm install
   ```

3. Deploy the function:
   ```bash
   firebase deploy --only functions:tekmateChatProxy
   ```

4. Capture the function URL from output (e.g., `https://us-central1-tekneck-support.cloudfunctions.net/tekmateChatProxy`)

5. Test the function:
   ```bash
   curl -X POST [FUNCTION_URL] -H "Content-Type: application/json" -d '{"test": true}'
   ```
   - Expected: 401 (unauthorized) - this is correct, means function is running

6. Report results:
   - Function URL
   - Deployment success/failure
   - Test response

**Success:** Function deployed and accessible

---

### 🤖 Task 2: Verify TekMate Backend Status
**Priority:** CRITICAL  
**Time:** 10 min

**Steps:**
1. Test TekMate server health:
   ```bash
   curl -sS https://tekmate.airpronwa.com/health
   ```
   - If JSON response → backend running ✅
   - If HTML response → Cloudflare issue (tell user 👤1 needed)
   - If timeout → server may be down (tell user to check joloserve)

2. Test personality-chat endpoint:
   ```bash
   curl -sS -X POST https://tekmate.airpronwa.com/api/personality-chat \
     -H "Content-Type: application/json" \
     -d '{"message":"test","user":"agent-test"}'
   ```

3. Report backend status

**Success:** Both endpoints return valid JSON

---

### 🤖 Task 3: Test Ghost Mode Security
**Priority:** HIGH  
**Prerequisite:** Tasks 1 & 2 complete  
**Time:** 30 min

**Steps:**
1. Read the TekMate integration files:
   - `lib/services/tekmate_chat_service.dart`
   - `lib/screens/admin/admin_chat_detail_screen.dart`
   - `functions/index.js`

2. Verify Ghost Mode implementation:
   - Check `TekMateChatService.init()` returns false for non-admins
   - Check Cloud Function has auth + role verification
   - Check admin UI only loads if `isAdmin == true`

3. Review Firestore security rules:
   ```bash
   cat firestore.rules
   ```
   - Verify `admin/tekmate_interactions` is protected

4. Create security audit report: `GHOST_MODE_AUDIT.md`
   - List all Ghost Mode checks
   - Note any potential leaks
   - Confirm customer invisibility

**Success:** Zero TekMate visibility for non-admins confirmed

---

### 🤖 Task 4: BLE Protocol Documentation
**Priority:** MEDIUM  
**Time:** 1-2 hours

**Steps:**
1. Read device implementations:
   - `lib/tools/services/device_registry.dart`
   - `lib/tools/services/device_data_service.dart`
   - `lib/tools/utils/refrigerant_detector.dart`

2. Create documentation for each device:
   - `docs/BLE-Sniffing/TESTO_PROTOCOL.md`
   - `docs/BLE-Sniffing/FIELDPIECE_PROTOCOL.md`
   - `docs/BLE-Sniffing/WEYTEK_PROTOCOL.md`
   - `docs/BLE-Sniffing/ABM200_PROTOCOL.md`

3. Create device support matrix:
   - `docs/DEVICE_SUPPORT_MATRIX.md`
   - List all devices, connection types, measurements

4. Create integration guide:
   - `docs/ADDING_NEW_BLE_DEVICE.md`
   - Step-by-step for adding new devices

**Success:** Complete BLE documentation

---

### 🤖 Task 5: Firebase Security Rules Audit
**Priority:** MEDIUM  
**Time:** 1 hour

**Steps:**
1. Read current rules:
   ```bash
   cat /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app/firestore.rules
   ```

2. Verify each collection is protected:
   - `chats` - Users can only access own chats
   - `users` - Users can only read/write own profile
   - `admin/*` - Admin only
   - `ble_sniff_logs` - Admin only

3. Check for security issues:
   - Over-permissive rules
   - Missing auth checks
   - Exposed admin data

4. Create security report: `FIRESTORE_SECURITY_AUDIT.md`

**Success:** All collections properly secured

---

### 🤖 Task 6: Test Suite Improvements
**Priority:** LOW  
**Time:** 2 hours

**Steps:**
1. Run current tests:
   ```bash
   cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app
   flutter test --coverage
   ```

2. Identify missing test coverage

3. Add tests for:
   - TekMate Ghost Mode service
   - BLE device registry
   - Refrigerant detection
   - PT chart calculations

4. Run analyzer:
   ```bash
   flutter analyze
   ```

5. Fix any issues found

**Success:** >80% coverage, no analyzer errors

---

### 🤖 Task 7: Documentation Cleanup
**Priority:** LOW  
**Time:** 30 min

**Steps:**
1. Archive outdated docs to `docs/archive/`:
   - Implementation summaries
   - Old status files
   - Completed migration docs

2. Update README.md:
   - Current feature status
   - Quick start guide
   - Troubleshooting section

3. Clean up root directory:
   - Move `*.md` summaries to docs/
   - Keep only essential files in root

**Success:** Clean, organized documentation

---

## 👤 MANUAL TASKS (Joey Only)

> **For AI Agents:** These require dashboard access, hardware, or credentials.
> **SKIP these** and tell user: "This is a manual task - you'll need to do 👤X yourself."

---

### 👤 1. Configure Firestore TekMate Settings (5 min)
**What:** Create settings document in Firestore  
**Why needed:** Cloud Function reads API URL/key from here  
**Where:** [Firebase Console](https://console.firebase.google.com/project/tekneck-support/firestore)

**Steps:**
1. Go to Firestore Database
2. Create collection: `settings`
3. Create document ID: `tekmate`
4. Add fields:
   - `apiUrl` (string): `https://tekmate.airpronwa.com/api/personality-chat`
   - `apiKey` (string): `[your_api_key]`

**After fixing, tell agent:** "Firestore configured, run task 2"

---

### 👤 2. Verify TekMate Backend on joloserve
**What:** SSH to server and check services  
**Why needed:** TekMate AI must be running for app to work

```bash
ssh jolo@192.168.1.117
systemctl status tekmate.service
systemctl status tekmate-proxy.service
systemctl status tekmate-tunnel.service
```

If services stopped, start them:
```bash
sudo systemctl start tekmate.service tekmate-proxy.service tekmate-tunnel.service
```

---

### 👤 3. Physical BLE Device Testing (30 min)
**What:** Test with real Fieldpiece/Testo devices  
**Why manual:** Requires physical hardware

**Test each device:**
1. Connect device to HVAC system
2. Open app → Tools Hub
3. Connect device via BLE
4. Verify readings display correctly
5. Test refrigerant detection
6. Note any issues

---

### 👤 4. Admin TekMate UI Testing (15 min)
**What:** Test TekMate features as admin user  
**Why manual:** Requires admin login credentials

**Steps:**
1. Login as admin (role='admin' in Firestore)
2. Open support chat
3. Click 🧠 "Ask TekMate" button
4. Verify suggestion appears
5. Test confidence score display
6. Test "Use Suggestion" / "Send Now"

---

## 🤝 COLLAB TASKS (Joey + Agent Together)

> **For AI Agents:** Ask "Is Joey available for live testing?" before starting these.

---

### 🤝 1. Live BLE Debugging
**What:** Real-time debugging while Joey tests with devices  
**Requires:** Joey with physical BLE devices + agent monitoring

**Workflow:**
1. Joey connects BLE device
2. Agent monitors: `adb logcat | grep -i "flutter\|ble"`
3. Agent analyzes data parsing
4. Agent suggests fixes for issues
5. Repeat until working

---

### 🤝 2. End-to-End TekMate Testing
**What:** Full flow from mobile app to TekMate AI  
**Requires:** Joey testing on device + agent monitoring logs

**Workflow:**
1. Agent monitors Cloud Function logs: `firebase functions:log`
2. Joey opens app as admin
3. Joey requests TekMate suggestion
4. Agent verifies logs show proper flow
5. Verify response displays correctly

---

## ✅ COMPLETED

### TekMate Integration
- ✅ Cloud Function `tekmateChatProxy` implementation
- ✅ Admin UI with 🧠 button
- ✅ Confidence scoring system
- ✅ Ghost Mode security (invisible to non-admins)
- ✅ TekMateChatService.dart

### BLE Device Support
- ✅ Testo probes (T115i, T549i)
- ✅ Fieldpiece devices (broadcast-only)
- ✅ Wey-Tek HD Scale
- ✅ ABM-200 Airflow meter
- ✅ Auto-reconnection service
- ✅ Refrigerant detection

### Testing
- ✅ Unit tests for PT chart
- ✅ Widget tests for screens
- ✅ Integration test suite

---

## 📝 QUICK REFERENCE

### Build & Run
```bash
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app
flutter run
```

### Deploy Function
```bash
cd functions && npm install && firebase deploy --only functions:tekmateChatProxy
```

### Run Tests
```bash
flutter test
flutter analyze
```

### Check TekMate Backend
```bash
curl -sS https://tekmate.airpronwa.com/health
```

### Firebase Console
https://console.firebase.google.com/project/tekneck-support
