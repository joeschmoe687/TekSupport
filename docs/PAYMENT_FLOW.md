# Payment Flow Diagrams

## Overall Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Flutter App                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  User Selects Support Option                                         │
│         ↓                                                            │
│  ChatScreen / SupportContactScreen                                   │
│         ↓                                                            │
│  PaymentScreen                                                       │
│    ┌──────────────────────────────────────┐                         │
│    │  [Google Pay]  [Credit Card]  [Scan] │                         │
│    └──────────────────────────────────────┘                         │
│         ↓                                                            │
│  PaymentService.processPayment()                                     │
│    • Initialize Stripe                                               │
│    • Create Payment Intent                                           │
│    • Show Payment Sheet                                              │
│         ↓                                                            │
└─────────────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Firebase Cloud Function                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  createPaymentIntent(amount, currency, userId, email)                │
│    1. Validate input parameters                                      │
│    2. Check user authentication                                      │
│    3. Call Stripe API with secret key                                │
│    4. Return client_secret to app                                    │
│         ↓                                                            │
└─────────────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────────────┐
│                         Stripe API                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  • Creates PaymentIntent object                                      │
│  • Returns client_secret                                             │
│  • Waits for payment confirmation                                    │
│  • Processes card/Google Pay                                         │
│  • Sends webhook events (success/failure)                            │
│         ↓                                                            │
└─────────────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────────────┐
│                        Firestore                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Collection: supportTransactions                                     │
│    {                                                                 │
│      userId: "user_123",                                             │
│      type: "phone",                                                  │
│      amount: 45.00,                                                  │
│      status: "completed",                                            │
│      paymentMethod: "google_pay",                                    │
│      timestamp: "2025-12-21T04:00:00Z"                               │
│    }                                                                 │
│         ↓                                                            │
└─────────────────────────────────────────────────────────────────────┘
                         ↓
                  Transaction Complete!
              User sees success message
          WhatsApp opens for support chat
```

## Card Payment Flow (Detailed)

```
User Taps "Credit/Debit Card"
         ↓
┌────────────────────────────┐
│   PaymentService           │
│   processCardPayment()     │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Create Payment Intent    │
│   (Call Cloud Function)    │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Cloud Function           │
│   • Validate amount        │
│   • Call Stripe API        │
│   • Return client_secret   │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Initialize Payment Sheet │
│   Stripe.initPaymentSheet()│
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Show Payment Sheet       │
│   (Native Stripe UI)       │
└────────────────────────────┘
         ↓
User enters card details
or scans card with camera
         ↓
┌────────────────────────────┐
│   Stripe Processes Payment │
│   (Secure on Stripe side)  │
└────────────────────────────┘
         ↓
    ┌────────┴────────┐
    ↓                 ↓
Success           Failure
    ↓                 ↓
┌─────────┐      ┌─────────┐
│ Log to  │      │ Show    │
│Firestore│      │ Error   │
└─────────┘      └─────────┘
    ↓                 
┌─────────────────────────┐
│ Show Success Dialog     │
│ Return to previous      │
│ Open WhatsApp          │
└─────────────────────────┘
```

## Google Pay Flow (Detailed)

```
User Taps "Google Pay"
         ↓
┌────────────────────────────┐
│   Check Google Pay         │
│   isGooglePayAvailable()   │
└────────────────────────────┘
         ↓
    Available?
    ┌───┴───┐
    ↓       ↓
  Yes       No
    ↓       ↓
Continue  Show Error
    ↓
┌────────────────────────────┐
│   Create Payment Intent    │
│   (Same as card flow)      │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Initialize Payment Sheet │
│   with Google Pay enabled  │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Show Google Pay Button   │
│   (One tap to pay)         │
└────────────────────────────┘
         ↓
User authorizes payment
(Fingerprint/Face/PIN)
         ↓
┌────────────────────────────┐
│   Google Pay sends token   │
│   to Stripe automatically  │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Stripe processes payment │
└────────────────────────────┘
         ↓
Success! (Faster than card)
         ↓
┌────────────────────────────┐
│   Log transaction          │
│   Show success             │
│   Open WhatsApp           │
└────────────────────────────┘
```

## Card Scanning Flow

```
User Taps "Scan Card"
         ↓
┌────────────────────────────┐
│   Check Camera Permission  │
└────────────────────────────┘
         ↓
    Granted?
    ┌───┴───┐
    ↓       ↓
  Yes       No
    ↓       ↓
Continue  Request
    ↓
┌────────────────────────────┐
│   Open Camera              │
│   CardScanner.scanCard()   │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   User positions card      │
│   ML Kit detects card      │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Extract Card Data        │
│   • Card Number            │
│   • Expiry Date           │
│   • Cardholder Name       │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Show "Card Scanned"      │
│   ****1234                 │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Proceed with Payment     │
│   (Use scanned data)       │
└────────────────────────────┘
         ↓
Continue normal card flow
```

## Error Handling Flow

```
Payment Initiated
         ↓
┌────────────────────────────┐
│   Try Payment              │
└────────────────────────────┘
         ↓
    Success?
    ┌───┴───┐
    ↓       ↓
  Yes       No
    ↓       ↓
Success   Error
Dialog      ↓
         ┌────────────────┐
         │ Catch Error    │
         └────────────────┘
                ↓
         ┌──────┴──────┐
         ↓             ↓
    User         System
   Cancelled      Error
         ↓             ↓
    Silent      Show Error
    Return       Dialog
                     ↓
              Offer Retry
```

## Security Flow

```
Payment Request
         ↓
┌────────────────────────────┐
│   Verify User Logged In    │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Load Publishable Key     │
│   from Firestore           │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Detect Test/Live Mode    │
│   (from key prefix)        │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Call Cloud Function      │
│   (HTTPS only)             │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Cloud Function uses      │
│   Secret Key (secure)      │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Stripe processes via     │
│   PCI-compliant servers    │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Card data never touches  │
│   our servers              │
└────────────────────────────┘
         ↓
┌────────────────────────────┐
│   Log transaction with     │
│   userId for audit         │
└────────────────────────────┘
         ↓
         ✅
    Secure!
```

## Data Flow Summary

| Component | Data In | Data Out |
|-----------|---------|----------|
| **PaymentScreen** | User selection | Payment amount, type |
| **PaymentService** | Amount, type, description | Payment result |
| **Cloud Function** | Amount, userId, currency | client_secret |
| **Stripe API** | Payment details | Success/failure |
| **Firestore** | Transaction data | Stored record |

## Key Security Boundaries

```
┌─────────────────────────────────────────────────────┐
│                    Client Side                       │
│  • Publishable key only                             │
│  • No card data stored                              │
│  • No secret keys                                   │
└─────────────────────────────────────────────────────┘
                         ↓
                   HTTPS Only
                         ↓
┌─────────────────────────────────────────────────────┐
│                   Server Side                        │
│  • Secret key stored securely                       │
│  • Payment intent creation                          │
│  • Amount validation                                │
└─────────────────────────────────────────────────────┘
                         ↓
                   HTTPS Only
                         ↓
┌─────────────────────────────────────────────────────┐
│                 Stripe (PCI DSS)                     │
│  • Card data processing                             │
│  • 3D Secure authentication                         │
│  • Fraud detection                                  │
└─────────────────────────────────────────────────────┘
```

## Performance Timeline

```
User Action          Time    Description
─────────────────────────────────────────────────────
Tap payment button   0ms     User initiates payment
Show PaymentScreen   100ms   Screen renders
Initialize service   200ms   Load Stripe config
Create intent        500ms   Call Cloud Function
Show payment sheet   800ms   Native UI appears
User enters card     10s     User input (variable)
Process payment      2s      Stripe processing
Show success         12.8s   Success dialog
Log to Firestore     13s     Background logging
─────────────────────────────────────────────────────
Total Time: ~13 seconds (typical)

With Google Pay:
User Action          Time    Description
─────────────────────────────────────────────────────
Tap Google Pay       0ms     User initiates
Authorize biometric  2s      Face/fingerprint
Process payment      3s      Google Pay + Stripe
Show success         5s      Success dialog
─────────────────────────────────────────────────────
Total Time: ~5 seconds (60% faster!)
```

## Integration Points

### 1. Chat Screen Integration
```
ChatScreen → Support Options Modal → Payment Screen → Success → Chat
```

### 2. Support Contact Integration
```
Support Contact → Select Service → Payment Screen → Success → WhatsApp
```

### 3. Admin Dashboard (Future)
```
Admin Dashboard → Transactions → Filter → Export → Analytics
```

## Conclusion

This payment system provides:
- ✅ Multiple payment methods
- ✅ Secure, PCI-compliant processing
- ✅ Fast checkout (5-13 seconds)
- ✅ Excellent user experience
- ✅ Comprehensive error handling
- ✅ Complete audit trail

See other documentation files for setup and configuration details.
