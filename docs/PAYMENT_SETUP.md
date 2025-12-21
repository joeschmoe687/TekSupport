# Payment Integration Setup Guide

This guide explains how to configure the payment system for the TekNeck Support App.

## Overview

The app now supports native in-app payments with:
- **Stripe Credit/Debit Card payments** with secure card entry
- **Google Pay integration** for fast checkout
- **Camera-based card scanning** for manual entry (using ML Kit)
- **Transaction logging** to Firestore

## Prerequisites

1. **Stripe Account**: Sign up at [stripe.com](https://stripe.com)
2. **Firebase Functions**: Deployed Cloud Functions for backend payment processing
3. **Firestore Configuration**: Settings stored in Firestore

## Setup Steps

### 1. Install Dependencies

Run the following command in the project root:

```bash
flutter pub get
```

This will install:
- `flutter_stripe: ^11.1.0` - Stripe SDK for Flutter
- `pay: ^2.0.0` - Google Pay integration
- `card_scanner: ^1.0.3` - Camera-based card scanning

### 2. Configure Stripe in Firestore

Add the following document to your Firestore database:

**Collection:** `settings`
**Document:** `stripe`

```json
{
  "publishableKey": "pk_live_YOUR_STRIPE_PUBLISHABLE_KEY",
  "merchantId": "merchant.com.tekneckjoe.tektool",
  "createPaymentIntentUrl": "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/createPaymentIntent"
}
```

**Important:**
- Use `pk_test_...` for testing
- Use `pk_live_...` for production
- Get your keys from [Stripe Dashboard > Developers > API keys](https://dashboard.stripe.com/apikeys)

### 3. Deploy Firebase Cloud Function

Create a Cloud Function to handle payment intent creation. This keeps your secret key secure on the server.

**File:** `functions/index.js` (in your Firebase Functions directory)

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const stripe = require('stripe')(functions.config().stripe.secret_key);

admin.initializeApp();

exports.createPaymentIntent = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  try {
    const { amount, currency, description, userId, email } = req.body;

    // Validate input
    if (!amount || !currency || !userId) {
      res.status(400).send({ error: 'Missing required parameters' });
      return;
    }

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // Amount in cents
      currency: currency,
      description: description,
      metadata: {
        userId: userId,
        email: email,
        platform: 'flutter_app',
      },
    });

    res.status(200).send({
      clientSecret: paymentIntent.client_secret,
    });
  } catch (error) {
    console.error('Error creating payment intent:', error);
    res.status(500).send({ error: error.message });
  }
});
```

**Deploy the function:**

```bash
cd functions
npm install stripe --save
firebase functions:config:set stripe.secret_key="sk_test_YOUR_STRIPE_SECRET_KEY"
firebase deploy --only functions:createPaymentIntent
```

### 4. Configure Android (for Google Pay)

Add the following to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
  <application ...>
    <!-- Google Pay -->
    <meta-data
        android:name="com.google.android.gms.wallet.api.enabled"
        android:value="true" />
  </application>
</manifest>
```

### 5. Configure iOS (for Apple Pay) - Optional

If you want to support Apple Pay:

1. Enable Apple Pay capability in Xcode
2. Add merchant identifier in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>merchant.com.tekneckjoe.tektool</string>
  </dict>
</array>
```

### 6. Testing

#### Test with Test Cards

Use Stripe test cards:
- **Success:** 4242 4242 4242 4242
- **Declined:** 4000 0000 0000 0002
- **Requires Authentication:** 4000 0025 0000 3155

Any future expiry date and any 3-digit CVC works with test cards.

#### Test Google Pay

1. Use test publishable key (`pk_test_...`)
2. Add a test card to Google Pay on your device
3. Ensure you have Google Play Services installed

#### Test Card Scanner

1. Point camera at a credit card
2. The scanner will automatically detect card number, expiry, and cardholder name
3. Works in good lighting conditions

## Security Considerations

### ✅ What We Do Right

1. **Server-Side Payment Intent Creation**: Secret key never exposed to app
2. **PCI Compliance**: Card data goes directly to Stripe, never touches our servers
3. **HTTPS Only**: All payment requests use encrypted connections
4. **Transaction Logging**: All payments logged to Firestore with user tracking

### ⚠️ Important Security Notes

1. **Never commit secret keys** to version control
2. **Use environment variables** for sensitive config (Firebase Functions config)
3. **Validate amounts server-side** (TODO: Add server-side price validation)
4. **Monitor for fraud** using Stripe Radar

## Architecture

```
┌─────────────────┐
│   Flutter App   │
│  (PaymentScreen)│
└────────┬────────┘
         │
         │ 1. Request payment
         ▼
┌─────────────────┐
│ PaymentService  │
└────────┬────────┘
         │
         │ 2. Create PaymentIntent
         ▼
┌─────────────────┐
│Cloud Function   │
│createPaymentIntent│
└────────┬────────┘
         │
         │ 3. Call Stripe API
         ▼
┌─────────────────┐
│   Stripe API    │
└────────┬────────┘
         │
         │ 4. Return client_secret
         ▼
┌─────────────────┐
│  Flutter Stripe │
│   SDK Payment   │
│    Sheet        │
└────────┬────────┘
         │
         │ 5. User enters card/Google Pay
         ▼
┌─────────────────┐
│ Payment Success │
│  Log to Firestore│
└─────────────────┘
```

## Transaction Logging

Successful payments are logged to Firestore:

**Collection:** `supportTransactions`

```json
{
  "userId": "user_uid",
  "email": "user@example.com",
  "type": "phone|video|text|emergency",
  "amount": 45.00,
  "amountCents": 4500,
  "timestamp": "2025-12-21T04:00:00Z",
  "status": "completed",
  "paymentMethod": "card|google_pay",
  "platform": "flutter_app"
}
```

## Troubleshooting

### "Payment system not initialized"

**Solution:** Ensure Firestore `settings/stripe` document exists with valid keys.

### "Google Pay is not available"

**Causes:**
1. Device doesn't have Google Play Services
2. No cards added to Google Pay
3. Test mode misconfiguration

**Solution:** Check device has Google Pay set up with at least one card.

### Card scanner not working

**Causes:**
1. Poor lighting
2. Camera permission not granted
3. Card not fully visible

**Solution:** 
- Ensure good lighting
- Check camera permissions in app settings
- Position card flat against contrasting background

### Payment succeeds but transaction not logged

**Cause:** Firestore write permission issue or network error.

**Solution:** Check Firestore security rules allow writes to `supportTransactions`.

## Migration from Web Checkout

### Old Flow (External Website)
```
App → Opens browser → airpronwa.com/checkout.html → Stripe → WhatsApp
```

### New Flow (Native App)
```
App → PaymentScreen → Stripe Payment Sheet → Success → WhatsApp
```

### Benefits
1. ✅ No leaving the app
2. ✅ Native Google Pay integration
3. ✅ Secure card scanning
4. ✅ Better user experience
5. ✅ Consistent branding

### Keeping Web Checkout (Optional)

You can keep the web checkout as a fallback. The old `_launchCheckout()` method has been replaced with navigation to `PaymentScreen`, but you can add a "Pay via Web" button if needed.

## Future Enhancements

### Planned Features
- [ ] Apple Pay support
- [ ] Subscription management for monthly plans
- [ ] Receipt generation (PDF)
- [ ] Refund processing from admin dashboard
- [ ] Payment analytics dashboard

### Server-Side Validation
**TODO:** Add price verification in Cloud Function to prevent amount tampering.

```javascript
// In createPaymentIntent function
const pricing = await admin.firestore()
  .collection('settings')
  .doc('pricing')
  .get();

// Validate amount matches expected price
const expectedAmount = pricing.data()[supportType];
if (amount !== expectedAmount * 100) {
  res.status(400).send({ error: 'Invalid amount' });
  return;
}
```

## Support

For issues:
1. Check Stripe Dashboard > Logs for payment errors
2. Check Firebase Console > Functions logs
3. Check app logs (Flutter DevTools)

## References

- [Stripe Flutter SDK Documentation](https://docs.stripe.com/payments/accept-a-payment?platform=flutter)
- [Google Pay Flutter Integration](https://pub.dev/packages/pay)
- [Card Scanner Package](https://pub.dev/packages/card_scanner)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
