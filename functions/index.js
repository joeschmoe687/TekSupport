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

// Import payment functions
const stripe = require('stripe')(functions.config().stripe?.secret_key || '');

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
    console.warn('Unauthenticated TekMate access attempt');
    console.log('tekmateChatProxy: Unauthorized - no auth token');
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
      console.warn(`TekMate access denied for non-admin user: ${userEmail} (${userId})`);
    if (!isAdmin) {
      console.log(`tekmateChatProxy: User ${userId} is not admin`);
      // Return generic "access denied" - don't reveal TekMate exists
      throw new functions.https.HttpsError(
        'permission-denied',
        'Access denied'
      );
    }

    // Extract request data
    const { message, context: userContext, platform } = data;

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

    // Call TekMate API
    // NOTE: This is a placeholder - you'll need to implement actual API call
    // based on your TekMate consolidated backend
    const fetch = require('node-fetch');
    
    const tekmateResponse = await fetch(tekmateApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${tekmateApiKey || ''}`,
      },
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
 * Payment Intent Creation - Stripe
 * (Existing payment function)
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
 */
exports.autoRespondWithGemini = functions.firestore
  .document('supportRooms/{roomId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const roomId = context.params.roomId;
    
    // Only auto-respond to customer messages
    if (message.senderType !== 'customer' && message.from !== 'customer') {
      return null;
    }
    
    try {
      // Get room data
      const roomDoc = await admin.firestore()
        .collection('supportRooms')
        .doc(roomId)
        .get();
      
      if (!roomDoc.exists) return null;
      
      const roomData = roomDoc.data();
      const assignedTo = roomData.claimedBy || roomData.assignedTo;
      
      // Only auto-respond if chat is not claimed
      if (assignedTo) {
        console.log(`Chat ${roomId} is claimed by ${assignedTo}, skipping auto-response`);
        return null;
      }
      
      // Check if Gemini is enabled
      const geminiSettings = await admin.firestore()
        .collection('settings')
        .doc('gemini')
        .get();
      
      if (!geminiSettings.exists) {
        console.log('Gemini settings not found');
        return null;
      }
      
      const geminiConfig = geminiSettings.data();
      
      if (!geminiConfig.enabled || !geminiConfig.apiKey) {
        console.log('Gemini not enabled or API key missing');
        return null;
      }
      
      // Skip if message is too short (likely greeting)
      const messageText = message.text || message.messageText || '';
      if (messageText.length < 10) {
        console.log('Message too short, skipping auto-response');
        return null;
      }
      
      // Get recent messages for context
      const recentMessagesSnap = await admin.firestore()
        .collection('supportRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', 'desc')
        .limit(5)
        .get();
      
      const recentMessages = recentMessagesSnap.docs.map(doc => {
        const data = doc.data();
        return {
          text: data.text || data.messageText || '',
          senderType: data.senderType || data.from || 'unknown',
        };
      });
      
      // Call Gemini API
      const genAI = new GoogleGenerativeAI(geminiConfig.apiKey);
      const model = genAI.getGenerativeModel({
        model: 'gemini-1.5-flash',
        systemInstruction: geminiConfig.personality || 
          'You are a helpful HVAC technical support assistant. ' +
          'Provide clear, professional guidance to customers. ' +
          'Be concise and practical. Mention that a technician will review this chat soon.'
      });
      
      // Build context
      let prompt = messageText;
      if (roomData.systemType) {
        prompt = `System Type: ${roomData.systemType}\n\n${prompt}`;
      }
      if (recentMessages.length > 1) {
        prompt = 'Recent conversation:\n' +
                 recentMessages.reverse().map(m => 
                   `${m.senderType}: ${m.text}`
                 ).join('\n') + '\n\n' + prompt;
      }
      
      const result = await model.generateContent(prompt);
      const response = result.response;
      const aiReply = response.text();
      
      // Add AI response to chat
      const aiDisclaimer = '\n\n_This is an AI-generated response. A technician will review your chat shortly._';
      
      await admin.firestore()
        .collection('supportRooms')
        .doc(roomId)
        .collection('messages')
        .add({
          role: 'assistant',
          senderType: 'ai',
          from: 'gemini',
          text: aiReply + aiDisclaimer,
          messageText: aiReply + aiDisclaimer,
          aiGenerated: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      // Update room
      await admin.firestore()
        .collection('supportRooms')
        .doc(roomId)
        .update({
          lastMessage: '🤖 AI: ' + aiReply.substring(0, 50) + '...',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          aiResponded: true,
        });
      
      console.log(`Gemini auto-responded to chat ${roomId}`);
      
      return null;
    } catch (error) {
      console.error('Error in Gemini auto-response:', error);
      return null;
    }
  });

/**
 * Push Notification - New Customer Message
 */
exports.sendPushNotificationOnNewMessage = functions.firestore
  .document('supportRooms/{roomId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const roomId = context.params.roomId;

    // Only send notification for customer messages
    if (message.senderType !== 'customer' && message.from !== 'customer') {
      return null;
    }

    try {
      // Get room data
      const roomDoc = await admin.firestore()
        .collection('supportRooms')
        .doc(roomId)
        .get();

      if (!roomDoc.exists) return null;

      const roomData = roomDoc.data();
      const assignedTo = roomData.claimedBy || roomData.assignedTo;

      if (!assignedTo) {
        console.log('No assigned tech/admin for notification');
        return null;
      }

      // Get admin's FCM token
      const adminDoc = await admin.firestore()
        .collection('users')
        .doc(assignedTo)
        .get();

      if (!adminDoc.exists) return null;

      const adminData = adminDoc.data();
      const fcmToken = adminData.fcmToken;

      if (!fcmToken) {
        console.log('Admin has no FCM token');
        return null;
      }

      // Send notification
      const payload = {
        notification: {
          title: 'New Message',
          body: message.text || 'New message received',
        },
        data: {
          type: 'new_message',
          roomId: roomId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        token: fcmToken,
      };

      await admin.messaging().send(payload);
      console.log(`Notification sent to admin ${assignedTo}`);

      return null;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });

/**
 * Push Notification - Admin Reply
 */
exports.sendPushNotificationOnAdminReply = functions.firestore
  .document('supportRooms/{roomId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const roomId = context.params.roomId;

    // Only send notification for tech/admin messages
    if (message.senderType !== 'tech' && message.from !== 'tech') {
      return null;
    }

    try {
      // Get room data
      const roomDoc = await admin.firestore()
        .collection('supportRooms')
        .doc(roomId)
        .get();

      if (!roomDoc.exists) return null;

      const roomData = roomDoc.data();
      const customerId = roomData.userId || roomData.customerUID;

      if (!customerId) {
        console.log('No customer ID for notification');
        return null;
      }

      // Get customer's FCM token
      const customerDoc = await admin.firestore()
        .collection('users')
        .doc(customerId)
        .get();

      if (!customerDoc.exists) return null;

      const customerData = customerDoc.data();
      const fcmToken = customerData.fcmToken;

      if (!fcmToken) {
        console.log('Customer has no FCM token');
        return null;
      }

      // Send notification
      const payload = {
        notification: {
          title: 'Support Reply',
          body: message.text || 'You have a new reply',
        },
        data: {
          type: 'admin_reply',
          roomId: roomId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        token: fcmToken,
      };

      await admin.messaging().send(payload);
      console.log(`Notification sent to customer ${customerId}`);

      return null;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });
