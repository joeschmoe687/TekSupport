# TekMate Ghost Mode - Deployment & Security Guide

## 🔒 Security Overview (CRITICAL)

**TekMate is COMPLETELY INVISIBLE to non-admin technicians.**

- Only authenticated admins (role='admin' in Firestore) see TekMate features
- Non-admins get zero TekMate UI, network calls, or evidence of its existence
- `TekMateChatService().init()` returns false for non-admins (silent, no error)
- All TekMate calls go through Cloud Function with Firebase auth + admin role check
- Logs stored in admin-only Firestore collection `admin/tekmate_interactions`

## 📋 Prerequisites

1. **Firebase CLI installed**
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

2. **Firebase project initialized**
   ```bash
   firebase init functions
   # Select JavaScript (not TypeScript)
   # Install dependencies: Yes
   ```

3. **Stripe configuration** (for payment functions)
   ```bash
   firebase functions:config:set stripe.secret_key="sk_test_YOUR_KEY"
   firebase functions:config:set stripe.webhook_secret="whsec_YOUR_SECRET"
   ```

## 🚀 Deployment Steps

### 1. Install Dependencies

```bash
cd functions
npm install
```

This installs:
- firebase-admin
- firebase-functions
- stripe

### 2. Deploy Cloud Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy only TekMate function
firebase deploy --only functions:tekmateChatProxy
```

Expected output:
```
✔  Deploy complete!

Functions:
  tekmateChatProxy(us-central1): https://us-central1-tekneck-support.cloudfunctions.net/tekmateChatProxy
  createPaymentIntent(us-central1): https://...
  stripeWebhook(us-central1): https://...
```

### 3. Verify Deployment

```bash
# Check function logs
firebase functions:log

# Test with Firebase CLI
firebase functions:shell
```

## 🔍 Testing

### Test as Admin User

1. **Set user as admin in Firestore:**
   ```
   Collection: users
   Document: YOUR_USER_ID
   Field: role = "admin" (or isAdmin = true)
   ```

2. **Login to app**
   - Navigate to any support chat
   - You should see "Ask TekMate AI" button above message input
   - Button has purple psychology icon

3. **Test TekMate query:**
   - Type a message in chat input
   - Click "Ask TekMate AI"
   - Should see dialog with AI response and confidence score
   - Click "Use This Response" to copy to message field

4. **Verify in Firestore:**
   ```
   Collection: admin
   Document: tekmate_interactions
   Subcollection: logs
   # Should see your query logged
   ```

### Test as Non-Admin User

1. **Set user as non-admin:**
   ```
   Collection: users
   Document: OTHER_USER_ID
   Field: role = "tech" (or remove role field)
   ```

2. **Login to app**
   - Navigate to any support chat
   - **CRITICAL:** Should NOT see "Ask TekMate AI" button
   - No TekMate features visible anywhere
   - No network calls to tekmateChatProxy

3. **Check browser/app logs:**
   - Should have NO references to TekMate
   - Should have NO failed network calls to tekmateChatProxy
   - Completely invisible

## 🛡️ Security Verification Checklist

- [ ] Non-admin users see zero TekMate UI
- [ ] Non-admin API calls return 403 Forbidden
- [ ] TekMate logs only visible to admins (check Firestore rules)
- [ ] Cloud Function requires authentication
- [ ] Cloud Function checks admin role
- [ ] No TekMate references in non-admin network logs
- [ ] No console errors for non-admins
- [ ] Admin users can successfully use TekMate

## 📊 Monitoring

### View Function Logs

```bash
# All logs
firebase functions:log

# Filter by function
firebase functions:log --only tekmateChatProxy

# Live tail
firebase functions:log --only tekmateChatProxy --new
```

### Monitor Usage

1. **Firebase Console > Functions**
   - Check invocation count
   - Monitor execution time
   - View error rates

2. **Firestore > admin/tekmate_interactions/logs**
   - Query logs by date
   - Analyze common queries
   - Track confidence scores

### Weekly Security Check

**Every week, verify Ghost Mode is working:**

1. Test with non-admin account
2. Check network logs for TekMate calls (should be ZERO)
3. Verify no UI leaks
4. Review admin logs for unauthorized access attempts

## 🔧 Troubleshooting

### "Permission denied" when calling TekMate

**Cause:** User is not admin

**Solution:** 
1. Check Firestore users/{userId} document
2. Verify role='admin' or isAdmin=true
3. Restart app after updating role

### "TekMate is not available"

**Cause:** Cloud Function not deployed or auth failed

**Solution:**
```bash
# Redeploy function
firebase deploy --only functions:tekmateChatProxy

# Check function exists
firebase functions:list
```

### Non-admin sees TekMate button

**CRITICAL SECURITY ISSUE**

**Solution:**
1. Check TekMateChatService.init() is called
2. Verify _isTekMateAvailable is false for non-admins
3. Check UI conditional: `if (_isTekMateAvailable)`
4. Clear app cache and restart

### TekMate responses are generic

**Expected behavior** - This is the mock implementation

**Solution:**
- Replace `generateMockTekMateResponse()` in functions/index.js
- Integrate with actual TekMate AI service (tekmate-consolidated repo)
- Update endpoint URL in function

## 📝 Firestore Security Rules

Add to firestore.rules:

```javascript
// Admin-only TekMate logs
match /admin/{document=**} {
  allow read, write: if request.auth != null && 
    (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' ||
     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true);
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

## 🔗 Integration with TekMate Consolidated

When ready to connect to actual TekMate AI:

1. **Replace mock function in functions/index.js:**
   ```javascript
   // Remove generateMockTekMateResponse()
   // Add actual API call:
   const axios = require('axios');
   
   const tekMateResponse = await axios.post(
     'https://tekmate-api.your-domain.com/chat',
     {
       message,
       context: userContext,
       userId,
     },
     {
       headers: {
         'Authorization': `Bearer ${TEKMATE_API_KEY}`,
       },
     }
   );
   ```

2. **Add API key to Firebase config:**
   ```bash
   firebase functions:config:set tekmate.api_key="YOUR_API_KEY"
   ```

3. **Redeploy:**
   ```bash
   firebase deploy --only functions:tekmateChatProxy
   ```

## 📱 App Updates

After deployment, ensure app is using latest:

```bash
# Flutter app
flutter pub get
flutter clean
flutter build apk --release

# Test on device
flutter run --release
```

## 🎯 Success Criteria

- ✅ Cloud Functions deployed successfully
- ✅ Admin users see TekMate button
- ✅ Non-admin users see NO TekMate features
- ✅ TekMate responses work with confidence scores
- ✅ Logs captured in Firestore admin collection
- ✅ No security leaks or unauthorized access
- ✅ Weekly monitoring in place

## 🆘 Support

For issues:
1. Check Firebase Functions logs
2. Verify Firestore user roles
3. Test with both admin and non-admin accounts
4. Review security rules
5. Check app network logs

---

**Remember: TekMate is Ghost Mode - completely invisible to non-admins!**
