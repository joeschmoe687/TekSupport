# Admin Setup Guide - TekMate & Firebase Auth

> Complete guide for setting up admin users and testing TekMate functionality

---

## 🔑 Creating an Admin User

### Method 1: Firebase Console (Recommended)

1. **Navigate to Firebase Console:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select project: `tekneck-support`

2. **Go to Firestore Database:**
   - Click "Firestore Database" in left menu
   - Navigate to `users` collection

3. **Find the User Document:**
   - Locate the document with the user's UID
   - If the user doesn't exist yet, have them sign up first

4. **Edit User Document:**
   - Click on the user document
   - Add or modify these fields:
     ```
     role: "admin"
     isAdmin: true
     ```
   - Click "Update"

5. **Verify:**
   - User should now have admin access
   - They will need to log out and log back in to refresh their session

### Method 2: Firebase Admin SDK (Programmatic)

```javascript
// In Firebase Admin SDK or Cloud Function
const admin = require('firebase-admin');

async function makeUserAdmin(uid) {
  await admin.firestore()
    .collection('users')
    .doc(uid)
    .set({
      role: 'admin',
      isAdmin: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  
  console.log(`User ${uid} is now an admin`);
}
```

---

## 🧪 Testing Admin Access

### Test Plan

#### 1. **Test Non-Admin User (Ghost Mode Verification)**

Create or log in as a regular user:

```
Email: test.user@example.com
Password: testuser123
```

**Expected Behavior:**
- ✅ User can log in successfully
- ✅ User sees basic app features
- ✅ User does NOT see any TekMate UI
- ✅ User does NOT see "Ask TekMate AI" button in admin chat
- ✅ User cannot access admin dashboard
- ❌ User should see NO evidence that TekMate exists

**How to Verify:**
1. Log in as non-admin user
2. Navigate to all app screens
3. Check for any TekMate-related UI elements
4. Confirm NO admin-only features are visible

#### 2. **Test Admin User (TekMate Access)**

Assign admin role to a test user and log in:

```
Email: admin.test@example.com
Password: admintest123
```

**Expected Behavior:**
- ✅ User can log in successfully
- ✅ User sees admin dashboard tab
- ✅ User sees "Ask TekMate AI" button in chat screens
- ✅ TekMate button shows purple icon (psychology)
- ✅ Clicking TekMate button shows AI response dialog
- ✅ TekMate responses include confidence scores
- ✅ Can copy TekMate suggestions to message field

**How to Verify:**
1. Log in as admin user
2. Navigate to Admin Chat Sessions
3. Open or create a chat
4. Type a message in the input field
5. Look for TekMate button (should be visible)
6. Click TekMate button
7. Verify dialog shows AI response with confidence score

---

## 📱 TekMate UI Locations

### Where TekMate Appears (Admin Only)

#### 1. **Admin Chat Detail Screen**
- **Location:** Admin Chats → Select Chat → Message Input Area
- **Button:** Purple "Ask TekMate AI" button with psychology icon
- **Function:** Provides AI-powered response suggestions for current message

#### 2. **AI Guidance Button**
- **Location:** Above message input in admin chat
- **Button:** Outlined button "Ask TekMate AI" or "Ask Gemini AI"
- **Function:** Analyzes conversation and provides guidance

### Visual Indicators

**TekMate Active:**
- Icon: 🧠 (psychology icon)
- Color: Purple (#7C3AED - AppColors.primaryPurple)
- Text: "Ask TekMate AI"

**Gemini Fallback:**
- Icon: ✨ (auto_awesome icon)
- Color: Cyan (#4EC7F3 - AppColors.primaryCyan)
- Text: "Ask Gemini AI"

---

## 🔐 Security Verification

### Firestore Rules Check

Verify security rules prevent non-admin access:

```javascript
// In firestore.rules
function isAdmin() {
  return isAuthenticated() &&
    exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
    (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' ||
     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true);
}

match /admin/{document=**} {
  // ONLY authenticated admins can access anything under /admin
  allow read, write: if isAdmin();
}
```

### Cloud Function Security Check

Verify Cloud Function checks admin role:

```javascript
// In functions/index.js - tekmateChatProxy
const userDoc = await admin.firestore()
  .collection('users')
  .doc(userId)
  .get();

const userData = userDoc.data();
const isAdmin = userData.role === 'admin' || userData.isAdmin === true;

if (!isAdmin) {
  throw new functions.https.HttpsError(
    'permission-denied',
    'Access denied'
  );
}
```

---

## 🐛 Troubleshooting

### Issue: Admin User Can't See TekMate

**Check:**
1. User document has `role: 'admin'` OR `isAdmin: true`
2. User logged out and back in after role assignment
3. TekMate service initialized successfully (check logs)
4. Check console for TekMate Admin Check logs

**Debug Logs:**
```dart
// In TekMate service initialization
debugPrint('TekMate Admin Check - User: ${user.uid}');
debugPrint('TekMate Admin Check - Doc exists: ${userDoc.exists}');
debugPrint('TekMate Admin Check - Role: ${userData['role']}');
debugPrint('TekMate Admin Check - isAdmin: ${userData['isAdmin']}');
debugPrint('TekMate Admin Check - Result: $_isAdmin');
```

### Issue: Non-Admin Can See TekMate

**This is a CRITICAL security issue!**

**Check:**
1. Verify `_isTekmateAvailable` flag is false for non-admin
2. Check if user document incorrectly has admin role
3. Review code for missing admin checks
4. Check if Ghost Mode is properly implemented

### Issue: TekMate Button Does Nothing

**Check:**
1. Message input field is not empty
2. TekMate Cloud Function is deployed
3. TekMate configuration in Firestore `settings/tekmate`
4. Check browser/app console for errors
5. Verify Cloud Function logs

---

## 📊 Monitoring Admin Access

### Check Admin Activity

```javascript
// Query admin interactions (Cloud Firestore)
admin.firestore()
  .collection('admin')
  .doc('tekmate_interactions')
  .get()
  .then(doc => {
    console.log('Admin TekMate usage:', doc.data());
  });
```

### View TekMate Logs

```bash
# Firebase Cloud Functions logs
firebase functions:log --only tekmateChatProxy

# Recent admin interactions
firebase firestore:get admin/tekmate_interactions
```

---

## 🎯 Testing Checklist

Use this checklist to verify complete implementation:

### Setup
- [ ] Create test admin user in Firebase
- [ ] Assign role: 'admin' to user document
- [ ] Create test non-admin user
- [ ] Deploy Cloud Functions

### Non-Admin User Test
- [ ] Log in as non-admin user
- [ ] Navigate entire app
- [ ] Confirm NO TekMate UI visible
- [ ] Confirm NO admin features visible
- [ ] Check console for no TekMate errors

### Admin User Test
- [ ] Log in as admin user
- [ ] See admin dashboard
- [ ] Open admin chat session
- [ ] See TekMate button in chat
- [ ] Click TekMate button
- [ ] Dialog shows with AI response
- [ ] Confidence score displays
- [ ] Can copy response to message field

### Security Test
- [ ] Attempt Cloud Function call as non-admin (should fail)
- [ ] Try to read `/admin` collection as non-admin (should fail)
- [ ] Verify Firestore security rules block non-admin
- [ ] Check logs show permission denied for non-admin

---

## 📚 Related Documentation

- **TekMate Architecture:** [TEKMATE_ARCHITECTURE.md](TEKMATE_ARCHITECTURE.md)
- **Firebase Development:** [.github/instructions/Firebase-Development.instructions.md](../.github/instructions/Firebase-Development.instructions.md)
- **Testing Guide:** [TEKMATE_TESTING_GUIDE.md](TEKMATE_TESTING_GUIDE.md)
- **Firestore Rules:** [../firestore.rules](../firestore.rules)

---

## ✅ Production Deployment

Before deploying to production:

1. **Test thoroughly** with both admin and non-admin users
2. **Verify security rules** block non-admin access
3. **Deploy Cloud Functions** with proper environment variables
4. **Monitor logs** for any security violations
5. **Document admin users** - keep list of who has admin access
6. **Regular audits** - review admin activity logs monthly

---

**Last Updated:** December 27, 2024  
**Maintained By:** TekNeck Development Team
