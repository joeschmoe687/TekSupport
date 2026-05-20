/**
 * Firebase Cloud Functions for TekNeck HVAC Support App
 * 
 * This file contains all Cloud Functions including:
 * - Payment processing (Stripe)
 * - TekMate AI chat proxy (admin only)
 * - Gemini AI auto-response
 * - Push notifications
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Stripe with environment variable (Gen 2 compatible)
let stripe = null;
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
if (STRIPE_SECRET_KEY && STRIPE_SECRET_KEY !== 'sk_dummy_for_deployment') {
  stripe = require('stripe')(STRIPE_SECRET_KEY);
  console.log('✅ Stripe initialized successfully');
} else {
  console.warn('⚠️  Stripe secret key not configured via environment variable');
}

// TekMate configuration from environment variables (Gen 2 compatible)
const TEKMATE_API_URL = process.env.TEKMATE_API_URL || 'https://tekmate.airpronwa.com/api/personality-chat';
const TEKMATE_API_KEY = process.env.TEKMATE_API_KEY || '';
const CF_ACCESS_CLIENT_ID = process.env.CF_ACCESS_CLIENT_ID || '';
const CF_ACCESS_CLIENT_SECRET = process.env.CF_ACCESS_CLIENT_SECRET || '';

/**
 * TekMate Chat Proxy - ADMIN ONLY (Ghost Mode)
 * 
 * This function acts as a secure proxy between the Flutter app and TekMate AI.
 * It enforces admin-only access and adds authentication context.
 * 
 * SECURITY:
 * - Requires valid Firebase Authentication token
 * - Verifies user has admin role in Firestore
 * - Non-admins get 403 Forbidden (no hint that TekMate exists)
 * 
 * REQUEST:
 * {
 *   "message": "How do I troubleshoot low superheat?",
 *   "context": {
 *     "jobId": "job_123",
 *     "refrigerant": "R410A",
 *     "systemType": "AC"
 *   },
 *   "platform": "app"
 * }
 * 
 * RESPONSE:
 * {
 *   "response": "Low superheat usually indicates...",
 *   "confidence": 0.92,
 *   "autoRespond": false
 * }
 * 
 * SETUP:
 * 1. Deploy: firebase deploy --only functions:tekmateChatProxy
 * 2. Configure TekMate API endpoint in Firestore:
 *    Collection: settings
 *    Document: tekmate
 *    Fields:
 *      - apiUrl: "https://YOUR_TEKMATE_API_URL"
 *      - apiKey: "your_api_key"
 * 3. Test with admin user
 */
exports.tekmateChatProxy = functions.https.onCall(async (data, context) => {
  // SECURITY: Require authentication
  if (!context.auth) {
    console.log('tekmateChatProxy: Unauthorized - no auth token');
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }

  const userId = context.auth.uid;
  const userEmail = context.auth.token.email || 'unknown';
  console.log(`tekmateChatProxy: Request from user ${userId}`);

  try {
    // SECURITY: Verify admin role
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      console.log(`tekmateChatProxy: User ${userId} not found`);
      throw new functions.https.HttpsError(
        'permission-denied',
        'Access denied'
      );
    }

    const userData = userDoc.data();
    const isAdmin = userData.role === 'admin' || userData.isAdmin === true;

    // SECURITY: Only admins can access TekMate
    if (!isAdmin) {
      console.log(`tekmateChatProxy: User ${userId} is not admin`);
      // Return generic "access denied" - don't reveal TekMate exists
      throw new functions.https.HttpsError(
        'permission-denied',
        'Access denied'
      );
    }

    // Validate input
    const { message, context: requestContext, platform } = data;

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

    console.log(`tekmateChatProxy: Admin ${userId} querying TekMate`);
    console.log(`Message: ${message.substring(0, 100)}...`);

    // Get TekMate configuration from Firestore
    const tekmateConfig = await admin.firestore()
      .collection('settings')
      .doc('tekmate')
      .get();

    if (!tekmateConfig.exists) {
      console.error('TekMate configuration not found in Firestore');
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Service configuration error'
      );
    }

    const config = tekmateConfig.data();
    const tekmateApiUrl = config.apiUrl;
    const tekmateApiKey = config.apiKey;

    if (!tekmateApiUrl) {
      console.error('TekMate API URL not configured');
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Service not configured'
      );
    }

    // Call TekMate API with Cloudflare Access credentials
    
    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${TEKMATE_API_KEY || ''}`,
    };
    
    // Add Cloudflare Access headers if configured
    if (CF_ACCESS_CLIENT_ID && CF_ACCESS_CLIENT_SECRET) {
      headers['CF-Access-Client-Id'] = CF_ACCESS_CLIENT_ID;
      headers['CF-Access-Client-Secret'] = CF_ACCESS_CLIENT_SECRET;
    }
    
    const tekmateResponse = await fetch(TEKMATE_API_URL, {
      method: 'POST',
      headers,
      timeout: 120000,  // 2 minutes for complex HVAC analysis
      body: JSON.stringify({
        message: message,
        context: {
          ...requestContext,
          userId: userId,
          platform: platform || 'app',
          timestamp: new Date().toISOString(),
        },
      }),
    });

    if (!tekmateResponse.ok) {
      console.error(`TekMate API error: ${tekmateResponse.status}`);
      throw new functions.https.HttpsError(
        'internal',
        'AI service temporarily unavailable'
      );
    }

    const tekmateData = await tekmateResponse.json();

    // Log interaction to Firestore (admin only collection)
    await admin.firestore()
      .collection('admin')
      .doc('tekmate_interactions')
      .collection('logs')
      .add({
        userId: userId,
        message: message,
        context: requestContext || {},
        response: tekmateData.response || '',
        confidence: tekmateData.confidence || 0,
        platform: platform || 'app',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(`tekmateChatProxy: Response sent to ${userId}`);

    // Return TekMate response
    return {
      response: tekmateData.response || '',
      confidence: tekmateData.confidence || 0.0,
      autoRespond: tekmateData.autoRespond || false,
    };

  } catch (error) {
    console.error('tekmateChatProxy error:', error);
    
    // Re-throw HttpsError as-is
    if (error.code && error.code.includes('https/')) {
      throw error;
    }

    // Wrap other errors
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred processing your request'
    );
  }
});


/**
 * ============================================================================
 * EXISTING PAYMENT FUNCTIONS (from payment-functions.js)
 * ============================================================================
 */

/**
 * Create Stripe Payment Intent
 * Used for processing support payments in the app
 */
exports.createPaymentIntent = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  
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
    // Ensure Stripe is initialized
    if (!stripe) {
      // Try environment variable first (Gen 2)
      let stripeKey = STRIPE_SECRET_KEY;
      
      // If env var not set, try Firebase SQL or Firestore or use test key for testing
      if (!stripeKey || stripeKey === 'sk_dummy_for_deployment') {
        try {
          // First, try Firebase SQL (recommended for secrets)
          const sqlClient = require('pg').Client;
          // Cloud SQL connection string from Firebase config
          const connectionString = process.env.CLOUD_SQL_CONNECTION_STRING || 
            'postgresql://stripe_user@localhost/teksupport';
          
          const client = new sqlClient(connectionString);
          await client.connect();
          const result = await client.query(
            'SELECT secret_key FROM stripe_config WHERE environment = $1 LIMIT 1',
            [process.env.NODE_ENV || 'test']
          );
          await client.end();
          
          if (result.rows.length > 0) {
            stripeKey = result.rows[0].secret_key;
            console.log('✅ Loaded Stripe key from Cloud SQL');
          }
        } catch (sqlError) {
          console.warn('⚠️  Could not fetch from Cloud SQL, trying Firestore:', sqlError.message);
          try {
            const settings = await admin.firestore().collection('settings').doc('stripe').get();
            const stripeConfig = settings.data();
            stripeKey = stripeConfig?.secretKey;
            if (stripeKey) {
              console.log('✅ Loaded Stripe key from Firestore');
            }
          } catch (firestoreError) {
            console.warn('⚠️  Could not fetch from Firestore, using test key:', firestoreError.message);
            // Fallback to test key for development
            stripeKey = 'sk_dummy_for_deployment';
          }
        }
        
        if (!stripeKey || stripeKey === 'sk_dummy_for_deployment') {
          console.error('❌ Stripe secret key not found in Cloud SQL or Firestore');
          return res.status(500).send({ error: 'Payment service not configured. Missing secretKey in Cloud SQL or Firestore settings/stripe.' });
        }
      }
      
      stripe = require('stripe')(stripeKey);
      console.log('✅ Stripe initialized with key starting with:', stripeKey.substring(0, 10) + '...');
    }

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
      amount: amount,
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

/**
 * Auto-Respond with Gemini AI (for unclaimed chats)
 * 
 * Automatically responds to customer messages using Gemini AI when:
 * 1. Chat is not claimed by any admin
 * 2. Gemini is enabled in settings
 * 3. Customer message is not a greeting/introduction
 * 
 * This helps customers get immediate assistance while waiting for admin
 * 
 * TODO: Fix Firestore trigger compatibility with firebase-functions v6
 */
// exports.autoRespondWithGemini = functions.firestore
//   .document('supportRooms/{roomId}/messages/{messageId}')
//   .onCreate(async (snap, context) => {
//    const message = snap.data();
//    const roomId = context.params.roomId;
//    
//    // Only auto-respond to customer messages
//    if (message.senderType !== 'customer' && message.from !== 'customer') {
//      return null;
//    }
//    
//    try {
//      // Get room data
//      const roomDoc = await admin.firestore()
//        .collection('supportRooms')
//        .doc(roomId)
//        .get();
//      
//      if (!roomDoc.exists) return null;
//      
//      const roomData = roomDoc.data();
//      const assignedTo = roomData.claimedBy || roomData.assignedTo;
//      
//      // Only auto-respond if chat is not claimed
//      if (assignedTo) {
//        console.log(`Chat ${roomId} is claimed by ${assignedTo}, skipping auto-response`);
//        return null;
//      }
//      
//      // Check if Gemini is enabled
//      const geminiSettings = await admin.firestore()
//        .collection('settings')
//        .doc('gemini')
//        .get();
//      
//      if (!geminiSettings.exists) {
//        console.log('Gemini settings not found');
//        return null;
//      }
//      
//      const geminiConfig = geminiSettings.data();
//      
//      if (!geminiConfig.enabled || !geminiConfig.apiKey) {
//        console.log('Gemini not enabled or API key missing');
//        return null;
//      }
//      
//      // Skip if message is too short (likely greeting)
//      const messageText = message.text || message.messageText || '';
//      if (messageText.length < 10) {
//        console.log('Message too short, skipping auto-response');
//        return null;
//      }
//      
//      // Get recent messages for context
//      const recentMessagesSnap = await admin.firestore()
//        .collection('supportRooms')
//        .doc(roomId)
//        .collection('messages')
//        .orderBy('createdAt', 'desc')
//        .limit(5)
//        .get();
//      
//      const recentMessages = recentMessagesSnap.docs.map(doc => {
//        const data = doc.data();
//        return {
//          text: data.text || data.messageText || '',
//          senderType: data.senderType || data.from || 'unknown',
//        };
//      });
//      
//      // Call Gemini API
//      const genAI = new GoogleGenerativeAI(geminiConfig.apiKey);
//      const model = genAI.getGenerativeModel({
//        model: 'gemini-1.5-flash',
//        systemInstruction: geminiConfig.personality || 
//          'You are a helpful HVAC technical support assistant. ' +
//          'Provide clear, professional guidance to customers. ' +
//          'Be concise and practical. Mention that a technician will review this chat soon.'
//      });
//      
//      // Build context
//      let prompt = messageText;
//      if (roomData.systemType) {
//        prompt = `System Type: ${roomData.systemType}\n\n${prompt}`;
//      }
//      if (recentMessages.length > 1) {
//        prompt = 'Recent conversation:\n' +
//                 recentMessages.reverse().map(m => 
//                   `${m.senderType}: ${m.text}`
//                 ).join('\n') + '\n\n' + prompt;
//      }
//      
//      const result = await model.generateContent(prompt);
//      const response = result.response;
//      const aiReply = response.text();
//      
//      // Add AI response to chat
//      const aiDisclaimer = '\n\n_This is an AI-generated response. A technician will review your chat shortly._';
//      
//      await admin.firestore()
//        .collection('supportRooms')
//        .doc(roomId)
//        .collection('messages')
//        .add({
//          role: 'assistant',
//          senderType: 'ai',
//          from: 'gemini',
//          text: aiReply + aiDisclaimer,
//          messageText: aiReply + aiDisclaimer,
//          aiGenerated: true,
//          createdAt: admin.firestore.FieldValue.serverTimestamp(),
//          timestamp: admin.firestore.FieldValue.serverTimestamp(),
//        });
//      
//      // Update room
//      await admin.firestore()
//        .collection('supportRooms')
//        .doc(roomId)
//        .update({
//          lastMessage: '🤖 AI: ' + aiReply.substring(0, 50) + '...',
//          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//          aiResponded: true,
//        });
//      
//      console.log(`Gemini auto-responded to chat ${roomId}`);
//      
//      return null;
//    } catch (error) {
//      console.error('Error in Gemini auto-response:', error);
//      return null;
//    }
  // });

/**
 * Push Notification - New Customer Message
 * TODO: Fix Firestore trigger compatibility with firebase-functions v6
 */
// exports.sendPushNotificationOnNewMessage = functions.firestore
//   .document('supportRooms/{roomId}/messages/{messageId}')
//   .onCreate(async (snap, context) => {
//    const message = snap.data();
//    const roomId = context.params.roomId;
//
//    // Only send notification for customer messages
//    if (message.senderType !== 'customer' && message.from !== 'customer') {
//      return null;
//    }

// ============================================================================
// COMMENTED OUT FIRESTORE TRIGGERS (Firebase Functions v6 compatibility)
// ============================================================================
//
// The following functions have been temporarily disabled due to
// compatibility issues with firebase-functions v6:
// - autoRespondWithGemini
// - sendPushNotificationOnNewMessage  
// - sendPushNotificationOnAdminReply
//
// They can be re-enabled when upgrading to firebase-functions v7+ 
// with environment parameter migration.
// ============================================================================
