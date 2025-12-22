---
applyTo: 'lib/services/**,lib/screens/*chat*,lib/screens/*admin*'
---

# Firebase Development Guide

> Instructions for working with Firebase services (Firestore, Auth, Functions, FCM)

## 🔥 Firebase Project Structure

### Shared Firebase Backend
**CRITICAL:** This app shares Firebase project `tekneck-support` with:
- **AirPro Website** - Web dashboard at airpronwa.com
- **TekMate AI** - Consolidated AI backend

**Before modifying anything Firebase-related:**
1. Check impact on web dashboard
2. Check impact on TekMate AI integration
3. Test on staging first
4. Coordinate with team if changing shared resources

## 📊 Firestore Collections

### Shared Collections (Read/Write Access)

#### `chats` - Customer Support Sessions
```javascript
{
  chatId: string,
  userId: string,              // Customer user ID
  status: 'new' | 'open' | 'claimed' | 'completed',
  createdAt: Timestamp,
  updatedAt: Timestamp,
  claimedBy: string?,          // Admin user ID
  claimedByName: string?,      // Admin display name
  completedAt: Timestamp?,
  completedBy: string?,
  hasLiveTech: boolean,        // True when admin is active
  lastMessage: string,
  lastMessageFrom: 'customer' | 'admin',
  messages: [                  // Subcollection
    {
      text: string,
      senderId: string,
      senderName: string,
      createdAt: Timestamp,
      type: 'text' | 'system',
    }
  ]
}
```

**Used by:**
- Mobile app: Customer and admin chat interfaces
- Web dashboard: Admin chat management
- TekMate AI: Chat context for guidance

#### `users` - User Profiles
```javascript
{
  uid: string,
  email: string,
  displayName: string?,
  phone: string?,
  role: 'customer' | 'tech' | 'admin',
  fcmToken: string?,           // For push notifications
  createdAt: Timestamp,
  lastLogin: Timestamp,
  preferences: {
    notifications: boolean,
    theme: 'light' | 'dark',
  }
}
```

**Used by:**
- Mobile app: User profile, role-based UI
- Web dashboard: User management
- Cloud Functions: Push notification routing

#### `customers` - CRM Data
```javascript
{
  customerId: string,
  name: string,
  email: string,
  phone: string,
  address: {
    street: string,
    city: string,
    state: string,
    zip: string,
  },
  createdAt: Timestamp,
  lastContact: Timestamp,
  notes: string,
  totalJobs: number,
  totalRevenue: number,
}
```

**Used by:**
- Web dashboard: CRM management (primary)
- Mobile app: Read-only customer info in dispatch

#### `jobs` - Work Orders / Dispatch
```javascript
{
  jobId: string,
  customerId: string,
  assignedTech: string?,
  status: 'scheduled' | 'in_progress' | 'completed',
  scheduledDate: Timestamp,
  completedDate: Timestamp?,
  location: {
    address: string,
    coordinates: GeoPoint,
  },
  equipment: string,
  description: string,
  notes: string,
}
```

**Used by:**
- Web dashboard: Job creation and management
- Mobile app: Technician dispatch view

#### `ble_sniff_logs` - BLE Protocol Captures
```javascript
{
  sessionId: string,
  deviceId: string,
  deviceName: string,
  manufacturer: string?,
  capturedAt: Timestamp,
  capturedBy: string,          // User ID
  services: [
    {
      uuid: string,
      characteristics: [
        {
          uuid: string,
          properties: string[],
          logs: [
            {
              timestamp: Timestamp,
              type: 'read' | 'notify' | 'write',
              data: string,        // Hex string
            }
          ]
        }
      ]
    }
  ]
}
```

**Used by:**
- Mobile app: BLE Sniffer uploads
- TekMate AI: Protocol learning and device integration

### Admin-Only Collections

#### `admin/tekmate_interactions` - AI Logs
```javascript
{
  interactionId: string,
  adminUid: string,
  chatId: string?,
  query: string,
  response: string,
  confidence: number,
  timestamp: Timestamp,
  accepted: boolean?,          // Did admin use suggestion?
}
```

**Security:** Only accessible to users with `role='admin'`

#### `settings/*` - App Configuration
```javascript
// settings/pricing
{
  businessHours: {
    message: number,
    phone: number,
    video: number,
  },
  afterHours: {
    message: number,
    phone: number,
    video: number,
  }
}

// settings/gemini
{
  enabled: boolean,
  apiKey: string,
  personality: string,
}
```

## 🔐 Security Rules

### Current Rules Structure
```
firestore.rules
├── /chats - Read: auth, Write: auth
├── /users - Read: auth, Write: own or admin
├── /customers - Read: auth, Write: admin
├── /jobs - Read: auth, Write: admin
├── /admin - Read/Write: admin only
└── /settings - Read: auth, Write: admin
```

### Testing Security Rules
```bash
# Install Firebase emulator
npm install -g firebase-tools

# Start emulator
firebase emulators:start --only firestore

# Run security rule tests
firebase emulators:exec --only firestore "flutter test test/firestore_rules_test.dart"
```

### Modifying Security Rules

**NEVER modify rules directly in production!**

1. **Edit** `firestore.rules`
2. **Test locally** with emulator
3. **Deploy to staging** first
4. **Test mobile app** on staging
5. **Test web dashboard** on staging
6. **Monitor logs** for auth failures
7. **Deploy to production** if all tests pass

```bash
# Deploy rules to staging
firebase deploy --only firestore:rules --project tekneck-support-staging

# Deploy to production (after testing)
firebase deploy --only firestore:rules --project tekneck-support
```

## 🔔 Firebase Cloud Messaging (FCM)

### Push Notification Flow

1. **User logs in** → FCM token generated
2. **Token saved** → `users/{uid}.fcmToken`
3. **Event occurs** → Cloud Function triggered
4. **Function sends notification** → FCM to device token
5. **App receives** → `NotificationService` handles

### Notification Categories

**Admin Notifications:**
```javascript
{
  title: 'New Customer Message',
  body: 'John Doe: I need help with...',
  data: {
    type: 'new_message',
    chatId: 'chat123',
    senderId: 'user456',
  }
}
```

**Customer Notifications:**
```javascript
{
  title: 'Technician Reply',
  body: 'Mike responded: I can help you...',
  data: {
    type: 'admin_reply',
    chatId: 'chat123',
    senderId: 'admin789',
  }
}
```

### Handling Notifications

In `lib/services/notification_service.dart`:

```dart
Future<void> handleNotificationTap(RemoteMessage message) async {
  final type = message.data['type'];
  final chatId = message.data['chatId'];
  
  switch (type) {
    case 'new_message':
      // Navigate to admin chat
      Navigator.pushNamed(context, '/admin-chat', arguments: chatId);
      break;
    case 'admin_reply':
      // Navigate to customer chat
      Navigator.pushNamed(context, '/chat', arguments: chatId);
      break;
  }
}
```

## ☁️ Cloud Functions

### Deployed Functions

#### `tekmateChatProxy` - TekMate AI Gateway
**Trigger:** HTTPS request  
**Auth:** Firebase Auth required + admin role check  
**Purpose:** Proxy requests to TekMate AI backend

```javascript
// Request
POST https://us-central1-tekneck-support.cloudfunctions.net/tekmateChatProxy
Authorization: Bearer <firebase-id-token>
Body: { query: string, context: object }

// Response
{
  response: string,
  confidence: number,
  timestamp: string,
}
```

**Security:**
- Validates Firebase ID token
- Checks `role='admin'` in users collection
- Returns 403 for non-admins

#### `sendPushNotificationOnNewMessage` - Customer Message Alert
**Trigger:** Firestore onCreate `chats/{chatId}/messages/{messageId}`  
**Action:** Sends push notification to all admin users

#### `sendPushNotificationOnAdminReply` - Admin Reply Alert
**Trigger:** Firestore onCreate `chats/{chatId}/messages/{messageId}`  
**Action:** Sends push notification to customer who owns chat

#### `autoRespondWithGemini` - AI Auto-Response
**Trigger:** Firestore onCreate `chats/{chatId}/messages/{messageId}`  
**Condition:** Chat is unclaimed AND Gemini enabled  
**Action:** Generates AI response, adds to chat

### Deploying Functions

```bash
# Deploy all functions
cd functions
npm install
npm run deploy

# Deploy specific function
firebase deploy --only functions:tekmateChatProxy

# View logs
firebase functions:log --only tekmateChatProxy
```

### Calling Functions from Flutter

```dart
import 'package:cloud_functions/cloud_functions.dart';

final functions = FirebaseFunctions.instance;

// Call tekmateChatProxy
final result = await functions
    .httpsCallable('tekmateChatProxy')
    .call({
      'query': 'How do I fix low superheat?',
      'context': {
        'chatId': chatId,
        'refrigerant': 'R410A',
      },
    });

final response = result.data['response'];
final confidence = result.data['confidence'];
```

## 🔄 Real-Time Listeners

### Best Practices

**DO:**
```dart
StreamSubscription? _chatSubscription;

@override
void initState() {
  super.initState();
  _chatSubscription = FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .snapshots()
      .listen(_handleChatUpdate);
}

@override
void dispose() {
  _chatSubscription?.cancel();
  super.dispose();
}
```

**DON'T:**
```dart
// ❌ Creates memory leak
@override
void initState() {
  super.initState();
  FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .snapshots()
      .listen(_handleChatUpdate);
  // Missing subscription tracking and cancel!
}
```

### Listening to Subcollections

```dart
// Chat messages (subcollection)
FirebaseFirestore.instance
    .collection('chats')
    .doc(chatId)
    .collection('messages')
    .orderBy('createdAt', descending: false)
    .snapshots()
    .listen((snapshot) {
      final messages = snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();
      setState(() => _messages = messages);
    });
```

### Query Optimization

```dart
// ✅ GOOD - Uses index, fast
.where('status', isEqualTo: 'open')
.where('claimedBy', isEqualTo: userId)
.limit(50)

// ❌ BAD - No index, slow
.where('status', isIn: ['open', 'claimed', 'completed'])
.orderBy('updatedAt', descending: true)
// Requires composite index!

// ✅ GOOD - Manual sorting in Dart
final docs = await collection.get();
final sorted = docs.docs.toList()
  ..sort((a, b) => b['updatedAt'].compareTo(a['updatedAt']));
```

## 🗄️ Firestore Indexes

### Required Indexes
Add to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "chats",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "jobs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "assignedTech", "order": "ASCENDING" },
        { "fieldPath": "scheduledDate", "order": "ASCENDING" }
      ]
    }
  ]
}
```

Deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

## 🚨 Error Handling

### Common Firebase Errors

```dart
try {
  await FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .update({'status': 'claimed'});
} on FirebaseException catch (e) {
  switch (e.code) {
    case 'permission-denied':
      _showError('You do not have permission to claim this chat');
      break;
    case 'not-found':
      _showError('Chat not found');
      break;
    case 'unavailable':
      _showError('Firebase is offline. Check your connection.');
      break;
    default:
      _showError('Failed to update chat: ${e.message}');
  }
}
```

### Offline Persistence

Firestore offline persistence is enabled by default:

```dart
// In firebase_options.dart initialization
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

**Behavior:**
- Writes queued when offline
- Reads served from cache
- Auto-syncs when online
- Optimistic updates (feels instant)

## 📖 Reference

### Firebase Services Used
- ✅ **Firestore** - NoSQL database
- ✅ **Authentication** - User management
- ✅ **Cloud Functions** - Serverless backend
- ✅ **Cloud Messaging** - Push notifications
- ✅ **Cloud Storage** - File uploads (future)
- ❌ **Crashlytics** - Crash reporting (planned)
- ❌ **Analytics** - Usage tracking (planned)

### Useful Commands
```bash
# View Firestore data
firebase firestore:export backup/

# Import data
firebase firestore:import backup/

# Delete collection (BE CAREFUL!)
firebase firestore:delete chats --recursive

# Monitor real-time changes
firebase firestore:watch chats
```

### Firebase Console Links
- [Firestore Database](https://console.firebase.google.com/project/tekneck-support/firestore)
- [Authentication](https://console.firebase.google.com/project/tekneck-support/authentication)
- [Cloud Functions](https://console.firebase.google.com/project/tekneck-support/functions)
- [Cloud Messaging](https://console.firebase.google.com/project/tekneck-support/messaging)
- [Usage & Billing](https://console.firebase.google.com/project/tekneck-support/usage)

### Documentation
- [FlutterFire](https://firebase.flutter.dev/)
- [Firestore Data Model](https://firebase.google.com/docs/firestore/data-model)
- [Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Cloud Functions](https://firebase.google.com/docs/functions)
