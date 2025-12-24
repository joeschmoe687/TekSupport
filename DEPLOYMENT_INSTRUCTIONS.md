# TekMate Cloud Function Deployment Instructions

## ✅ Completed (Automated Agent Work)

1. **Fixed package.json** - Removed duplicate fields and syntax errors
2. **Installed dependencies** - All npm packages successfully installed
3. **Cleaned tekmateChatProxy function** - Fixed duplicate code, proper error handling
4. **Code ready for deployment** - All syntax errors resolved

## 🚀 Manual Deployment Steps

### Prerequisites

Ensure you have Firebase CLI installed and authenticated:
```bash
firebase --version
# If not installed: npm install -g firebase-tools
```

### Step 1: Authenticate with Firebase

```bash
# Option A: Interactive login
firebase login

# Option B: CI token (for automated deployments)
# Set FIREBASE_TOKEN environment variable with your token
# Get token with: firebase login:ci
```

### Step 2: Deploy TekMate Function

```bash
cd /home/runner/work/hvac_support_app/hvac_support_app

# Deploy only the tekmateChatProxy function
firebase deploy --only functions:tekmateChatProxy

# Or deploy all functions
firebase deploy --only functions
```

### Step 3: Capture Function URL

After deployment, Firebase will output the function URL. It should look like:
```
✔  functions[tekmateChatProxy(us-central1)] Deployed successfully
   https://us-central1-tekneck-support.cloudfunctions.net/tekmateChatProxy
```

### Step 4: Test Function Endpoint

```bash
# Test 1: Unauthenticated request (should return 401)
curl -X POST https://us-central1-tekneck-support.cloudfunctions.net/tekmateChatProxy \
  -H "Content-Type: application/json" \
  -d '{"data": {"message": "test"}}'

# Expected: {"error": {"message": "Unauthenticated.", "status": "UNAUTHENTICATED"}}
```

### Step 5: Test with Firebase Auth Token

```bash
# Get Firebase auth token for testing (requires Firebase Auth setup)
# This is typically done from your app or using Firebase Admin SDK

# Test with valid admin user token:
curl -X POST https://us-central1-tekneck-support.cloudfunctions.net/tekmateChatProxy \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -d '{
    "data": {
      "message": "How do I troubleshoot low superheat?",
      "context": {
        "refrigerant": "R410A"
      },
      "platform": "app"
    }
  }'
```

## 📋 TekMate Backend Verification (Task 2)

### Prerequisites

These commands require network access to tekmate.airpronwa.com. Run from a machine with proper DNS and network access.

### Test Health Endpoint

```bash
curl -sS https://tekmate.airpronwa.com/health

# Expected response (JSON):
# {"status": "ok", "version": "1.0.0", ...}

# If HTML response: Cloudflare issue (manual task 👤1 needed)
# If timeout: Server may be down (check joloserve)
```

### Test Personality-Chat Endpoint

```bash
curl -sS -X POST https://tekmate.airpronwa.com/api/personality-chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "test",
    "user": "agent-test"
  }'

# Expected: JSON response with AI reply
```

### Check Server Status (SSH Access Required)

```bash
# SSH to joloserve
ssh jolo@192.168.1.117

# Check service status
systemctl status tekmate.service
systemctl status tekmate-proxy.service
systemctl status tekmate-tunnel.service

# If services are down, restart:
sudo systemctl start tekmate.service tekmate-proxy.service tekmate-tunnel.service
```

## ⚙️ Firestore Configuration

Before the function will work properly, you need to configure TekMate settings in Firestore:

1. Go to [Firebase Console](https://console.firebase.google.com/project/tekneck-support/firestore)
2. Create collection: `settings`
3. Create document ID: `tekmate`
4. Add fields:
   - `apiUrl` (string): `https://tekmate.airpronwa.com/api/personality-chat`
   - `apiKey` (string): `[your_api_key]` (get from joloserve if needed)

## ✅ Success Criteria

### Task 1: Deploy TekMate Cloud Function
- [ ] Function deployed successfully
- [ ] Function URL captured and documented
- [ ] Test endpoint returns 401 for unauthenticated requests
- [ ] Function appears in Firebase Console Functions list

### Task 2: Verify TekMate Backend Status
- [ ] Health endpoint returns valid JSON (not HTML)
- [ ] Personality-chat endpoint returns AI response
- [ ] All backend services running on joloserve

## 🔍 Troubleshooting

### Function Deployment Fails

**Error: "Not authenticated"**
```bash
firebase login
# or
export FIREBASE_TOKEN="your-token-here"
```

**Error: "Missing dependencies"**
```bash
cd functions
npm install
```

**Error: "Parse error in index.js"**
- Check for syntax errors with: `node -c index.js`
- Validate with ESLint if available

### Backend Not Accessible

**DNS Resolution Fails**
- Check if domain is accessible: `nslookup tekmate.airpronwa.com`
- May need to update DNS or check Cloudflare settings

**Connection Timeout**
- SSH to joloserve and check service status
- Check firewall rules
- Verify Cloudflare tunnel is running

### Function Returns Errors

**"Service configuration error"**
- Ensure Firestore settings/tekmate document exists
- Verify apiUrl field is set

**"AI service temporarily unavailable"**
- Backend may be down - check joloserve
- API endpoint may have changed
- Check TekMate service logs

## 📝 Notes

- The tekmateChatProxy function enforces admin-only access (Ghost Mode)
- Non-admin users get a generic "Access denied" error
- All interactions are logged to `admin/tekmate_interactions/logs` collection
- Function requires Firestore configuration before it will work properly
