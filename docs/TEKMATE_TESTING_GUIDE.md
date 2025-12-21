# TekMate Integration Testing Guide

## Overview
This document provides comprehensive testing procedures for the TekMate AI integration, with a focus on Ghost Mode security.

## Security Requirements (Ghost Mode)
TekMate must be **completely invisible** to non-admin users:
- ✅ No UI elements visible
- ✅ No network calls made
- ✅ No error messages that reveal TekMate exists
- ✅ Service calls return null silently for non-admins

## Test Environment Setup

### Prerequisites
1. Firebase project configured (`tekneck-support`)
2. Cloud Functions deployed
3. TekMate API endpoint configured in Firestore
4. Test users with different roles:
   - Admin user (role='admin')
   - Technician user (role='tech')
   - Customer user (role='customer')

### Firebase Configuration Check
Before testing, verify Firestore document exists:
```
Collection: settings
Document: tekmate
Fields:
  - apiUrl: "https://your-tekmate-endpoint.com/api/chat"
  - apiKey: "your-api-key"
```

## Unit Tests

### Run Unit Tests
```bash
cd /path/to/hvac_support_app
flutter test test/services/tekmate_chat_service_test.dart
```

### Expected Results
All tests should pass:
- ✅ Service is a singleton
- ✅ isAvailable returns false before init
- ✅ isAdmin returns false before init
- ✅ getResponse returns null for non-admin
- ✅ Confidence thresholds work correctly
- ✅ Confidence percent calculation accurate

## Integration Tests

### Test 1: Admin User - TekMate Available

**Login as:** Admin user

**Steps:**
1. Open the app
2. Navigate to any support chat (Admin → Chats → Select chat)
3. Look at the message input area

**Expected Results:**
- ✅ Purple "psychology" icon (🧠) visible next to send button
- ✅ Icon tooltip says "Ask TekMate AI"
- ✅ Icon is enabled (not grayed out)

**Screenshot Required:** Yes - Show TekMate button visible

### Test 2: Admin User - TekMate Interaction

**Login as:** Admin user

**Steps:**
1. Open a support chat with customer messages
2. Tap the TekMate (🧠) button
3. Wait for response (loading indicator should show)

**Expected Results:**
- ✅ Loading indicator appears (purple spinner)
- ✅ Dialog opens with title "TekMate Suggestion"
- ✅ Confidence score badge displayed (e.g., "Confidence: 87%")
- ✅ Badge color matches confidence level:
  - Green: 85%+ (High confidence)
  - Orange: 70-84% (Medium confidence)
  - Red: <70% (Low confidence)
- ✅ AI suggestion text displayed
- ✅ Text is editable
- ✅ Three buttons visible: "Cancel", "Use Suggestion", "Send Now"

**Screenshot Required:** Yes - Show TekMate dialog with confidence score

### Test 3: Admin User - Use Suggestion

**Login as:** Admin user

**Steps:**
1. Get TekMate suggestion (from Test 2)
2. Click "Use Suggestion" button

**Expected Results:**
- ✅ Dialog closes
- ✅ Message input field populated with AI suggestion
- ✅ Message is NOT sent automatically
- ✅ User can edit before sending

### Test 4: Admin User - Send Now

**Login as:** Admin user

**Steps:**
1. Get TekMate suggestion
2. Optionally edit the suggestion text
3. Click "Send Now" button

**Expected Results:**
- ✅ Dialog closes
- ✅ Message sent immediately to chat
- ✅ Message appears in chat history
- ✅ Customer sees the message

### Test 5: Non-Admin User - Ghost Mode (CRITICAL)

**Login as:** Technician or Customer user (NOT admin)

**Steps:**
1. Open the app
2. Navigate to any support chat
3. Look at the message input area
4. Check browser/app network logs

**Expected Results:**
- ✅ NO TekMate button visible (only attachment and send buttons)
- ✅ NO psychology icon anywhere in UI
- ✅ NO network calls to `tekmateChatProxy` function
- ✅ NO console errors about TekMate
- ✅ App functions normally for chat

**Screenshot Required:** Yes - Show message input WITHOUT TekMate button

**Network Log Check:**
```
Filter network requests by: "tekmate"
Expected: 0 results
```

### Test 6: API Error Handling

**Login as:** Admin user

**Steps:**
1. Temporarily misconfigure TekMate (delete Firestore settings/tekmate doc)
2. Open support chat
3. Tap TekMate button

**Expected Results:**
- ✅ Loading indicator shows
- ✅ Error message displayed: "TekMate is temporarily unavailable"
- ✅ No crash or stack trace visible
- ✅ Can continue using chat normally

### Test 7: Network Failure

**Login as:** Admin user

**Steps:**
1. Turn on airplane mode (or disable network)
2. Open support chat
3. Tap TekMate button

**Expected Results:**
- ✅ Loading indicator shows
- ✅ Timeout after reasonable wait (~10 seconds)
- ✅ Error message: "Error getting AI guidance: [error]"
- ✅ No crash
- ✅ Can retry when network restored

### Test 8: Confidence Scoring Display

**Login as:** Admin user

**Steps:**
1. Get multiple TekMate suggestions with varying confidence
2. Note the confidence scores displayed

**Expected Results:**
- ✅ High confidence (85%+): Green badge with checkmark icon
- ✅ Medium confidence (70-84%): Orange badge with info icon
- ✅ Low confidence (<70%): Red badge with warning icon
- ✅ Text below suggestion indicates confidence level:
  - High: "✓ High confidence - Review and send"
  - Low: "⚠ Lower confidence - Verify carefully"

### Test 9: Context Passing

**Login as:** Admin user

**Steps:**
1. Open a support chat with job context (jobId, systemType, etc.)
2. Tap TekMate button
3. Check Cloud Function logs

**Expected Results:**
- ✅ Recent messages included in context
- ✅ Job metadata included if available
- ✅ User ID included
- ✅ Platform set to "app"

**Cloud Function Log Check:**
```
Message: [customer's question]
Context: {
  roomId: "...",
  recentMessages: [...],
  jobId: "...",
  systemType: "AC"
}
```

### Test 10: Interaction Logging

**Login as:** Admin user

**Steps:**
1. Use TekMate to get suggestion
2. Check Firestore collection: `admin/tekmate_interactions/logs`

**Expected Results:**
- ✅ New document created with:
  - userId (admin's UID)
  - message (query sent)
  - context (conversation context)
  - response (AI response)
  - confidence (score)
  - platform ("app")
  - timestamp

## Performance Tests

### Response Time
**Acceptance Criteria:**
- TekMate response within 5 seconds under normal conditions
- Loading indicator displays immediately (<100ms)
- UI remains responsive during API call

### Memory Usage
**Check for memory leaks:**
- Open/close TekMate dialog 10 times
- Monitor app memory usage
- Should not increase significantly

## Security Tests

### Test S1: Authentication Required

**Steps:**
1. Call Cloud Function without auth token (use Postman/curl)

**Expected Results:**
- ✅ HTTP 401 or 403 error
- ✅ Error message: "Authentication required"

### Test S2: Admin Role Required

**Steps:**
1. Call Cloud Function with non-admin user auth token

**Expected Results:**
- ✅ HTTP 403 Forbidden
- ✅ Error message: "Access denied" (generic, no TekMate mention)

### Test S3: Input Validation

**Steps:**
1. Call Cloud Function with missing message
2. Call Cloud Function with invalid data types

**Expected Results:**
- ✅ HTTP 400 Bad Request
- ✅ Error: "Message is required" or "invalid-argument"

## Regression Tests

After each deployment, verify:
- [ ] Payment functions still work
- [ ] Push notifications still work
- [ ] Chat functionality unaffected
- [ ] BLE device connections unaffected
- [ ] Admin dashboard accessible

## Production Monitoring

### Weekly Checks
- [ ] Review `admin/tekmate_interactions/logs` collection
- [ ] Check Cloud Function logs for errors
- [ ] Verify no TekMate calls from non-admin users
- [ ] Monitor API usage and costs

### Alerting Setup
Configure Firebase/Cloud Function alerts for:
- High error rate on `tekmateChatProxy`
- Unusual spike in TekMate requests
- API timeout rates >10%

## Troubleshooting

### Issue: TekMate button not visible for admin
**Solution:**
1. Verify user role in Firestore: `users/{uid}` has `role: 'admin'` or `isAdmin: true`
2. Check `_initTekMate()` is called in initState
3. Verify `_isTekmateAvailable` state updates

### Issue: "TekMate is temporarily unavailable"
**Solution:**
1. Check Firestore `settings/tekmate` document exists
2. Verify `apiUrl` field is set
3. Check TekMate backend is running
4. Review Cloud Function logs for errors

### Issue: Confidence score always 0
**Solution:**
1. Verify TekMate backend returns `confidence` field
2. Check data type is number (not string)
3. Review API response format

### Issue: Network calls visible for non-admins
**CRITICAL SECURITY ISSUE:**
1. Verify `_isTekmateAvailable` is false for non-admins
2. Check UI conditional rendering: `if (_isTekmateAvailable)`
3. Verify `TekMateChatService.init()` checks role correctly
4. Review app logs for unauthorized calls

## Test Results Template

```markdown
## Test Results - [Date]

### Environment
- Firebase Project: tekneck-support
- App Version: [version]
- Platform: Android/iOS
- Tester: [name]

### Unit Tests
- [ ] All unit tests pass
- [ ] No warnings or errors

### Integration Tests
- [ ] Test 1: Admin - TekMate Available ✅/❌
- [ ] Test 2: Admin - TekMate Interaction ✅/❌
- [ ] Test 3: Admin - Use Suggestion ✅/❌
- [ ] Test 4: Admin - Send Now ✅/❌
- [ ] Test 5: Non-Admin - Ghost Mode ✅/❌ (CRITICAL)
- [ ] Test 6: API Error Handling ✅/❌
- [ ] Test 7: Network Failure ✅/❌
- [ ] Test 8: Confidence Scoring ✅/❌
- [ ] Test 9: Context Passing ✅/❌
- [ ] Test 10: Interaction Logging ✅/❌

### Security Tests
- [ ] S1: Authentication Required ✅/❌
- [ ] S2: Admin Role Required ✅/❌
- [ ] S3: Input Validation ✅/❌

### Performance
- Average response time: [X] seconds
- Memory stable: Yes/No

### Issues Found
1. [Issue description]
2. [Issue description]

### Screenshots
- [Attach screenshots for Tests 2, 3, and 5]

### Recommendation
- [ ] Ready for production
- [ ] Needs fixes (see issues)
```

## Sign-Off Checklist

Before marking TekMate integration as complete:
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] Security tests verified Ghost Mode working
- [ ] Performance acceptable (<5s response)
- [ ] Documentation complete
- [ ] Cloud Functions deployed
- [ ] Firestore configured
- [ ] Production monitoring enabled
- [ ] Team trained on testing procedures
- [ ] Screenshots captured for evidence

---

**Last Updated:** December 21, 2024
**Document Version:** 1.0
**Maintained By:** Development Team
