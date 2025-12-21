/**
 * TekNeck HVAC Support App - Cloud Functions
 * 
 * This file contains Firebase Cloud Functions for the app.
 * CRITICAL: TekMate functions are ADMIN ONLY (Ghost Mode)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * ============================================================================
 * TEKMATE CHAT PROXY - ADMIN ONLY (GHOST MODE)
 * ============================================================================
 * 
 * This function proxies chat queries to the TekMate AI service.
 * 
 * SECURITY (CRITICAL):
 * - Only authenticated users can call this function
 * - Only users with role='admin' or isAdmin=true can access TekMate
 * - Non-admins get 403 Forbidden (function doesn't reveal TekMate exists)
 * - All requests are logged to admin-only collection for audit
 * 
 * REQUEST:
 * {
 *   message: string,      // User's question/prompt
 *   context: object,      // Optional job/customer/device context
 *   platform: string      // 'app' or 'web'
 * }
 * 
 * RESPONSE:
 * {
 *   response: string,     // TekMate's response text
 *   confidence: number,   // 0.0-1.0 confidence score
 *   autoRespond: boolean  // Whether to auto-send (high confidence)
 * }
 */
exports.tekmateChatProxy = functions.https.onCall(async (data, context) => {
  // SECURITY: Require authentication
  if (!context.auth) {
    console.warn('Unauthenticated TekMate access attempt');
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }

  const userId = context.auth.uid;
  const userEmail = context.auth.token.email || 'unknown';

  try {
    // SECURITY: Check admin status
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.warn(`TekMate access attempt by non-existent user: ${userId}`);
      throw new functions.https.HttpsError(
        'permission-denied',
        'User not found'
      );
    }

    const userData = userDoc.data();
    const isAdmin = userData.role === 'admin' || userData.isAdmin === true;

    // SECURITY: Only admins can access TekMate
    if (!isAdmin) {
      console.warn(`TekMate access denied for non-admin user: ${userEmail} (${userId})`);
      throw new functions.https.HttpsError(
        'permission-denied',
        'Access denied'
      );
    }

    // Extract request data
    const { message, context: userContext, platform } = data;

    // Validate input
    if (!message || typeof message !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Message is required'
      );
    } else if (message.length > 5000) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Message too long'
      );
    }

    console.log(`TekMate request from admin ${userEmail}: "${message.substring(0, 50)}..."`);

    // TODO: Call actual TekMate AI service (tekmate-consolidated repo)
    // For now, return a mock response with varying confidence
    // In production, this should call the TekMate API endpoint
    
    // Mock response logic - simulates AI behavior
    const mockResponse = await generateMockTekMateResponse(message, userContext);

    // Log interaction to admin-only collection
    await db.collection('admin').doc('tekmate_interactions').collection('logs').add({
      userId,
      userEmail,
      message,
      response: mockResponse.response,
      confidence: mockResponse.confidence,
      context: userContext || {},
      platform: platform || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`TekMate response sent (confidence: ${mockResponse.confidence})`);

    return mockResponse;

  } catch (error) {
    console.error('TekMate proxy error:', error);
    
    // Don't expose internal errors to client
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred processing your request'
    );
  }
});

/**
 * Mock TekMate AI Response Generator
 * 
 * This simulates the TekMate AI service responses until the actual
 * tekmate-consolidated integration is complete.
 * 
 * In production, replace this with actual API call to TekMate service.
 */
async function generateMockTekMateResponse(message, context) {
  const lowerMessage = message.toLowerCase();
  
  // Detect query type and provide appropriate mock response
  let response = '';
  let confidence;
  
  // BLE Device Setup queries
  if (lowerMessage.includes('bluetooth') || lowerMessage.includes('ble') || 
      lowerMessage.includes('pair') || lowerMessage.includes('device')) {
    response = `Based on the device info, this appears to be a standard BLE HVAC tool. Here's the recommended setup:

1. Enable Bluetooth on your device
2. Put the tool in pairing mode (usually hold power for 3-5 seconds)
3. Scan for devices in the TekTool app
4. Select the device when it appears
5. The app will automatically detect the protocol

Expected characteristics:
- Service UUID: Check manufacturer documentation
- Data format: Usually 16-byte packets with sensor readings
- Update rate: 1-5 Hz depending on tool type

Would you like me to analyze the BLE sniffer logs for this device?`;
    confidence = 0.82;
  }
  // HVAC Troubleshooting queries
  else if (lowerMessage.includes('superheat') || lowerMessage.includes('subcool') ||
           lowerMessage.includes('pressure') || lowerMessage.includes('refrigerant')) {
    response = `For proper HVAC diagnostics:

**Normal Operating Ranges (R410A Residential AC):**
- Suction Pressure: 118-145 PSI
- Discharge Pressure: 350-425 PSI  
- Superheat: 10-15°F (TXV system)
- Subcool: 8-12°F

**If readings are outside range:**
- High superheat + Low suction = Low refrigerant charge
- Low superheat + High suction = Overcharged or airflow issue
- High discharge = Condenser airflow problem

Check ambient temperature compensation - hotter days will show higher pressures. What are your current readings?`;
    confidence = 0.88;
  }
  // Service call guidance
  else if (lowerMessage.includes('service') || lowerMessage.includes('call') ||
           lowerMessage.includes('customer') || lowerMessage.includes('job')) {
    response = `For service call best practices:

1. **Initial Assessment:**
   - Customer complaint/symptoms
   - System type and age
   - Visual inspection before connecting gauges

2. **Diagnostic Steps:**
   - Check thermostat settings
   - Inspect air filter and airflow
   - Listen for unusual sounds
   - Connect gauges and read pressures
   - Measure temperatures (supply/return)

3. **Documentation:**
   - Take photos of nameplate and system
   - Record all readings
   - Note any abnormal conditions
   - Document repairs made

Would you like specific guidance on the current issue?`;
    confidence = 0.79;
  }
  // General/Unknown queries
  else {
    response = `I can help with:

- **HVAC Diagnostics:** Pressure readings, superheat/subcool calculations, troubleshooting
- **Device Setup:** Bluetooth tool pairing, protocol analysis, device configuration
- **Service Calls:** Step-by-step guidance, best practices, safety procedures
- **Technical Support:** Equipment specs, refrigerant properties, industry standards

Please provide more details about what you need help with, including:
- System type (AC, heat pump, refrigeration)
- Current readings or symptoms
- Equipment information
- Specific questions or concerns`;
    confidence = 0.65; // Lower confidence for general queries
  }
  
  // Determine if should auto-respond (confidence > 0.9)
  const autoRespond = confidence > 0.9;
  
  return {
    response,
    confidence,
    autoRespond,
  };
}

/**
 * ============================================================================
 * EXISTING PAYMENT FUNCTIONS (from payment-functions.js)
 * ============================================================================
 */

const stripe = require('stripe')(functions.config().stripe?.secret_key || 'sk_test_placeholder');

/**
 * Create Stripe Payment Intent
 * Used for processing support payments in the app
 */
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
 * Stripe Webhook Handler
 * Receives events from Stripe for payment status updates
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = functions.config().stripe?.webhook_secret;

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
