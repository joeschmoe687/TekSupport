/**
 * Firebase Cloud Functions for TekNeck HVAC Support App
 * 
 * This file contains all Cloud Functions including:
 * - Payment processing (Stripe)
 * - TekMate AI chat proxy (admin only)
 * - Push notifications
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

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
    console.log('tekmateChatProxy: Unauthorized - no auth token');
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }

  const userId = context.auth.uid;
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

    if (!isAdmin) {
      console.log(`tekmateChatProxy: User ${userId} is not admin`);
      // Return generic "access denied" - don't reveal TekMate exists
      throw new functions.https.HttpsError(
        'permission-denied',
        'Access denied'
      );
    }

    // Extract request data
    const { message, context: requestContext, platform } = data;

    if (!message || typeof message !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Message is required'
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

  if (req.method !== 'POST') {
    res.status(405).send({ error: 'Method not allowed' });
    return;
  }

  try {
    const { amount, currency, description, userId, email } = req.body;

    if (!amount || !currency || !userId) {
      res.status(400).send({ 
        error: 'Missing required parameters',
        required: ['amount', 'currency', 'userId']
      });
      return;
    }

    if (amount <= 0) {
      res.status(400).send({ error: 'Amount must be positive' });
      return;
    }

    console.log(`Creating payment intent for user ${userId}, amount: ${amount} ${currency}`);

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
      automatic_payment_methods: {
        enabled: true,
      },
    });

    console.log(`Payment intent created: ${paymentIntent.id}`);

    res.status(200).send({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });

  } catch (error) {
    console.error('Error creating payment intent:', error);
    
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
