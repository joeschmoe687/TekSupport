# 🚀 Quick Start Guide - Payment System Setup

Get your payment system up and running in 5 steps!

## Prerequisites

- [ ] Stripe account (sign up at [stripe.com](https://stripe.com))
- [ ] Firebase project with Cloud Functions enabled
- [ ] Flutter development environment set up

## Step 1: Install Dependencies (5 minutes)

```bash
cd /path/to/hvac_support_app
flutter pub get
```

This installs:
- `flutter_stripe` - Stripe SDK
- `pay` - Google Pay
- `card_scanner` - Card scanning

## Step 2: Configure Stripe Keys (2 minutes)

### Get Your Stripe Keys

1. Go to [Stripe Dashboard](https://dashboard.stripe.com)
2. Click **Developers** → **API keys**
3. Copy your **Publishable key** (starts with `pk_test_...`)
4. Copy your **Secret key** (starts with `sk_test_...`) - Keep this secure!

### Add Keys to Firestore

1. Open Firebase Console → Your project → Firestore Database
2. Navigate to or create: `settings` collection → `stripe` document
3. Add these fields:

```
publishableKey: "pk_test_YOUR_PUBLISHABLE_KEY"
merchantId: "merchant.com.tekneckjoe.tektool"
createPaymentIntentUrl: ""  (leave empty for now, we'll add this in step 3)
```

**Screenshot:**
```
Collection: settings
  └─ Document: stripe
       ├─ publishableKey: "pk_test_..."
       ├─ merchantId: "merchant.com..."
       └─ createPaymentIntentUrl: ""
```

## Step 3: Deploy Cloud Function (10 minutes)

### A. Initialize Firebase Functions (if not done)

```bash
firebase init functions
```

Choose:
- Language: JavaScript
- ESLint: Yes (recommended)
- Install dependencies: Yes

### B. Add Payment Function

Open `functions/index.js` and add:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const stripe = require('stripe')(functions.config().stripe.secret_key);

if (!admin.apps.length) {
  admin.initializeApp();
}

exports.createPaymentIntent = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  try {
    const { amount, currency, description, userId, email } = req.body;

    if (!amount || !currency || !userId) {
      res.status(400).send({ error: 'Missing required parameters' });
      return;
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency.toLowerCase(),
      description: description || 'TekNeck Support Service',
      metadata: { userId, email, platform: 'flutter_app' },
      automatic_payment_methods: { enabled: true },
    });

    res.status(200).send({ clientSecret: paymentIntent.client_secret });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).send({ error: 'Internal server error' });
  }
});
```

Or copy from `functions/payment-functions.js` (full version with webhooks).

### C. Install Stripe Package

```bash
cd functions
npm install stripe --save
cd ..
```

### D. Configure Stripe Secret Key

```bash
firebase functions:config:set stripe.secret_key="sk_test_YOUR_SECRET_KEY"
```

**⚠️ Use your SECRET key here, not publishable key!**

### E. Deploy Function

```bash
firebase deploy --only functions:createPaymentIntent
```

**After deployment, note the function URL** (e.g., `https://us-central1-tekneck-support.cloudfunctions.net/createPaymentIntent`)

### F. Update Firestore with Function URL

Go back to Firestore → `settings/stripe` document and update:

```
createPaymentIntentUrl: "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/createPaymentIntent"
```

## Step 4: Test the Setup (5 minutes)

### Option A: Use Verification Screen

Add this to your app temporarily:

```dart
// In lib/main.dart or any screen
import 'package:tektool/screens/payment_verification_screen.dart';

// Add a button to navigate to verification screen
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PaymentVerificationScreen()),
    );
  },
  child: Text('Test Payment Setup'),
)
```

Run the app and tap the button. All checks should pass ✅.

### Option B: Manual Testing

1. Run the app: `flutter run`
2. Navigate to support/payment screen
3. Try to initiate a payment
4. You should see the Stripe payment sheet

## Step 5: Test with Test Cards (3 minutes)

Use these Stripe test cards:

| Card Number | Result | Use Case |
|------------|--------|----------|
| 4242 4242 4242 4242 | ✅ Success | Normal payment |
| 4000 0000 0000 0002 | ❌ Declined | Test error handling |
| 4000 0025 0000 3155 | 🔐 Requires Auth | Test 3D Secure |

**Expiry:** Any future date (e.g., 12/34)
**CVC:** Any 3 digits (e.g., 123)

### Test Flow:

1. Launch app
2. Go to Chat screen → Support Options
3. Select "Phone Support" ($45)
4. You should see PaymentScreen
5. Tap "Credit/Debit Card"
6. Enter test card: `4242 4242 4242 4242`
7. Enter expiry: `12/34`, CVC: `123`
8. Tap "Pay"
9. ✅ Success! Check Firestore `supportTransactions` collection

## ✅ Success Checklist

After completing all steps, verify:

- [ ] `flutter pub get` completed without errors
- [ ] Firestore `settings/stripe` document has all 3 fields
- [ ] Cloud Function deployed successfully
- [ ] PaymentVerificationScreen shows all green checks
- [ ] Test payment with `4242...` card succeeds
- [ ] Transaction appears in `supportTransactions` collection
- [ ] Google Pay option appears (if device supports it)

## 🎯 Production Checklist

Before going live:

- [ ] Replace test keys with live keys (`pk_live_...`, `sk_live_...`)
- [ ] Test with real card (small amount)
- [ ] Enable Stripe Radar (fraud detection)
- [ ] Set up webhook endpoint (optional but recommended)
- [ ] Add server-side price validation
- [ ] Review Firestore security rules
- [ ] Set up Firebase Functions monitoring
- [ ] Add error alerting

## 🐛 Troubleshooting

### "Payment system not initialized"
**Fix:** Check Firestore `settings/stripe` document exists with valid `publishableKey`.

### "Failed to create payment intent"
**Fix:** 
1. Check Cloud Function is deployed
2. Verify `createPaymentIntentUrl` in Firestore
3. Check Functions logs: `firebase functions:log`

### "Google Pay not available"
**Expected:** Not all devices support Google Pay. Card payment will still work.

### Card scanner not working
**Fix:** 
1. Ensure good lighting
2. Check camera permissions granted
3. Position card flat against contrasting background

## 📚 Next Steps

- Read `PAYMENT_SETUP.md` for detailed documentation
- Review `IMPLEMENTATION_SUMMARY.md` for technical details
- Check `functions/README.md` for Cloud Functions guide
- Run tests: `flutter test test/payment_service_test.dart`

## 🎉 You're Done!

Your payment system is now configured and ready to accept payments. Users can:
- Pay with Google Pay (one-tap)
- Pay with card (manual or scanned)
- See immediate payment confirmation
- Have transactions logged automatically

**Need Help?** Review the docs or check Firebase/Stripe dashboard logs.

---

**Setup Time:** ~25 minutes
**Difficulty:** Easy (with this guide)
**Result:** Production-ready payment system ✨
