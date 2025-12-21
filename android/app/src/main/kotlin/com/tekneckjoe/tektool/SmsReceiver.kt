package com.tekneckjoe.tektool

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SmsMessage
import android.util.Log
import java.util.Calendar

/**
 * SMS Auto-Responder BroadcastReceiver
 * Intercepts incoming SMS and sends auto-reply during configured hours
 * 
 * Admin-only feature for TekTool
 */
class SmsReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "SmsAutoResponder"
        private const val PREFS_NAME = "sms_autoresponder_prefs"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_AUTO_REPLY_TEXT = "auto_reply_text"
        private const val KEY_START_HOUR = "start_hour"
        private const val KEY_END_HOUR = "end_hour"
        private const val KEY_REPLIES_SENT = "replies_sent_count"
        private const val KEY_LAST_REPLY_TO = "last_reply_to"
        private const val KEY_LAST_REPLY_TIME = "last_reply_time"
        
        // Cooldown to prevent spam - 1 hour between auto-replies to same number
        private const val REPLY_COOLDOWN_MS = 60 * 60 * 1000L
        
        private const val DEFAULT_AUTO_REPLY = "Hi! Thanks for messaging. I'm currently unavailable but will get back to you soon. - TekTool"
        
        private fun getPrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
        
        fun setEnabled(context: Context, enabled: Boolean) {
            getPrefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
            Log.d(TAG, "Auto-responder enabled: $enabled")
        }
        
        fun isEnabled(context: Context): Boolean {
            return getPrefs(context).getBoolean(KEY_ENABLED, false)
        }
        
        fun setAutoReplyText(context: Context, text: String) {
            getPrefs(context).edit().putString(KEY_AUTO_REPLY_TEXT, text).apply()
        }
        
        fun getAutoReplyText(context: Context): String {
            return getPrefs(context).getString(KEY_AUTO_REPLY_TEXT, DEFAULT_AUTO_REPLY) ?: DEFAULT_AUTO_REPLY
        }
        
        fun setAutoReplyHours(context: Context, startHour: Int, endHour: Int) {
            getPrefs(context).edit()
                .putInt(KEY_START_HOUR, startHour)
                .putInt(KEY_END_HOUR, endHour)
                .apply()
        }
        
        fun getStartHour(context: Context): Int {
            return getPrefs(context).getInt(KEY_START_HOUR, 7)
        }
        
        fun getEndHour(context: Context): Int {
            return getPrefs(context).getInt(KEY_END_HOUR, 19)
        }
        
        fun getRepliesSentCount(context: Context): Int {
            return getPrefs(context).getInt(KEY_REPLIES_SENT, 0)
        }
        
        private fun incrementRepliesSent(context: Context) {
            val current = getRepliesSentCount(context)
            getPrefs(context).edit().putInt(KEY_REPLIES_SENT, current + 1).apply()
        }
        
        private fun canReplyToNumber(context: Context, phoneNumber: String): Boolean {
            val prefs = getPrefs(context)
            val lastReplyTo = prefs.getString(KEY_LAST_REPLY_TO, null)
            val lastReplyTime = prefs.getLong(KEY_LAST_REPLY_TIME, 0)
            
            // If different number or cooldown expired, allow reply
            if (lastReplyTo != phoneNumber) return true
            if (System.currentTimeMillis() - lastReplyTime > REPLY_COOLDOWN_MS) return true
            
            Log.d(TAG, "Skipping auto-reply to $phoneNumber - cooldown active")
            return false
        }
        
        private fun recordReplyToNumber(context: Context, phoneNumber: String) {
            getPrefs(context).edit()
                .putString(KEY_LAST_REPLY_TO, phoneNumber)
                .putLong(KEY_LAST_REPLY_TIME, System.currentTimeMillis())
                .apply()
        }
        
        /**
         * Send SMS directly (used for testing)
         */
        fun sendSms(context: Context, phoneNumber: String, message: String): Boolean {
            return try {
                val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    context.getSystemService(SmsManager::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }
                
                // Split long messages
                val parts = smsManager.divideMessage(message)
                if (parts.size > 1) {
                    smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                } else {
                    smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                }
                Log.d(TAG, "SMS sent to $phoneNumber")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send SMS: ${e.message}")
                false
            }
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return
        
        // Check if auto-responder is enabled
        if (!isEnabled(context)) {
            Log.d(TAG, "Auto-responder is disabled, ignoring SMS")
            return
        }
        
        // Check if current time is outside business hours (auto-reply only during off-hours)
        if (!shouldAutoReply(context)) {
            Log.d(TAG, "Within business hours, not auto-replying")
            return
        }
        
        // Extract SMS data
        val bundle = intent.extras ?: return
        val pdus = bundle.get("pdus") as? Array<*> ?: return
        val format = bundle.getString("format")
        
        for (pdu in pdus) {
            val smsMessage = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                SmsMessage.createFromPdu(pdu as ByteArray, format)
            } else {
                @Suppress("DEPRECATION")
                SmsMessage.createFromPdu(pdu as ByteArray)
            }
            
            val senderNumber = smsMessage.originatingAddress ?: continue
            val messageBody = smsMessage.messageBody ?: continue
            
            Log.d(TAG, "Received SMS from: $senderNumber")
            
            // Check cooldown for this number
            if (!canReplyToNumber(context, senderNumber)) continue
            
            // Send auto-reply
            val replyText = getAutoReplyText(context)
            val sent = sendSms(context, senderNumber, replyText)
            
            if (sent) {
                recordReplyToNumber(context, senderNumber)
                incrementRepliesSent(context)
                Log.d(TAG, "Auto-reply sent to $senderNumber")
            }
        }
    }
    
    /**
     * Check if we should auto-reply based on current time
     * Returns true if OUTSIDE business hours (when auto-reply should be active)
     */
    private fun shouldAutoReply(context: Context): Boolean {
        val calendar = Calendar.getInstance()
        val currentHour = calendar.get(Calendar.HOUR_OF_DAY)
        
        val startHour = getStartHour(context) // Start of business hours
        val endHour = getEndHour(context)     // End of business hours
        
        // Auto-reply when OUTSIDE business hours
        // If startHour=7 and endHour=19, auto-reply from 7pm to 7am
        return currentHour < startHour || currentHour >= endHour
    }
}
