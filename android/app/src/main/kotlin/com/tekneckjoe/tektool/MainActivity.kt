package com.tekneckjoe.tektool

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.tekneckjoe.tektool/sms_autoresponder"
    private val SMS_PERMISSION_REQUEST_CODE = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermissions" -> {
                    requestSmsPermissions()
                    result.success(true)
                }
                "checkSmsPermissions" -> {
                    result.success(hasSmsPermissions())
                }
                "setAutoResponderEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    SmsReceiver.setEnabled(this, enabled)
                    result.success(true)
                }
                "setAutoReplyText" -> {
                    val text = call.argument<String>("text") ?: ""
                    SmsReceiver.setAutoReplyText(this, text)
                    result.success(true)
                }
                "setAutoReplyHours" -> {
                    val startHour = call.argument<Int>("startHour") ?: 7
                    val endHour = call.argument<Int>("endHour") ?: 19
                    SmsReceiver.setAutoReplyHours(this, startHour, endHour)
                    result.success(true)
                }
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

    private fun hasSmsPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED &&
               ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED &&
               ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermissions() {
        val permissions = arrayOf(
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.SEND_SMS,
            Manifest.permission.READ_SMS
        )
        ActivityCompat.requestPermissions(this, permissions, SMS_PERMISSION_REQUEST_CODE)
    }
}
