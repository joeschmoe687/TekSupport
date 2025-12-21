# TekMate Integration Quick Reference

## 🔒 Ghost Mode Security - CRITICAL

TekMate is **completely invisible** to non-admin users.

### Security Checklist
- ✅ UI: Conditional rendering `if (_isTekmateAvailable)`
- ✅ Service: Returns `null` for non-admins
- ✅ Cloud Function: Checks `role === 'admin'`
- ✅ No error messages revealing TekMate exists

## 📁 Key Files

| File | Purpose |
|------|---------|
| `lib/services/tekmate_chat_service.dart` | Client-side service |
| `lib/screens/admin_chat_detail_screen.dart` | UI integration |
| `functions/index.js` | Cloud Function (tekmateChatProxy) |
| `test/services/tekmate_chat_service_test.dart` | Unit tests |
| `docs/TEKMATE_TESTING_GUIDE.md` | Full testing guide |

## 🚀 Quick Start

### 1. Deploy Cloud Function
```bash
cd functions
npm install
firebase deploy --only functions:tekmateChatProxy
```

### 2. Configure Firestore
Create document: `settings/tekmate`
```json
{
  "apiUrl": "https://your-tekmate-api.com/api/chat",
  "apiKey": "your-api-key"
}
```

### 3. Test Admin Access
1. Login as admin user
2. Open support chat
3. Look for purple 🧠 icon
4. Tap to get AI suggestion

### 4. Test Ghost Mode (CRITICAL)
1. Login as non-admin
2. Open support chat
3. Verify NO 🧠 icon visible
4. Check network logs - NO tekmate calls

## 🎨 UI Components

### TekMate Button
```dart
if (_isTekmateAvailable) ...[
  IconButton(
    icon: Icon(Icons.psychology, color: AppColors.primaryPurple),
    onPressed: _getTekmateGuidance,
    tooltip: 'Ask TekMate AI',
  ),
]
```

### Confidence Colors
- 🟢 Green: 85%+ (High confidence)
- 🟠 Orange: 70-84% (Medium)
- 🔴 Red: <70% (Low)

## 🔧 API Reference

### Cloud Function: tekmateChatProxy

**Endpoint:** Firebase Cloud Functions
**Auth:** Required (Firebase Auth + admin role)

**Request:**
```json
{
  "message": "How do I troubleshoot low superheat?",
  "context": {
    "jobId": "job_123",
    "refrigerant": "R410A",
    "systemType": "AC"
  },
  "platform": "app"
}
```

**Response:**
```json
{
  "response": "Low superheat usually indicates...",
  "confidence": 0.92,
  "autoRespond": false
}
```

**Errors:**
- `unauthenticated`: No auth token
- `permission-denied`: Not admin
- `invalid-argument`: Missing message
- `failed-precondition`: Config missing
- `internal`: API error

## 🧪 Testing Commands

### Run Unit Tests
```bash
flutter test test/services/tekmate_chat_service_test.dart
```

### Check Code Quality
```bash
flutter analyze lib/services/tekmate_chat_service.dart
flutter analyze lib/screens/admin_chat_detail_screen.dart
```

### View Cloud Function Logs
```bash
firebase functions:log --only tekmateChatProxy
```

## 🐛 Common Issues

### Button Not Visible (Admin)
1. Check Firestore: `users/{uid}` has `role: 'admin'`
2. Verify `_initTekMate()` called
3. Check `_isTekmateAvailable` state

### "Service Not Configured" Error
1. Create `settings/tekmate` document
2. Add `apiUrl` field
3. Redeploy Cloud Function

### Button Visible (Non-Admin) 🚨
**SECURITY ISSUE!**
1. Check role detection logic
2. Verify `_isTekmateAvailable` is false
3. Review conditional rendering

## 📊 Monitoring

### Firebase Console
1. Functions → tekmateChatProxy
2. View invocations, errors, logs
3. Check execution time

### Firestore Logs
Collection: `admin/tekmate_interactions/logs`
- View all TekMate queries
- Check confidence scores
- Analyze usage patterns

## 🔗 Related Documentation

- [TEKMATE_TESTING_GUIDE.md](TEKMATE_TESTING_GUIDE.md) - Full testing procedures
- [TODO.md](../TODO.md) - Deployment checklist
- [README.md](../README.md) - Project overview

## 💡 Tips

1. **Test Ghost Mode first** - Most critical security requirement
2. **Review confidence scores** - Train team on when to trust AI
3. **Monitor API costs** - TekMate calls consume Cloud Function quota
4. **Log everything** - Interaction logs help improve AI over time
5. **Keep secrets secure** - Never commit API keys

## 📞 Support

For issues:
1. Check Cloud Function logs
2. Review Firestore configuration
3. Test with different user roles
4. Consult TEKMATE_TESTING_GUIDE.md

---

**Quick Check:** Can non-admin users see TekMate? **NO!** ✅
