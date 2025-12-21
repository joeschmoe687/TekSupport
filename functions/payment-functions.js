/**
 * Cloud Function: Create Stripe Payment Intent
 * 
 * This function creates a Stripe payment intent for processing payments.
 * It should be deployed to Firebase Cloud Functions.
 * 
 * SETUP INSTRUCTIONS:
 * 
 * 1. Install dependencies in your functions directory:
 *    cd functions
 *    npm install stripe --save
 * 
 * 2. Set Stripe secret key:
 *    firebase functions:config:set stripe.secret_key="sk_test_YOUR_KEY"
 *    (Use sk_live_ for production)
 * 
 * 3. Add this function to your functions/index.js file
 * 
 * 4. Deploy:
 *    firebase deploy --only functions:createPaymentIntent
 * 
 * 5. Update Firestore settings/stripe document with function URL:
 *    {
 *      "createPaymentIntentUrl": "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/createPaymentIntent"
 *    }
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const stripe = require('stripe')(functions.config().stripe.secret_key);

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

exports.createPaymentIntent = functions.https.onRequest(async (req, res) => {
  // Enable CORS for Flutter app
  res.set('Access-Control-Allow-Origin', '*');
  
  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    res.status(405).send({ error: 'Method not allowed' });
    return;
  }

  try {
    const { amount, currency, description, userId, email } = req.body;

    // Validate required parameters
    if (!amount || !currency || !userId) {
      res.status(400).send({ 
        error: 'Missing required parameters',
        required: ['amount', 'currency', 'userId']
      });
      return;
    }

    // Validate amount is positive
    if (amount <= 0) {
      res.status(400).send({ error: 'Amount must be positive' });
      return;
    }

    // Optional: Validate amount against expected prices from Firestore
    // This prevents users from tampering with payment amounts
    // Uncomment to enable server-side price validation:
    /*
    const pricingDoc = await admin.firestore()
      .collection('settings')
      .doc('pricing')
      .get();
    
    if (pricingDoc.exists) {
      const pricing = pricingDoc.data();
      // Add validation logic based on supportType
      // Example: if (amount !== pricing.expectedAmount * 100) { throw error }
    }
    */

    console.log(`Creating payment intent for user ${userId}, amount: ${amount} ${currency}`);

    // Create payment intent with Stripe
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // Amount in cents
      currency: currency.toLowerCase(),
      description: description || 'TekNeck Support Service',
      metadata: {
        userId: userId,
        email: email || '',
        platform: 'flutter_app',
        timestamp: new Date().toISOString(),
      },
      // Enable automatic payment methods
      automatic_payment_methods: {
        enabled: true,
      },
    });

    console.log(`Payment intent created: ${paymentIntent.id}`);

    // Return client secret to app
    res.status(200).send({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });

  } catch (error) {
    console.error('Error creating payment intent:', error);
    
    // Return appropriate error message
    if (error.type === 'StripeCardError') {
      res.status(400).send({ error: error.message });
    } else if (error.type === 'StripeInvalidRequestError') {
      res.status(400).send({ error: 'Invalid request to payment processor' });
    } else {
      res.status(500).send({ error: 'Internal server error' });
    }
  }
});

/**
 * Optional: Webhook handler for Stripe events
 * 
 * This webhook receives events from Stripe (payment_intent.succeeded, etc.)
 * and can be used to update order status, send notifications, etc.
 * 
 * Setup:
 * 1. Deploy: firebase deploy --only functions:stripeWebhook
 * 2. Add webhook endpoint in Stripe Dashboard
 * 3. Set webhook secret: firebase functions:config:set stripe.webhook_secret="whsec_..."
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = functions.config().stripe.webhook_secret;

  if (!webhookSecret) {
    console.error('Webhook secret not configured');
    res.status(500).send('Webhook secret not configured');
    return;
  }

  let event;

  try {
    // Verify webhook signature
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      sig,
      webhookSecret
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  // Handle the event
  switch (event.type) {
    case 'payment_intent.succeeded':
      const paymentIntent = event.data.object;
      console.log(`Payment succeeded: ${paymentIntent.id}`);
      
      // Update transaction in Firestore
      try {
        const userId = paymentIntent.metadata.userId;
        
        // Find and update the transaction
        const transactionQuery = await admin.firestore()
          .collection('supportTransactions')
          .where('userId', '==', userId)
          .where('status', '==', 'pending')
          .orderBy('timestamp', 'desc')
          .limit(1)
          .get();
        
        if (!transactionQuery.empty) {
          const doc = transactionQuery.docs[0];
          await doc.ref.update({
            status: 'completed',
            paymentIntentId: paymentIntent.id,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`Transaction updated for user ${userId}`);
        }
      } catch (error) {
        console.error('Error updating transaction:', error);
      }
      break;

    case 'payment_intent.payment_failed':
      const failedPayment = event.data.object;
      console.log(`Payment failed: ${failedPayment.id}`);
      
      // Update transaction as failed
      try {
        const userId = failedPayment.metadata.userId;
        
        const transactionQuery = await admin.firestore()
          .collection('supportTransactions')
          .where('userId', '==', userId)
          .where('status', '==', 'pending')
          .orderBy('timestamp', 'desc')
          .limit(1)
          .get();
        
        if (!transactionQuery.empty) {
          const doc = transactionQuery.docs[0];
          await doc.ref.update({
            status: 'failed',
            paymentIntentId: failedPayment.id,
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
            error: failedPayment.last_payment_error?.message || 'Payment failed',
          });
        }
      } catch (error) {
        console.error('Error updating failed transaction:', error);
      }
      break;

    default:
      console.log(`Unhandled event type: ${event.type}`);
  }

  res.status(200).send({ received: true });
});
