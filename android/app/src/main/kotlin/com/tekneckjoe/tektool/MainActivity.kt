package com.tekneckjoe.tektool

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.appcompat.app.AppCompatActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


// MainActivity handles the bridge between Flutter and Android for SMS auto-responder features.
// Extends FlutterFragmentActivity (required by Stripe plugin)
class MainActivity : FlutterFragmentActivity() {


    companion object {
        // MethodChannel names for Flutter/Dart communication
        private const val CHANNEL = "com.tekneckjoe.tektool/sms_autoresponder"
        private const val HCI_CHANNEL = "com.tekneckjoe.tektool/hci_capture"
        // Request codes for permissions
        private const val SMS_PERMISSION_REQUEST_CODE = 101
        // Log tag for theme debugging
        private const val TAG = "MainActivity"
    }

    // Verify we have an AppCompat theme at startup (Stripe needs it for UI).
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Log theme configuration for Stripe debugging
        try {
            val theme = theme
            Log.d(TAG, "✅ MainActivity theme initialized")
            Log.d(TAG, "✅ Activity is AppCompatActivity: ${this is AppCompatActivity}") // AppCompatActivity check
            
            // Verify AppCompat theme attributes are available
            val typedValue = TypedValue()
            val resolved = theme.resolveAttribute(androidx.appcompat.R.attr.colorPrimary, typedValue, true)
            if (resolved) {
                Log.d(TAG, "✅ AppCompat theme attributes resolved successfully")
            } else {
                Log.w(TAG, "⚠️ AppCompat theme attributes not found - potential Stripe theme issue")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error verifying theme configuration: ${e.message}")
        }
    }

    // Sets up the MethodChannel for communication with Dart. Call this in configureFlutterEngine for FlutterActivity.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up SMS MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
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
        
        // Set up HCI Capture MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HCI_CHANNEL).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "checkHciLogging" -> {
                    result.success(isHciLoggingEnabled())
                }
                "enableHciLogging" -> {
                    result.success(enableHciLogging())
                }
                "captureHciLog" -> {
                    captureHciLogAsync(result)
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
    
    // ========================================================================
    // HCI LOG CAPTURE METHODS
    // ========================================================================
    
    // Check if HCI logging is currently enabled
    private fun isHciLoggingEnabled(): Boolean {
        return try {
            // Try multiple property names (Samsung/different Android versions)
            val properties = listOf(
                "persist.bluetooth.btsnooplogmode",
                "persist.bluetooth.btsnoopenable",
                "persist.vendor.bluetooth.btsnooplogmode"
            )
            
            for (propName in properties) {
                try {
                    val prop = Runtime.getRuntime().exec("getprop $propName")
                    val reader = prop.inputStream.bufferedReader()
                    val value = reader.readText().trim()
                    
                    Log.d(TAG, "Checking $propName: $value")
                    
                    // Check various enabled states
                    if (value.equals("full", ignoreCase = true) ||
                        value.equals("filtered", ignoreCase = true) ||
                        value.equals("true", ignoreCase = true) ||
                        value == "1"
                    ) {
                        Log.d(TAG, "✅ HCI logging enabled via $propName = $value")
                        return true
                    }
                } catch (e: Exception) {
                    // Try next property
                    continue
                }
            }
            
            // Fallback: Check if HCI log file exists and is being written to
            val hciLogFile = java.io.File("/data/misc/bluetooth/logs/btsnoop_hci.log")
            if (hciLogFile.exists()) {
                val lastModified = hciLogFile.lastModified()
                val ageMinutes = (System.currentTimeMillis() - lastModified) / 1000 / 60
                Log.d(TAG, "HCI log file exists, modified $ageMinutes minutes ago")
                
                // If log was modified in last 5 minutes, assume logging is active
                if (ageMinutes < 5) {
                    Log.d(TAG, "✅ HCI logging enabled (file recently modified)")
                    return true
                }
            }
            
            Log.w(TAG, "❌ HCI logging not detected via any method")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking HCI logging: ${e.message}")
            false
        }
    }
    
    // Enable HCI logging (requires developer options)
    private fun enableHciLogging(): Boolean {
        return try {
            // Note: This typically requires user to enable in Developer Options
            // We can only check/inform, not actually enable it programmatically
            Log.i(TAG, "HCI logging must be enabled manually in Developer Options")
            false // Return false to indicate user action needed
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling HCI: ${e.message}")
            false
        }
    }
    
    // Capture HCI log asynchronously (runs in background thread)
    private fun captureHciLogAsync(result: MethodChannel.Result) {
        Thread {
            try {
                val logPath = captureHciLog()
                if (logPath != null) {
                    runOnUiThread {
                        result.success(logPath)
                    }
                } else {
                    runOnUiThread {
                        result.error("CAPTURE_FAILED", "Failed to capture HCI log", null)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "HCI capture error: ${e.message}")
                runOnUiThread {
                    result.error("CAPTURE_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    // Capture HCI log from Android system
    private fun captureHciLog(): String? {
        return try {
            Log.i(TAG, "🔍 Starting HCI log capture...")
            
            val appDir = applicationContext.getExternalFilesDir(null)
            val timestamp = System.currentTimeMillis()
            val destDir = java.io.File("$appDir/hci_logs")
            destDir.mkdirs()
            val destPath = "$appDir/hci_logs/btsnoop_${timestamp}.log"
            val destFile = java.io.File(destPath)
            
            // Try multiple methods to access HCI log with proper error handling
            
            // Method 1: Direct file access (works if app has system permissions)
            Log.d(TAG, "📋 Method 1: Direct file access...")
            try {
                val hciLogPath = "/data/misc/bluetooth/logs/btsnoop_hci.log"
                val hciLogFile = java.io.File(hciLogPath)
                
                if (hciLogFile.exists() && hciLogFile.canRead()) {
                    hciLogFile.inputStream().use { input ->
                        destFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                    if (destFile.length() > 0) {
                        Log.i(TAG, "✅ Method 1 success: Direct file access worked")
                        Log.i(TAG, "   File: $destPath (${destFile.length()} bytes)")
                        return destPath
                    }
                }
                Log.w(TAG, "❌ Method 1 failed: File not readable (exists: ${hciLogFile.exists()}, canRead: ${hciLogFile.canRead()})")
            } catch (e: Exception) {
                Log.w(TAG, "❌ Method 1 exception: ${e.message}")
            }
            
            // Method 2: Try via sh -c command (better compatibility)
            Log.d(TAG, "📋 Method 2: Shell command (sh -c)...")
            try {
                val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", "cat /data/misc/bluetooth/logs/btsnoop_hci.log"))
                process.inputStream.use { input ->
                    destFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                process.waitFor()
                
                if (destFile.length() > 0) {
                    Log.i(TAG, "✅ Method 2 success: Shell command worked")
                    Log.i(TAG, "   File: $destPath (${destFile.length()} bytes)")
                    return destPath
                }
                Log.w(TAG, "❌ Method 2 failed: Empty output (${destFile.length()} bytes)")
            } catch (e: Exception) {
                Log.w(TAG, "❌ Method 2 exception: ${e.message}")
            }
            
            // Method 3: Try raw ProcessBuilder approach
            Log.d(TAG, "📋 Method 3: ProcessBuilder (cat command)...")
            try {
                val processBuilder = ProcessBuilder("cat", "/data/misc/bluetooth/logs/btsnoop_hci.log")
                val process = processBuilder.start()
                process.inputStream.use { input ->
                    destFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                process.waitFor()
                
                if (destFile.length() > 0) {
                    Log.i(TAG, "✅ Method 3 success: ProcessBuilder worked")
                    Log.i(TAG, "   File: $destPath (${destFile.length()} bytes)")
                    return destPath
                }
                Log.w(TAG, "❌ Method 3 failed: Empty output")
            } catch (e: Exception) {
                Log.w(TAG, "❌ Method 3 exception: ${e.message}")
            }
            
            // Method 4: Check app's private directory for HCI logs (Android 12+)
            Log.d(TAG, "📋 Method 4: Checking private app directories...")
            try {
                val privateHciDir = java.io.File(filesDir, "bluetooth_logs")
                if (privateHciDir.exists()) {
                    val files = privateHciDir.listFiles()
                    if (files != null && files.isNotEmpty()) {
                        Log.i(TAG, "✅ Method 4 success: Found HCI log in app dir")
                        Log.i(TAG, "   File: ${files[0].absolutePath}")
                        return files[0].absolutePath
                    }
                }
                Log.w(TAG, "❌ Method 4 failed: No logs in app private dir")
            } catch (e: Exception) {
                Log.w(TAG, "❌ Method 4 exception: ${e.message}")
            }
            
            // All methods failed
            Log.e(TAG, "❌ HCI log not accessible via any method:")
            Log.e(TAG, "   Possible causes:")
            Log.e(TAG, "   1. HCI logging disabled in Developer Settings")
            Log.e(TAG, "   2. SELinux policies preventing access (/data/misc/bluetooth/logs/)")
            Log.e(TAG, "   3. Device requires root or elevated privileges")
            Log.e(TAG, "   4. HCI log file not yet created (toggle Bluetooth to generate)")
            null
        } catch (e: Exception) {
            Log.e(TAG, "❌ HCI capture outer exception: ${e.message}")
            e.printStackTrace()
            null
        }
    }
}
