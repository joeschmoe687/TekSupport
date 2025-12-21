# TekMate Ghost Mode - Quick Start

## 🚀 Deploy in 3 Commands

```bash
# 1. Navigate to project
cd /path/to/hvac_support_app

# 2. Run deployment script
./scripts/deploy-tekmate.sh

# 3. Done! Test the app
```

## ⚙️ Manual Deployment

If you prefer manual steps:

```bash
# Install function dependencies
cd functions
npm install

# Deploy everything
firebase deploy --only functions,firestore:rules

# Or deploy selectively
firebase deploy --only functions:tekmateChatProxy
firebase deploy --only firestore:rules
```

## 🔍 Quick Testing

### Admin Test (Should See TekMate)
1. Set user role in Firestore:
   ```
   Collection: users
   Document: [your_uid]
   Field: role = "admin"
   ```
2. Login to app
3. Open any chat
4. ✅ Should see purple "Ask TekMate AI" button

### Non-Admin Test (Should See Nothing)
1. Set user role:
   ```
   Field: role = "tech" (or no role)
   ```
2. Login to app
3. Open any chat
4. ✅ Should NOT see TekMate button

## 📊 Monitor

```bash
# View function logs
firebase functions:log --only tekmateChatProxy

# Live logs
firebase functions:log --only tekmateChatProxy --new

# Check TekMate usage in Firestore
# Navigate to: admin/tekmate_interactions/logs
```

## 🆘 Troubleshooting

### "Permission denied" error
**Fix:** User needs `role: "admin"` in Firestore users collection

### Function not found
**Fix:** Deploy functions: `firebase deploy --only functions`

### Non-admin sees TekMate button
**CRITICAL BUG:** Check these files:
- `lib/screens/admin_chat_detail_screen.dart` - Line with `if (_isTekMateAvailable)`
- `lib/services/tekmate_chat_service.dart` - `init()` should return false for non-admins

## 📖 Full Documentation

- **GHOST_MODE_DEPLOYMENT.md** - Complete deployment guide
- **TEKMATE_TESTING.md** - Full test plan with 7 scenarios
- **functions/README.md** - Cloud Functions documentation

## ✅ Success Checklist

- [ ] Cloud Functions deployed
- [ ] Firestore rules deployed  
- [ ] Admin user can see TekMate button
- [ ] Non-admin user sees nothing
- [ ] TekMate responses work
- [ ] Logs appear in Firestore admin collection
- [ ] No security leaks

## 🔐 Security Reminder

**TekMate is Ghost Mode:**
- Completely invisible to non-admins
- No UI, no network calls, no evidence
- Only authenticated admins with role='admin'

Test with both account types before production!
