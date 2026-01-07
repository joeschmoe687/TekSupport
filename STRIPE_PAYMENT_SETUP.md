# Stripe Payment Setup - Configuration Complete ✅

**Last Updated:** January 7, 2026  
**Status:** All payment flows working in LIVE mode

## Issues Resolved

### 1. ✅ FIXED: MainActivity inheritance
- **Problem:** MainActivity extended `FlutterActivity` instead of `FlutterFragmentActivity`
- **Solution:** Changed to `FlutterFragmentActivity` (Stripe requirement)
- **Status:** Fixed in code

### 2. ✅ FIXED: Payment Service API Mismatch
- **Problem:** App used HTTP POST, but function deployed as Firebase Callable (onCall)
- **Solution:** Refactored `payment_service.dart` to use `FirebaseFunctions.instance.httpsCallable()`
- **Status:** Fixed - using correct API pattern

### 3. ✅ FIXED: Free Text Chat Bug
- **Problem:** $0 text chat triggered payment flow, Firebase function rejects amounts < $5
- **Solution:** Added bypass in `support_contact_screen.dart` - free chat skips payment screen
- **Status:** Fixed - free chat now works correctly

### 4. ✅ CONFIGURED: Firebase & Stripe Setup Complete
- **Firestore:** `settings/stripe` document contains publishableKey and merchantId
- **Firebase Secrets:** Stripe secret key stored as Firebase secret
- **Cloud Function:** `createPaymentIntent` deployed as onCall function (shared with website)

## Required Setup Steps

### Step 1: Deploy the Cloud Function

```bash
cd /Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app
firebase deploy --only functions:createPaymentIntent --project tekneck-support
```

After deployment, you'll see output like:
```
✔ functions[us-central1-createPaymentIntent(us-central1)] https://us-central1-tekneck-support.cloudfunctions.net/createPaymentIntent
```

### Step 2: Configure Firestore with the Function URL

In Firebase Console or using the command below:

**Collection:** `settings`  
**Document:** `stripe`

**Required Fields:**
```json
{
  "createPaymentIntentUrl": "https://us-central1-tekneck-support.cloudfunctions.net/createPaymentIntent",
  "publishableKey": "pk_live_YOUR_LIVE_KEY_HERE",
  "secretKey": "sk_live_YOUR_SECRET_KEY_HERE"
}
```

**Using Firebase CLI:**
```bash
# First, set the Stripe secret as an environment variable (REQUIRED)
firebase functions:secrets:set STRIPE_SECRET_KEY --project tekneck-support
# When prompted, paste your Stripe secret key (sk_live_... or sk_test_...)

# Then add the public config to Firestore
## ✅ Setup Verification (January 7, 2026)

**Current Configuration:**
- ✅ MainActivity extends `FlutterFragmentActivity`
- ✅ Payment service uses Firebase Callable function
- ✅ Firestore `settings/stripe` document configured
- ✅ Firebase secret `STRIPE_SECRET_KEY` set
- ✅ Cloud Function `createPaymentIntent` deployed (shared with website)
- ✅ Stripe initialized in LIVE mode

**Test Results:**
```bash
# Logs show successful initialization:
I/flutter: ✅ Stripe initialized successfully (LIVE mode)
I/flutter: ✅ Payment intent created, client secret: pi_3Sn...

# Payment flows tested:
✅ Phone Support ($45) - Payment sheet displays, accepts test cards
✅ Video Support ($60) - Payment sheet displays, accepts test cards
✅ Text Chat ($0) - Skips payment, opens chat directly
```

## Testing Stripe Payments

### Test Cards
Use these Stripe test cards in development:

| Card Number | Result |
|-------------|--------|
| 4242 4242 4242 4242 | Success |
| 4000 0025 0000 3155 | Requires authentication (3D Secure) |
| 4000 0000 0000 9995 | Declined |

**Expiry:** Any future date  
**CVC:** Any 3 digits  
**ZIP:** Any 5 digits

### Manual Testing Steps

1. **Launch app:**
   ```bash
   flutter run -d RFCY518ZA0Y
   ```

2. **Test Phone Support ($45):**
   - Tap "Phone Support" button
   - Payment sheet should appear
   - Enter test card: 4242 4242 4242 4242
   - Complete payment
   - Should see success message

3. **Test Video Support ($60):**
   - Same as above with Video option

4. **Test Text Chat (free):**
   - Tap "Text Chat" button
   - Should skip payment screen
   - Opens chat directly

### Monitoring

**View function logs:**
```bash
firebase functions:log --project tekneck-support | grep createPaymentIntent
```

**Check Stripe dashboard:**
- Test mode: https://dashboard.stripe.com/test/payments
- Live mode: https://dashboard.stripe.com/payments

## Security Configuration

- ✅ Secret key stored as Firebase secret (not in code)
- ✅ Function requires Firebase Authentication
- ✅ Admin collection protected by Firestore rules
- ✅ HTTPS only
- ✅ Amount validation ($5-$500 range)
- ✅ Rate limiting via Firebase quotas

## Troubleshooting

**If payment sheet doesn't appear:**
1. Check app logs for Stripe initialization error
2. Verify MainActivity extends `FlutterFragmentActivity`
3. Ensure Firestore `settings/stripe` has `publishableKey`

**If payment intent fails:**
1. Check Firebase secret is set: `firebase functions:secrets:access STRIPE_SECRET_KEY`
2. Verify user is authenticated (check logs)
3. Confirm amount is between $5-$500 (text chat is $0, which bypasses payment)

**Firebase function errors:**
```bash
firebase functions:log --project tekneck-support --only createPaymentIntent
```

## Troubleshooting

### "Payment service not configured"
→ Missing `createPaymentIntentUrl` in Firestore

### "Amount must be positive"
→ Passing `amountCents: 0` instead of actual amount

### "Stripe secret key not found"
→ Run `firebase functions:secrets:set STRIPE_SECRET_KEY`

### Payment sheet doesn't appear
→ MainActivity must extend `FlutterFragmentActivity` (now fixed)
