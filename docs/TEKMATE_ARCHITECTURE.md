# TekMate Integration Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                          │
│                  (Android/iOS - TekTool)                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Firebase Auth Token
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Admin Chat Screen                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Message Input Area                                      │  │
│  │  ┌──────┐  ┌──────────────────┐  ┌────┐  ┌──────┐     │  │
│  │  │ 📎   │  │ Type message...   │  │ 🧠 │  │ ➤   │     │  │
│  │  │Attach│  │                   │  │AI  │  │Send │     │  │
│  │  └──────┘  └──────────────────┘  └────┘  └──────┘     │  │
│  │                                      │                  │  │
│  │                                      │ (Admin Only!)    │  │
│  └──────────────────────────────────────┼──────────────────┘  │
│                                         │                      │
└─────────────────────────────────────────┼──────────────────────┘
                                          │
                                          │ Tap TekMate Button
                                          ▼
┌─────────────────────────────────────────────────────────────────┐
│               TekMateChatService (Client)                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. Check isAdmin (from Firestore users/{uid})          │  │
│  │  2. If NOT admin → return null (Ghost Mode)             │  │
│  │  3. If admin → call Cloud Function                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS + Auth Token
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│          Firebase Cloud Function (tekmateChatProxy)             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. Verify Firebase Auth Token                          │  │
│  │  2. Check user role in Firestore                        │  │
│  │  3. If NOT admin → 403 Forbidden                        │  │
│  │  4. Extract message + context                           │  │
│  │  5. Call TekMate API                                    │  │
│  │  6. Log interaction to Firestore                        │  │
│  │  7. Return response + confidence                        │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS + API Key
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              TekMate Consolidated Backend                       │
│                    (tekmate-consolidated)                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • AI/ML inference engine                               │  │
│  │  • HVAC knowledge base                                  │  │
│  │  • Technician training data                             │  │
│  │  • Device protocol learning                             │  │
│  │  • Confidence scoring                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Response
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Response Flow                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  {                                                       │  │
│  │    "response": "To troubleshoot low superheat...",      │  │
│  │    "confidence": 0.92,                                  │  │
│  │    "autoRespond": false                                 │  │
│  │  }                                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               TekMate Suggestion Dialog                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  🧠 TekMate Suggestion                                  │  │
│  │  ┌────────────────────────────────────────────────────┐ │  │
│  │  │ 🟢 Confidence: 92%                                 │ │  │
│  │  └────────────────────────────────────────────────────┘ │  │
│  │                                                          │  │
│  │  To troubleshoot low superheat, first check...         │  │
│  │  (editable text area)                                   │  │
│  │                                                          │  │
│  │  ✓ High confidence - Review and send                   │  │
│  │                                                          │  │
│  │  [Cancel]  [Use Suggestion]  [Send Now]                │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

### Admin User (Ghost Mode OFF)

```
User → Admin Chat Screen
  │
  ├─ Tap 🧠 Button
  │    │
  │    └─→ TekMateChatService.getResponse()
  │          │
  │          ├─ Check isAdmin: ✓ TRUE
  │          │
  │          └─→ Firebase Cloud Function
  │                │
  │                ├─ Verify Auth: ✓ PASS
  │                ├─ Verify Admin: ✓ PASS
  │                │
  │                └─→ TekMate API
  │                      │
  │                      └─→ AI Response
  │                            │
  │                            └─→ Show Dialog
  │                                  │
  │                                  ├─ [Use Suggestion]
  │                                  └─ [Send Now]
```

### Non-Admin User (Ghost Mode ON) 🔒

```
User → Chat Screen
  │
  ├─ 🧠 Button: ❌ NOT VISIBLE
  │
  └─ TekMateChatService.init()
       │
       └─ Check isAdmin: ✗ FALSE
            │
            └─ Return: isAvailable = false
                 │
                 └─ UI: No TekMate elements render
                      │
                      └─ Network: No API calls made
                           │
                           └─ Ghost Mode: ✓ WORKING
```

## Security Layers

```
┌─────────────────────────────────────────────┐
│  Layer 1: UI Conditional Rendering          │
│  if (_isTekmateAvailable) → Show button     │
│  else → Button never rendered               │
└─────────────────────────────────────────────┘
                    ▼
┌─────────────────────────────────────────────┐
│  Layer 2: Client Service Check              │
│  TekMateChatService.init()                  │
│  if (!isAdmin) → return false               │
└─────────────────────────────────────────────┘
                    ▼
┌─────────────────────────────────────────────┐
│  Layer 3: Cloud Function Auth               │
│  if (!context.auth) → 401 Unauthorized      │
└─────────────────────────────────────────────┘
                    ▼
┌─────────────────────────────────────────────┐
│  Layer 4: Cloud Function Role Check         │
│  if (role !== 'admin') → 403 Forbidden      │
└─────────────────────────────────────────────┘
                    ▼
┌─────────────────────────────────────────────┐
│  Layer 5: Interaction Logging               │
│  Log to admin-only Firestore collection     │
│  admin/tekmate_interactions/logs            │
└─────────────────────────────────────────────┘
```

## File Structure

```
hvac_support_app/
├── lib/
│   ├── services/
│   │   └── tekmate_chat_service.dart       # Client service
│   └── screens/
│       └── admin_chat_detail_screen.dart   # UI integration
├── functions/
│   ├── index.js                            # Cloud Functions
│   └── package.json                        # Dependencies
├── test/
│   └── services/
│       └── tekmate_chat_service_test.dart  # Unit tests
├── docs/
│   ├── TEKMATE_TESTING_GUIDE.md           # Full testing guide
│   ├── TEKMATE_QUICK_REFERENCE.md         # Quick reference
│   └── TEKMATE_ARCHITECTURE.md            # This file
├── scripts/
│   └── deploy_tekmate.sh                  # Deployment script
├── firebase.json                          # Firebase config
└── .firebaserc                            # Project config
```

## Configuration

### Firestore Collections

```
settings/
  └── tekmate/
      ├── apiUrl: "https://tekmate-api.com/api/chat"
      └── apiKey: "your-api-key"

users/
  └── {userId}/
      ├── role: "admin" | "tech" | "customer"
      └── isAdmin: true | false

admin/
  └── tekmate_interactions/
      └── logs/
          └── {logId}/
              ├── userId: "admin_uid"
              ├── message: "query"
              ├── response: "AI response"
              ├── confidence: 0.92
              └── timestamp: Timestamp
```

### Environment Variables

```bash
# Firebase Functions Config
firebase functions:config:set \
  stripe.secret_key="sk_test_..." \
  stripe.webhook_secret="whsec_..."
```

## API Contracts

### TekMate Cloud Function

**Request:**
```typescript
interface TekMateRequest {
  message: string;
  context?: {
    roomId?: string;
    jobId?: string;
    systemType?: string;
    refrigerant?: string;
    recentMessages?: Array<{
      text: string;
      senderType: string;
      timestamp: string;
    }>;
  };
  platform?: string;
}
```

**Response:**
```typescript
interface TekMateResponse {
  response: string;       // AI-generated text
  confidence: number;     // 0.0 to 1.0
  autoRespond: boolean;   // Should auto-send?
}
```

**Errors:**
```typescript
type TekMateError =
  | { code: 'unauthenticated'; message: 'Authentication required' }
  | { code: 'permission-denied'; message: 'Access denied' }
  | { code: 'invalid-argument'; message: 'Message is required' }
  | { code: 'failed-precondition'; message: 'Service not configured' }
  | { code: 'internal'; message: 'AI service error' }
```

## Deployment Checklist

- [ ] Install dependencies: `cd functions && npm install`
- [ ] Configure Firebase project: `firebase use tekneck-support`
- [ ] Deploy functions: `firebase deploy --only functions:tekmateChatProxy`
- [ ] Create Firestore `settings/tekmate` document
- [ ] Test with admin user
- [ ] Test with non-admin user (Ghost Mode)
- [ ] Monitor Cloud Function logs
- [ ] Set up error alerting

## Monitoring & Observability

### Metrics to Track

1. **Usage Metrics**
   - Total TekMate requests per day
   - Average confidence score
   - High confidence (>85%) rate
   - Low confidence (<70%) rate

2. **Performance Metrics**
   - Average response time
   - 95th percentile response time
   - Error rate
   - Timeout rate

3. **Security Metrics**
   - Admin vs non-admin request ratio (should be 100% admin)
   - Failed authentication attempts
   - Permission denied errors

### Cloud Function Logs

```bash
# View recent logs
firebase functions:log --only tekmateChatProxy

# Filter for errors
firebase functions:log --only tekmateChatProxy | grep ERROR

# Monitor in real-time
firebase functions:log --only tekmateChatProxy --tail
```

## Cost Estimation

### Firebase Cloud Functions
- **Invocations:** $0.40 per million after 2M free
- **Compute Time:** $0.0000025 per GB-second
- **Network:** $0.12 per GB

**Estimated Cost for 1000 TekMate queries/day:**
- ~30,000 invocations/month = FREE (under 2M limit)
- Compute time: ~$0.50/month
- Network: ~$0.10/month
- **Total: ~$0.60/month**

### TekMate API Costs
- Depends on your TekMate backend pricing
- Monitor usage in TekMate dashboard

## Troubleshooting Guide

### Problem: TekMate button not visible for admin

**Diagnosis:**
```dart
// Add debug logging
print('TekMate init: ${await _tekmateService.init()}');
print('Is available: ${_tekmateService.isAvailable}');
```

**Solution:**
1. Check Firestore `users/{uid}` has `role: 'admin'`
2. Verify `_initTekMate()` is called in `initState`
3. Check `_isTekmateAvailable` state updates

### Problem: "Service not configured" error

**Diagnosis:**
Check Firestore document exists:
```
settings/tekmate
  └── apiUrl: ✓ exists?
```

**Solution:**
Create missing document in Firebase Console

### Problem: Network timeout

**Diagnosis:**
Check TekMate backend health:
```bash
curl -X POST https://your-tekmate-api.com/health
```

**Solution:**
1. Verify TekMate backend is running
2. Check CORS configuration
3. Increase Cloud Function timeout

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12-21 | Initial implementation |

---

**Maintained by:** Development Team
**Last Updated:** December 21, 2024
