# TekMate Testing Guide

This guide provides step-by-step instructions for testing the TekMate Ghost Mode implementation.

## Prerequisites

1. Firebase project deployed with Cloud Functions
2. Test accounts in Firestore:
   - One admin account (role='admin')
   - One non-admin account (role='tech' or no role)
3. Flutter app installed on test device

## Test Plan

### ✅ Test 1: Admin User Can Access TekMate

**Objective:** Verify admin users see and can use TekMate features

**Setup:**
1. In Firestore Console, set test user as admin:
   ```
   Collection: users
   Document: [YOUR_TEST_USER_ID]
   Fields:
     - role: "admin"
   ```

**Steps:**
1. Launch app and login with admin account
2. Navigate to Admin Chat Sessions (from main menu)
3. Open any chat session
4. Scroll to bottom of chat

**Expected Results:**
- ✅ Purple "Ask TekMate AI" button visible above message input
- ✅ Button has psychology brain icon
- ✅ Button is positioned between attachment button and message field

**Test TekMate Dialog:**
1. Type a test message in the input field (e.g., "How do I check superheat?")
2. Click "Ask TekMate AI" button

**Expected Results:**
- ✅ Dialog appears with "TekMate Suggestion" title
- ✅ Shows confidence percentage (e.g., "88%")
- ✅ Shows AI-generated response text
- ✅ Response relates to the input message
- ✅ "Use This Response" and "Cancel" buttons visible

**Test Response Usage:**
1. Click "Use This Response"

**Expected Results:**
- ✅ Dialog closes
- ✅ Message input field populated with TekMate response
- ✅ Can edit response before sending

**Test Firestore Logging:**
1. Open Firestore Console
2. Navigate to: `admin/tekmate_interactions/logs`

**Expected Results:**
- ✅ New log entry created
- ✅ Contains userId, userEmail, message, response, confidence
- ✅ Timestamp is current

---

### ✅ Test 2: Non-Admin User Cannot Access TekMate (CRITICAL)

**Objective:** Verify TekMate is completely invisible to non-admin users

**Setup:**
1. In Firestore Console, set test user as non-admin:
   ```
   Collection: users
   Document: [OTHER_TEST_USER_ID]
   Fields:
     - role: "tech" (or remove role field entirely)
   ```

**Steps:**
1. Launch app and login with non-admin account
2. Navigate to any chat or screen

**Expected Results:**
- ✅ NO "Ask TekMate AI" button visible anywhere
- ✅ NO TekMate UI elements visible
- ✅ NO TekMate-related menu items
- ✅ App functions normally without any errors

**Test Network Calls:**
1. Open Chrome DevTools (if using web) or device logs
2. Monitor network requests
3. Use app normally, try all features

**Expected Results:**
- ✅ NO calls to `tekmateChatProxy` function
- ✅ NO 403 Forbidden errors in console
- ✅ NO TekMate-related network activity
- ✅ NO console errors related to TekMate

**Test Service Initialization:**
1. Check app logs (if in debug mode)

**Expected Results:**
- ✅ `TekMateChatService.init()` returns false silently
- ✅ NO error messages about TekMate
- ✅ NO warnings about missing permissions

---

### ✅ Test 3: Confidence Scoring

**Objective:** Verify different confidence levels are displayed correctly

**Setup:** Admin account

**Test Cases:**

**3a. High Confidence Query**
1. Type: "What is the normal superheat for R410A?"
2. Click "Ask TekMate AI"

**Expected:**
- ✅ Confidence: 80%+ (green)
- ✅ Green check icon
- ✅ NO warning message

**3b. General/Vague Query**
1. Clear input
2. Type: "Help me"
3. Click "Ask TekMate AI"

**Expected:**
- ✅ Confidence: <70% (orange)
- ✅ Orange warning icon
- ✅ Warning message: "Low confidence - review before sending"

---

### ✅ Test 4: Context Passing

**Objective:** Verify job context is passed to TekMate

**Setup:** Admin account

**Steps:**
1. Open a chat that has customer info
2. Type a message
3. Click "Ask TekMate AI"
4. Check Firestore log entry

**Expected Results:**
- ✅ Log contains `context` object
- ✅ Context includes: roomId, customerId, customerName
- ✅ Context includes: supportType, jobType (if available)

---

### ✅ Test 5: Error Handling

**Objective:** Verify graceful error handling

**Test Cases:**

**5a. Empty Message**
1. Leave message field empty
2. Click "Ask TekMate AI"

**Expected:**
- ✅ Orange snackbar appears
- ✅ Message: "Type a message first, then ask TekMate for help"
- ✅ No error thrown

**5b. Network Error**
1. Disconnect device from internet
2. Type message
3. Click "Ask TekMate AI"

**Expected:**
- ✅ Loading indicator appears
- ✅ Error snackbar after timeout
- ✅ Message: "Error getting TekMate suggestion: [error]"
- ✅ App doesn't crash

**5c. Unauthorized Access**
1. Admin account
2. Revoke admin role in Firestore (while app is running)
3. Type message
4. Click "Ask TekMate AI"

**Expected:**
- ✅ Error response from Cloud Function
- ✅ Graceful error message
- ✅ Button remains disabled after role change

---

### ✅ Test 6: Loading States

**Objective:** Verify proper loading indicators

**Steps:**
1. Admin account
2. Type long message
3. Click "Ask TekMate AI"
4. Observe button during request

**Expected Results:**
- ✅ Button text changes to "Thinking..."
- ✅ Brain icon replaced with spinner
- ✅ Button disabled during loading
- ✅ Loading state clears after response

---

### ✅ Test 7: Security - Cloud Function Auth

**Objective:** Verify Cloud Function rejects unauthenticated requests

**Setup:** Use Postman or curl

**Test Unauthenticated Call:**
```bash
curl -X POST \
  https://us-central1-tekneck-support.cloudfunctions.net/tekmateChatProxy \
  -H "Content-Type: application/json" \
  -d '{"data": {"message": "Test"}}'
```

**Expected:**
- ✅ HTTP 401 Unauthorized
- ✅ Error: "Authentication required"

**Test Non-Admin Authenticated Call:**
1. Get Firebase ID token for non-admin user
2. Make authenticated request

**Expected:**
- ✅ HTTP 403 Forbidden
- ✅ Error: "Access denied"
- ✅ Function logs show: "TekMate access denied for non-admin user"

---

## Security Checklist

Before deploying to production, verify:

- [ ] Non-admin users see ZERO TekMate UI
- [ ] Non-admin users make ZERO TekMate network calls
- [ ] Cloud Function requires Firebase authentication
- [ ] Cloud Function checks admin role in Firestore
- [ ] Cloud Function logs access attempts
- [ ] Firestore rules restrict admin collection to admins only
- [ ] No TekMate references in non-admin device logs
- [ ] No console errors for non-admin users
- [ ] Admin users can successfully use TekMate
- [ ] Confidence scoring works correctly
- [ ] Context is passed to AI service
- [ ] Error handling works gracefully

## Automated Testing (Future)

Consider adding these integration tests:

```dart
// test/tekmate_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TekMate Ghost Mode', () {
    test('Service returns false for non-admin', () async {
      // Mock non-admin user
      final service = TekMateChatService();
      final isAvailable = await service.init();
      expect(isAvailable, false);
    });

    test('Service returns true for admin', () async {
      // Mock admin user
      final service = TekMateChatService();
      final isAvailable = await service.init();
      expect(isAvailable, true);
    });

    test('Non-admin gets null response', () async {
      // Mock non-admin
      final service = TekMateChatService();
      final response = await service.getResponse('test');
      expect(response, null);
    });
  });
}
```

## Bug Reporting

If you find any issues, document:
1. User account type (admin/non-admin)
2. Steps to reproduce
3. Expected vs actual behavior
4. Screenshots/logs
5. Device/platform info

Report to development team immediately if:
- Non-admin users see TekMate UI
- Non-admin users can call TekMate function
- TekMate leaks information in logs
- Security vulnerabilities discovered

---

**Remember: Ghost Mode = Complete Invisibility to Non-Admins**
