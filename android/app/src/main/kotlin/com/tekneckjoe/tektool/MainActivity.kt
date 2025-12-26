package com.tekneckjoe.tektool

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


// MainActivity handles the bridge between Flutter and Android for SMS auto-responder features.
class MainActivity : FlutterActivity() {


    companion object {
        // MethodChannel name for Flutter/Dart communication
        private const val CHANNEL = "com.tekneckjoe.tektool/sms_autoresponder"
        // Request code for SMS permissions
        private const val SMS_PERMISSION_REQUEST_CODE = 101
    }

    // Sets up the MethodChannel for communication with Dart. Call this in onCreate for FlutterActivity.
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Set up MethodChannel after Flutter is initialized
        MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, CHANNEL).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                // Handles permission request from Flutter
                "requestSmsPermissions" -> {
                    requestSmsPermissions()
                    result.success(true)
                }
                // Checks if SMS permissions are granted
                "checkSmsPermissions" -> {
                    result.success(hasSmsPermissions())
                }
                // Enables or disables the SMS auto-responder
                "setAutoResponderEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    SmsReceiver.setEnabled(this, enabled)
                    result.success(true)
                }
                // Sets the auto-reply text
                "setAutoReplyText" -> {
                    val text = call.argument<String>("text") ?: ""
                    SmsReceiver.setAutoReplyText(this, text)
                    result.success(true)
                }
                // Sets the auto-reply active hours
                "setAutoReplyHours" -> {
                    val startHour = call.argument<Int>("startHour") ?: 7
                    val endHour = call.argument<Int>("endHour") ?: 19
                    SmsReceiver.setAutoReplyHours(this, startHour, endHour)
                    result.success(true)
                }
                // Gets the current auto-responder status and settings
                "getAutoResponderStatus" -> {
                    val status = mapOf(
                        "enabled" to SmsReceiver.isEnabled(this),
                        "hasPermissions" to hasSmsPermissions(),
                        "autoReplyText" to SmsReceiver.getAutoReplyText(this),
                        "startHour" to SmsReceiver.getStartHour(this),
                        "endHour" to SmsReceiver.getEndHour(this),
                        "repliesSent" to SmsReceiver.getRepliesSentCount(this)
                    )
                    result.success(status)
                }
                // Sends a test SMS (for diagnostics)
                "sendTestSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                    val message = call.argument<String>("message") ?: "Test from TekTool"
                    val success = SmsReceiver.sendSms(this, phoneNumber, message)
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // Checks if all required SMS permissions are granted.
    private fun hasSmsPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED &&
               ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED &&
               ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
    }

    // Requests all necessary SMS permissions from the user.
    private fun requestSmsPermissions() {
        val permissions = arrayOf(
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.SEND_SMS,
            Manifest.permission.READ_SMS
        )
        ActivityCompat.requestPermissions(this, permissions, SMS_PERMISSION_REQUEST_CODE)
    }
}
