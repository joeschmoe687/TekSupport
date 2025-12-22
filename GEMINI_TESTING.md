# Gemini AI Integration - Testing Guide

## Overview
This guide covers testing the Gemini AI integration including admin controls, auto-response functionality, and fallback behavior.

## Prerequisites
- Admin account with `role: 'admin'` in Firestore
- Customer test account
- Google Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey)

## Setup Steps

### 1. Deploy Cloud Functions
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

Wait for deployment to complete. Verify these functions are deployed:
- `autoRespondWithGemini`
- `tekmateChatProxy`
- `sendPushNotificationOnNewMessage`
- `sendPushNotificationOnAdminReply`

### 2. Configure Gemini in Firestore

**Option A: Using Firebase Console**
1. Open [Firebase Console](https://console.firebase.google.com/project/tekneck-support/firestore)
2. Navigate to Firestore Database
3. Go to `settings` collection
4. Create or update document `gemini` with:
   ```json
   {
     "enabled": true,
     "apiKey": "AIza...",
     "personality": "You are a helpful HVAC technical support assistant. Provide clear, professional guidance to customers. Be concise and practical. Mention that a technician will review this chat soon."
   }
   ```

**Option B: Using Admin App (Preferred)**
1. Open app as admin user
2. Navigate to **Admin Dashboard** → **Settings**
3. Scroll to **Gemini AI Assistant** section
4. Tap **"Set API Key"** and paste your API key
5. Toggle **"Enable Gemini AI"** to ON
6. Optionally customize **"Personality Tuning"**

### 3. Verify Admin Status
Check your user document in Firestore:
```
Collection: users
Document: <your-uid>
Required fields:
  - role: "admin"
  OR
  - isAdmin: true
```

## Test Cases

### Test 1: Admin UI - Settings Access
**Goal:** Verify admin can access Gemini settings

1. Open app as admin user
2. Navigate to **Admin Dashboard**
3. Select **Settings** tab
4. Verify you see:
   - "General Settings" section
   - "Gemini AI Assistant" section with:
     - Enable/Disable toggle
     - API Key button
     - Personality Tuning button

**Expected:** All Gemini controls visible with purple/cyan styling

### Test 2: Admin UI - API Key Configuration
**Goal:** Test API key setup flow

1. In Settings → Gemini AI Assistant
2. Tap **"Set API Key"**
3. Enter test API key: `AIza_test_key_123`
4. Tap **Save**
5. Check Firestore: `settings/gemini/apiKey` should be updated
6. Return to Settings, verify button shows "API Key Configured"

**Expected:** API key saved, status indicator updates

### Test 3: Admin UI - Personality Tuning
**Goal:** Test personality customization

1. In Settings → Gemini AI Assistant
2. Tap **"Personality Tuning"**
3. Edit the personality prompt:
   ```
   You are a friendly HVAC expert. Use simple language.
   Keep responses under 3 sentences. Always ask clarifying questions.
   ```
4. Tap **Save**
5. Check Firestore: `settings/gemini/personality` should be updated

**Expected:** Personality saved, confirmed with snackbar

### Test 4: Admin Chat - Manual AI Assistance
**Goal:** Test manual AI request in admin chat

1. Create a test support room with a customer message:
   - Customer: "My AC is blowing warm air, what should I check?"
2. Open chat as admin (this auto-claims the chat)
3. Verify you see button: "Ask TekMate AI" OR "Ask Gemini AI"
4. Tap the AI button
5. Wait for response dialog
6. Verify:
   - Dialog title shows "TekMate Suggestion" or "Gemini Suggestion"
   - Response text appears
   - Confidence score is shown
   - Can edit before sending

**Expected:** AI provides HVAC troubleshooting guidance

### Test 5: Auto-Response - Unclaimed Chat
**Goal:** Test automatic Gemini responses for unclaimed chats

1. Ensure Gemini is enabled in settings
2. Create new support room as customer
3. As customer, send message:
   - "I need help with my furnace not heating properly"
4. Wait 5-10 seconds
5. Check chat messages
6. Verify:
   - Gemini responds automatically
   - Response includes AI disclaimer
   - Room shows `aiResponded: true`
   - Last message shows "🤖 AI: ..."

**Expected:** Gemini responds within 10 seconds with helpful guidance

### Test 6: Auto-Response - Claimed Chat
**Goal:** Verify AI doesn't auto-respond to claimed chats

1. Create new support room as customer
2. Send initial message: "Need help with AC"
3. Open chat as admin (auto-claims)
4. As customer, send another message: "It's making noise"
5. Wait 10 seconds
6. Verify:
   - No auto-response from Gemini
   - Only customer message appears
   - Admin notification sent

**Expected:** No auto-response once admin claims chat

### Test 7: Auto-Response - Short Messages
**Goal:** Verify AI skips short/greeting messages

1. Create new support room as customer
2. Send short message: "Hello"
3. Wait 10 seconds
4. Verify: No auto-response

5. Send longer message: "My heat pump is making a loud buzzing sound"
6. Wait 10 seconds
7. Verify: Gemini responds

**Expected:** AI only responds to substantive messages (>10 chars)

### Test 8: Fallback Behavior - TekMate Down
**Goal:** Test Gemini fallback when TekMate unavailable

1. Simulate TekMate unavailable:
   - In Firestore, set `settings/tekmate/apiUrl` to invalid URL
   OR
   - Simply ensure TekMate config is missing
2. Open admin chat with customer messages
3. Tap AI assistance button
4. Verify:
   - Button shows "Ask Gemini AI" (not TekMate)
   - Icon is sparkle (not psychology)
   - Response comes from Gemini

**Expected:** Seamless fallback to Gemini

### Test 9: Conversation Context
**Goal:** Verify AI uses conversation history

1. Create new support room as customer
2. Send messages in sequence:
   - "I have a Carrier AC unit"
   - "It's 5 years old"
   - "Now it's not cooling properly"
3. Check AI auto-response for third message
4. Verify response references:
   - Carrier brand
   - Unit age
   - Cooling issue

**Expected:** AI shows awareness of conversation context

### Test 10: Disabled State
**Goal:** Verify behavior when Gemini is disabled

1. In Settings, toggle "Enable Gemini AI" to OFF
2. Create new unclaimed support room
3. Send customer message
4. Wait 10 seconds
5. Verify: No auto-response

6. Open chat as admin
7. Verify: No AI assistance button shown

**Expected:** No AI functionality when disabled

## Troubleshooting

### No Auto-Response
**Check:**
- [ ] Gemini enabled: `settings/gemini/enabled = true`
- [ ] API key set: `settings/gemini/apiKey` exists
- [ ] Chat unclaimed: `supportRooms/{id}/claimedBy` is null
- [ ] Message length > 10 characters
- [ ] Cloud Function deployed: `firebase functions:log --only autoRespondWithGemini`

### API Key Errors
**Symptoms:** Error in logs: "API key not valid"
**Fix:**
1. Verify API key at [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Check key has no spaces/newlines
3. Regenerate key if needed
4. Update in Firestore

### Admin UI Not Showing Gemini
**Check:**
- [ ] User has `role: 'admin'` or `isAdmin: true`
- [ ] App updated to latest version
- [ ] `lib/screens/admin_dashboard_screen.dart` includes Gemini section

### Confidence Score Always Low
**Note:** This is normal initially. Confidence estimation is heuristic-based.
**To improve:**
- Tune personality for more specific/technical language
- Gemini responses with measurements and technical terms score higher

## Firestore Schema Reference

### Collection: `settings` / Document: `gemini`
```typescript
{
  enabled: boolean,        // Enable/disable Gemini
  apiKey: string,          // Google Gemini API key
  personality: string      // System instruction for AI
}
```

### Collection: `supportRooms` / Document: `{roomId}`
```typescript
{
  status: string,          // 'unclaimed', 'claimed', 'completed'
  claimedBy: string | null, // Admin UID or null
  hasLiveTech: boolean,    // True when admin is active
  aiResponded: boolean,    // True if Gemini auto-responded
  lastMessage: string,     // Last message preview
  // ... other fields
}
```

### Subcollection: `supportRooms/{roomId}/messages`
```typescript
{
  role: string,            // 'user', 'support', 'assistant'
  senderType: string,      // 'customer', 'tech', 'ai'
  from: string,           // 'customer', 'tech', 'gemini'
  text: string,           // Message content
  aiGenerated: boolean,   // True for AI messages
  createdAt: Timestamp,
  // ... other fields
}
```

## Cloud Function Logs

### Check Auto-Response Logs
```bash
firebase functions:log --only autoRespondWithGemini
```

Look for:
- "Chat {id} is claimed by {uid}, skipping auto-response"
- "Gemini not enabled or API key missing"
- "Message too short, skipping auto-response"
- "Gemini auto-responded to chat {id}"
- Errors: API issues, Firestore errors

### Enable Debug Logging
Add to `functions/.env.local`:
```
DEBUG=gemini:*
```

## Success Criteria
✅ All 10 test cases pass
✅ No errors in Cloud Function logs
✅ Admin can configure Gemini via UI
✅ Auto-response works for unclaimed chats
✅ Auto-response stops when admin claims
✅ Fallback from TekMate to Gemini works
✅ Personality tuning affects responses
✅ No functionality visible to non-admin users

## Known Limitations
- Auto-response limited to English (Gemini default)
- Confidence scoring is heuristic, not from API
- Rate limits: 60 requests/minute (Gemini free tier)
- Response time: 2-5 seconds typical
- Context window: Last 5 messages only
