package com.poyrazoncel.korubeni

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.Settings
import android.view.KeyEvent
import com.poyrazoncel.korubeni.emergency.EmergencyChannels
import com.poyrazoncel.korubeni.emergency.EmergencyEventStreamHandler
import com.poyrazoncel.korubeni.emergency.EmergencyPlatformHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val ANDROID_INTENTS_CHANNEL = "com.poyrazoncel.korubeni/android_intents"
        private const val SETTINGS_CHANNEL = "com.poyrazoncel.korubeni/settings"
        private const val AUDIO_CONTROL_CHANNEL = "com.poyrazoncel.korubeni/audio_control"
        private const val CONTACTS_PICKER_CHANNEL = "com.poyrazoncel.korubeni/contacts_picker"
        private const val CONTACT_PICK_REQUEST_CODE = 7341
    }

    private val volumeDetector = VolumeButtonDetector()
    private lateinit var dozeModeHandler: DozeModeHandler
    private lateinit var emergencyPlatformHandler: EmergencyPlatformHandler
    private var pendingContactPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            val messenger = flutterEngine.dartExecutor.binaryMessenger
            emergencyPlatformHandler = EmergencyPlatformHandler(this)

            // Volume button EventChannel — Flutter'a sürekli event akışı
            try {
                EventChannel(messenger, VolumeButtonDetector.CHANNEL)
                    .setStreamHandler(volumeDetector)
                android.util.Log.d("MainActivity", "Volume detector EventChannel configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Volume EventChannel failed: ${e.message}", e)
            }

            // Volume button MethodChannel — enable/disable kontrolü
            try {
                MethodChannel(messenger, "${VolumeButtonDetector.CHANNEL}/control")
                    .setMethodCallHandler { call, result ->
                        try {
                            when (call.method) {
                                "setEnabled" -> {
                                    val enabled = call.argument<Boolean>("enabled") ?: false
                                    volumeDetector.setEnabled(enabled)
                                    result.success(true)
                                }
                                else -> result.notImplemented()
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Volume control error: ${e.message}")
                            result.error("ERROR", e.message, null)
                        }
                    }
                android.util.Log.d("MainActivity", "Volume detector MethodChannel configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Volume MethodChannel failed: ${e.message}", e)
            }

            try {
                MethodChannel(messenger, AUDIO_CONTROL_CHANNEL)
                    .setMethodCallHandler { call, result ->
                        try {
                            val audioManager =
                                getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            when (call.method) {
                                "setMaxAlarmVolume" -> {
                                    val original =
                                        audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                                    val max =
                                        audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                                    audioManager.setStreamVolume(
                                        AudioManager.STREAM_ALARM,
                                        max,
                                        0
                                    )
                                    result.success(original)
                                }
                                "restoreAlarmVolume" -> {
                                    val requested = call.arguments as? Int
                                    if (requested != null) {
                                        val max = audioManager.getStreamMaxVolume(
                                            AudioManager.STREAM_ALARM
                                        )
                                        audioManager.setStreamVolume(
                                            AudioManager.STREAM_ALARM,
                                            requested.coerceIn(0, max),
                                            0
                                        )
                                    }
                                    result.success(true)
                                }
                                else -> result.notImplemented()
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Audio control error: ${e.message}")
                            result.error("AUDIO_CONTROL_ERROR", e.message, null)
                        }
                    }
                android.util.Log.d("MainActivity", "Audio control MethodChannel configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Audio control channel failed: ${e.message}", e)
            }

            // Doze Mode handler — optional battery optimization reliability flow
            try {
                dozeModeHandler = DozeModeHandler(this)
                MethodChannel(messenger, DozeModeHandler.CHANNEL)
                    .setMethodCallHandler(dozeModeHandler)
                android.util.Log.d("MainActivity", "Doze Mode handler configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Doze Mode handler failed: ${e.message}", e)
            }

            try {
                MethodChannel(messenger, EmergencyChannels.METHOD)
                    .setMethodCallHandler(emergencyPlatformHandler)
                EventChannel(messenger, EmergencyChannels.EVENTS)
                    .setStreamHandler(EmergencyEventStreamHandler())
                android.util.Log.d("MainActivity", "Emergency platform configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Emergency platform failed: ${e.message}", e)
            }

            try {
                MethodChannel(messenger, ANDROID_INTENTS_CHANNEL)
                    .setMethodCallHandler { call, result ->
                        try {
                            when (call.method) {
                                "openDialer" -> {
                                    val number = call.argument<String>("number").orEmpty()
                                    result.success(openDialer(number))
                                }
                                else -> result.notImplemented()
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Android intents error: ${e.message}", e)
                            result.error("ANDROID_INTENTS_ERROR", e.message, null)
                        }
                    }
                android.util.Log.d("MainActivity", "Android intent channel configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Android intent channel failed: ${e.message}", e)
            }
            
            // Settings channel (extended) — battery optimization + manufacturer auto-start
            try {
                MethodChannel(messenger, SETTINGS_CHANNEL)
                    .setMethodCallHandler { call, result ->
                        try {
                            when (call.method) {
                                "openBatterySettings" -> {
                                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                        Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                            data = Uri.parse("package:$packageName")
                                        }
                                    } else {
                                        Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
                                    }
                                    startActivity(intent)
                                    result.success(true)
                                }
                                "openActivityByComponent" -> {
                                    val component = call.argument<String>("component").orEmpty()
                                    if (component.isEmpty()) {
                                        result.error("INVALID_ARG", "component is empty", null)
                                        return@setMethodCallHandler
                                    }
                                    val parts = component.split("/")
                                    if (parts.size != 2) {
                                        result.error("INVALID_ARG", "component format must be pkg/class", null)
                                        return@setMethodCallHandler
                                    }
                                    val intent = Intent().apply {
                                        setComponent(ComponentName(parts[0], parts[1]))
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(intent)
                                    result.success(true)
                                }
                                "openNotificationSettings" -> {
                                    // Android 8.0+ supports the dedicated app-notification
                                    // settings screen; older versions fall back to the
                                    // generic app details page.
                                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        }
                                    } else {
                                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                            data = Uri.fromParts("package", packageName, null)
                                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        }
                                    }
                                    startActivity(intent)
                                    result.success(true)
                                }
                                else -> result.notImplemented()
                            }
                        } catch (e: ActivityNotFoundException) {
                            result.error("NOT_FOUND", "Settings screen not available: ${e.message}", null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                android.util.Log.d("MainActivity", "Settings channel (extended) configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Settings channel (extended) failed: ${e.message}", e)
            }

            // Permissionless single-contact picker. ACTION_PICK on the phone
            // data URI grants temporary read access to just the picked row, so
            // no READ_CONTACTS permission and no broad address-book access.
            try {
                MethodChannel(messenger, CONTACTS_PICKER_CHANNEL)
                    .setMethodCallHandler { call, result ->
                        when (call.method) {
                            "pickPhoneContact" -> startPhoneContactPick(result)
                            else -> result.notImplemented()
                        }
                    }
                android.util.Log.d("MainActivity", "Contacts picker channel configured")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Contacts picker channel failed: ${e.message}", e)
            }

            android.util.Log.i("MainActivity", "All platform channels configured successfully")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Critical: configureFlutterEngine failed", e)
            // Don't crash - let Flutter handle it
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (volumeDetector.onKeyEvent(event)) {
            return true // Event consume edildi
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (volumeDetector.onKeyEvent(event)) {
            return true // Event consume edildi
        }
        return super.onKeyUp(keyCode, event)
    }
    
    /**
     * Lifecycle cleanup - prevent memory leaks
     */
    override fun onDestroy() {
        try {
            volumeDetector.setEnabled(false)
            android.util.Log.d("MainActivity", "Resources cleaned up")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Cleanup failed: ${e.message}")
        }
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    private fun startPhoneContactPick(result: MethodChannel.Result) {
        // One pick at a time; reject re-entrancy without dropping the first.
        if (pendingContactPickResult != null) {
            result.error("ALREADY_ACTIVE", "A contact pick is already in progress", null)
            return
        }
        val intent = Intent(
            Intent.ACTION_PICK,
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
        )
        try {
            pendingContactPickResult = result
            startActivityForResult(intent, CONTACT_PICK_REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            pendingContactPickResult = null
            result.error("NO_PICKER", "No contacts app available to pick from", null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CONTACT_PICK_REQUEST_CODE) {
            return
        }
        // One-shot guard: ignore any duplicate delivery or a callback that
        // arrives after process death (pendingContactPickResult would be null).
        val result = pendingContactPickResult ?: return
        pendingContactPickResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null) // user cancelled
            return
        }
        try {
            result.success(readPickedPhoneContact(data.data!!))
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Contact pick query failed: ${e.message}", e)
            result.error("PICK_FAILED", e.message, null)
        }
    }

    private fun readPickedPhoneContact(uri: Uri): Map<String, String>? {
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
        )
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val numberIdx =
                    cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                val nameIdx =
                    cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val number = if (numberIdx >= 0) cursor.getString(numberIdx) ?: "" else ""
                val name = if (nameIdx >= 0) cursor.getString(nameIdx) ?: "" else ""
                return mapOf("number" to number, "name" to name)
            }
        }
        return null
    }

    private fun openDialer(number: String): Boolean {
        // Audit F5: same separator-stripping defense as EmergencyExecutor.
        val cleaned = com.poyrazoncel.korubeni.emergency.EmergencyExecutor
            .sanitizeForDial(number)
        if (cleaned.isEmpty()) {
            return false
        }

        val intent = Intent(Intent.ACTION_DIAL).apply {
            data = Uri.parse("tel:$cleaned")
        }

        return startExternalIntent(intent)
    }

    private fun startExternalIntent(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            android.util.Log.e("MainActivity", "Intent launch failed: ${e.message}", e)
            false
        }
    }
}
