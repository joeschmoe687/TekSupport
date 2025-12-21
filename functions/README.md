# Firebase Cloud Functions for Payment Processing

This directory contains Cloud Functions for handling Stripe payment operations.

## Setup

### 1. Initialize Firebase Functions (if not already done)

```bash
firebase init functions
```

Choose JavaScript or TypeScript.

### 2. Install Dependencies

```bash
cd functions
npm install
npm install stripe --save
```

### 3. Configure Stripe Keys

Set your Stripe secret key as a Firebase Functions config variable:

```bash
# Test mode
firebase functions:config:set stripe.secret_key="sk_test_YOUR_TEST_SECRET_KEY"

# Production mode (when ready)
firebase functions:config:set stripe.secret_key="sk_live_YOUR_LIVE_SECRET_KEY"
```

### 4. Add Payment Functions

Copy the contents of `payment-functions.js` into your `functions/index.js` file, or import it:

**Option A: Direct copy**
```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const stripe = require('stripe')(functions.config().stripe.secret_key);

admin.initializeApp();

// Paste the exports.createPaymentIntent function here
// Paste the exports.stripeWebhook function here
```

**Option B: Import**
```javascript
// functions/index.js
const paymentFunctions = require('./payment-functions');
exports.createPaymentIntent = paymentFunctions.createPaymentIntent;
exports.stripeWebhook = paymentFunctions.stripeWebhook;
```

### 5. Deploy Functions

```bash
firebase deploy --only functions:createPaymentIntent
```

After deployment, note the function URL (e.g., `https://us-central1-YOUR_PROJECT.cloudfunctions.net/createPaymentIntent`)

### 6. Update Firestore Configuration

Add the function URL to your Firestore database:

```
Collection: settings
Document: stripe
Fields:
  - publishableKey: "pk_test_YOUR_PUBLISHABLE_KEY"
  - merchantId: "merchant.com.tekneckjoe.tektool"
  - createPaymentIntentUrl: "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/createPaymentIntent"
```

## Functions

### createPaymentIntent

**Purpose:** Creates a Stripe payment intent for processing payments

**Endpoint:** POST request from Flutter app

**Parameters:**
- `amount` (number): Payment amount in cents
- `currency` (string): Currency code (e.g., "usd")
- `description` (string): Payment description
- `userId` (string): Firebase user ID
- `email` (string): User email

**Response:**
```json
{
  "clientSecret": "pi_xxx_secret_xxx",
  "paymentIntentId": "pi_xxx"
}
```

### stripeWebhook (Optional)

**Purpose:** Receives webhook events from Stripe

**Setup:**
1. Deploy the function
2. Copy the webhook URL
3. Add it to Stripe Dashboard > Developers > Webhooks
4. Copy the webhook signing secret
5. Configure it:
   ```bash
   firebase functions:config:set stripe.webhook_secret="whsec_YOUR_SECRET"
   ```

**Events Handled:**
- `payment_intent.succeeded` - Updates transaction status to completed
- `payment_intent.payment_failed` - Updates transaction status to failed

## Testing

### Test with Stripe CLI

Install Stripe CLI:
```bash
brew install stripe/stripe-cli/stripe
```

Forward webhooks to local function:
```bash
stripe listen --forward-to http://localhost:5001/YOUR_PROJECT/us-central1/createPaymentIntent
```

Trigger test events:
```bash
stripe trigger payment_intent.succeeded
```

### Test with Postman

1. Create a POST request to your function URL
2. Set headers:
   - Content-Type: application/json
3. Set body:
   ```json
   {
     "amount": 5000,
     "currency": "usd",
     "description": "Test payment",
     "userId": "test_user_123",
     "email": "test@example.com"
   }
   ```
4. Send request
5. Verify you get a `clientSecret` in response

## Security

### ✅ Best Practices

1. **Never commit secret keys** - Use Firebase Functions config
2. **Validate all inputs** - Check amount, currency, userId
3. **Use HTTPS only** - Firebase Functions automatically use HTTPS
4. **Verify webhook signatures** - Prevents fake webhook events
5. **Log all transactions** - For audit trail
6. **Monitor for fraud** - Use Stripe Radar

### ⚠️ Important Notes

- Keep test and production keys separate
- Rotate keys periodically
- Monitor Firebase Functions logs
- Set up alerts for function failures

## Troubleshooting

### Function deployment fails

**Cause:** Missing dependencies or incorrect Node version

**Solution:**
```bash
cd functions
npm install
node --version  # Should be 18 or higher
```

### "stripe is not defined"

**Cause:** Stripe secret key not configured

**Solution:**
```bash
firebase functions:config:set stripe.secret_key="sk_test_YOUR_KEY"
firebase deploy --only functions
```

### "CORS error" when calling from app

**Cause:** CORS headers not set

**Solution:** Ensure function includes:
```javascript
res.set('Access-Control-Allow-Origin', '*');
```

### Webhook signature verification fails

**Cause:** Incorrect webhook secret or modified payload

**Solution:**
1. Verify secret is correct
2. Check Stripe Dashboard > Webhooks for delivery logs
3. Ensure raw body is used (not parsed JSON)

## Monitoring

### View Function Logs

```bash
firebase functions:log
```

### Monitor in Firebase Console

1. Go to Firebase Console
2. Select your project
3. Click "Functions" in sidebar
4. View logs, metrics, and errors

### Stripe Dashboard

1. Go to Stripe Dashboard
2. Click "Developers" > "Logs"
3. View all API requests and responses

## Cost

Firebase Cloud Functions pricing:
- First 2M invocations/month: Free
- After that: $0.40 per million invocations

Typical cost for payment processing:
- ~$0.80/month for 1,000 payments
- Negligible for most use cases

Stripe fees:
- 2.9% + $0.30 per successful card charge
- No setup or monthly fees

## Support

For issues:
1. Check Firebase Functions logs
2. Check Stripe Dashboard logs
3. Review payment-functions.js code
4. Consult Firebase and Stripe documentation
