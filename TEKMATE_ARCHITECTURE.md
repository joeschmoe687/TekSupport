# TekMate Ghost Mode Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HVAC SUPPORT APP                            │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                  ADMIN CHAT SCREEN                           │  │
│  │                                                              │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │  TekMateChatService.init()                             │ │  │
│  │  │  ↓                                                      │ │  │
│  │  │  Check Firebase Auth                                   │ │  │
│  │  │  ↓                                                      │ │  │
│  │  │  Query: users/{uid} → role field                       │ │  │
│  │  │  ↓                                                      │ │  │
│  │  │  if (role == 'admin') → return true                    │ │  │
│  │  │  else → return false (SILENT)                          │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  │                                                              │  │
│  │  ┌─── IF ADMIN (isAvailable == true) ────┐                 │  │
│  │  │                                        │                 │  │
│  │  │  ┌──────────────────────────────────┐ │                 │  │
│  │  │  │  "Ask TekMate AI" Button        │ │                 │  │
│  │  │  │  [🧠 Purple Psychology Icon]     │ │                 │  │
│  │  │  └──────────────────────────────────┘ │                 │  │
│  │  │              ↓ (onClick)              │                 │  │
│  │  │  ┌──────────────────────────────────┐ │                 │  │
│  │  │  │  TekMate Dialog                  │ │                 │  │
│  │  │  │  • AI Response Text              │ │                 │  │
│  │  │  │  • Confidence: 88%               │ │                 │  │
│  │  │  │  • [Use This Response] button    │ │                 │  │
│  │  │  └──────────────────────────────────┘ │                 │  │
│  │  │                                        │                 │  │
│  │  └────────────────────────────────────────┘                 │  │
│  │                                                              │  │
│  │  ┌─── IF NON-ADMIN (isAvailable == false) ────┐            │  │
│  │  │                                             │            │  │
│  │  │  NO TEKMATE UI                              │            │  │
│  │  │  NO BUTTON                                  │            │  │
│  │  │  NO NETWORK CALLS                           │            │  │
│  │  │  COMPLETE INVISIBILITY                      │            │  │
│  │  │                                             │            │  │
│  │  └─────────────────────────────────────────────┘            │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
                    (Admin clicks button)
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      FIREBASE CLOUD FUNCTIONS                       │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  tekmateChatProxy (Callable Function)                        │  │
│  │                                                              │  │
│  │  1. ✓ Check Firebase Auth Token                             │  │
│  │     if (!context.auth) → 401 Unauthenticated                │  │
│  │                                                              │  │
│  │  2. ✓ Query Firestore: users/{uid}                          │  │
│  │     const userData = userDoc.data()                          │  │
│  │                                                              │  │
│  │  3. ✓ Check Admin Role                                      │  │
│  │     const isAdmin = userData.role === 'admin'               │  │
│  │     if (!isAdmin) → 403 Forbidden                           │  │
│  │                                                              │  │
│  │  4. ✓ Generate AI Response (mock)                           │  │
│  │     - Analyze message for query type                        │  │
│  │     - BLE device? HVAC diagnostic? Service call?            │  │
│  │     - Generate contextual response                          │  │
│  │     - Calculate confidence score                            │  │
│  │                                                              │  │
│  │  5. ✓ Log to Firestore                                      │  │
│  │     admin/tekmate_interactions/logs/{logId}                 │  │
│  │     - userId, userEmail                                     │  │
│  │     - message, response                                     │  │
│  │     - confidence, context                                   │  │
│  │     - timestamp                                             │  │
│  │                                                              │  │
│  │  6. ✓ Return Response                                       │  │
│  │     { response: "...", confidence: 0.88, autoRespond: false }│  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
                      (Response returned)
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                         FIRESTORE DATABASE                          │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Collection: admin                                           │  │
│  │  ├── Document: tekmate_interactions                          │  │
│  │  │   └── Subcollection: logs                                │  │
│  │  │       ├── {logId1}                                        │  │
│  │  │       │   ├── userId: "abc123"                           │  │
│  │  │       │   ├── userEmail: "admin@example.com"            │  │
│  │  │       │   ├── message: "What is normal superheat?"       │  │
│  │  │       │   ├── response: "For R410A AC, expect 10-15°F"  │  │
│  │  │       │   ├── confidence: 0.88                          │  │
│  │  │       │   ├── context: { roomId, customerId, ... }      │  │
│  │  │       │   └── timestamp: 2025-12-21T...                 │  │
│  │  │       └── {logId2} ...                                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  SECURITY RULES: firestore.rules                            │  │
│  │                                                              │  │
│  │  match /admin/{document=**} {                               │  │
│  │    // ONLY authenticated admins can access                  │  │
│  │    allow read, write: if isAdmin();                         │  │
│  │  }                                                           │  │
│  │                                                              │  │
│  │  function isAdmin() {                                       │  │
│  │    return request.auth != null &&                           │  │
│  │      get(/users/$(request.auth.uid)).data.role == 'admin';  │  │
│  │  }                                                           │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘


════════════════════════════════════════════════════════════════════════
                        SECURITY FLOW COMPARISON
════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────┬─────────────────────────────────┐
│         ADMIN USER              │       NON-ADMIN USER            │
├─────────────────────────────────┼─────────────────────────────────┤
│                                 │                                 │
│ 1. Login with admin account     │ 1. Login with tech account      │
│    ↓                            │    ↓                            │
│ 2. TekMate.init()               │ 2. TekMate.init()               │
│    → checks role='admin'        │    → checks role='tech'         │
│    → returns TRUE               │    → returns FALSE (silent)     │
│    ↓                            │    ↓                            │
│ 3. UI renders button            │ 3. UI renders NOTHING           │
│    [🧠 Ask TekMate AI]          │    (button hidden by if check)  │
│    ↓                            │    ↓                            │
│ 4. Click button                 │ 4. NO BUTTON TO CLICK           │
│    ↓                            │    ↓                            │
│ 5. Call tekmateChatProxy        │ 5. NO API CALL                  │
│    with Firebase Auth           │    (service returned null)      │
│    ↓                            │    ↓                            │
│ 6. Function checks auth ✓       │ 6. NO FUNCTION CALLED           │
│    ↓                            │    ↓                            │
│ 7. Function checks admin ✓      │ 7. COMPLETE INVISIBILITY        │
│    ↓                            │    - No UI elements             │
│ 8. Generate AI response         │    - No network calls           │
│    ↓                            │    - No console errors          │
│ 9. Return confidence + text     │    - No logs                    │
│    ↓                            │    - Zero evidence              │
│ 10. Log to admin collection     │                                 │
│    ↓                            │                                 │
│ 11. Show dialog with response   │                                 │
│                                 │                                 │
└─────────────────────────────────┴─────────────────────────────────┘


════════════════════════════════════════════════════════════════════════
                            DATA FLOW
════════════════════════════════════════════════════════════════════════

User Input → TekMate Service → Cloud Function → AI Processing → Response

┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Message  │───→│ Service  │───→│ Firebase │───→│   Mock   │───→│ Dialog   │
│ "Help?"  │    │  Check   │    │ Function │    │    AI    │    │ Display  │
│          │    │  Admin   │    │  Auth    │    │ Response │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
                     ↓                ↓                ↓               ↓
                 if !admin       if !auth         Context         Confidence
                 return null     → 401            Analysis        Score: 88%
                                                                       ↓
                                                                  "Use This"


════════════════════════════════════════════════════════════════════════
                         DEPLOYMENT FLOW
════════════════════════════════════════════════════════════════════════

Local Development → Firebase → Production

1. Code Complete ✓
   ├── functions/index.js
   ├── firestore.rules
   └── admin_chat_detail_screen.dart

2. Deploy Script
   ./scripts/deploy-tekmate.sh
   ├── Check Firebase CLI
   ├── npm install in functions/
   └── firebase deploy --only functions,firestore:rules

3. Set Admin Role
   Firestore Console → users/{uid} → role: "admin"

4. Test Admin
   Login → Chat → See Button → Get Response ✓

5. Test Non-Admin
   Login → Chat → See Nothing ✓

6. Monitor
   Firebase Console → Functions → Logs
   Firestore → admin/tekmate_interactions/logs

7. Production Ready! 🎉
```

## Key Security Points

1. **Triple Check System:**
   - Client-side: Service returns null for non-admins
   - UI-side: Button only renders if service says available
   - Server-side: Cloud Function verifies admin role

2. **Silent Failures:**
   - No error messages for non-admins
   - No network calls attempted
   - No console logs revealing TekMate

3. **Admin-Only Data:**
   - Firestore `/admin` collection
   - Protected by security rules
   - Only admins can read/write

4. **Context Isolation:**
   - Non-admins never see TekMate context
   - Room/customer data only sent if admin
   - Logs contain admin info only

## Testing Checkpoints

✓ Non-admin login → No button
✓ Non-admin network logs → No tekmate calls
✓ Admin login → Button visible
✓ Admin click → Response received
✓ Admin logs → Entry in Firestore
✓ Non-admin Firestore access → Denied
