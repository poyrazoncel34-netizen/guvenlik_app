package com.poyrazoncel.korubeni

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.ContactsContract
import android.provider.Settings
import android.view.KeyEvent
import android.view.WindowManager
import com.poyrazoncel.korubeni.emergency.EmergencyChannels
import com.poyrazoncel.korubeni.emergency.EmergencyEventStreamHandler
import com.poyrazoncel.korubeni.emergency.EmergencyPlatformHandler
import com.poyrazoncel.korubeni.quickaccess.PanicLaunch
import com.poyrazoncel.korubeni.quickaccess.PanicRequestStore
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
        private const val QUICK_PANIC_CHANNEL = "com.poyrazoncel.korubeni/quick_panic"
        private const val DEEP_LINK_CHANNEL = "com.poyrazoncel.korubeni/deep_link"

        /// The ONLY scheme this Activity will hand to Dart. The manifest filter
        /// already restricts what Android delivers; this is the second half of
        /// the same rule, kept here so a manifest edit alone cannot widen it.
        private const val DEEP_LINK_SCHEME = "korubeni"

        /// A bound before the string ever leaves Kotlin. Dart bounds it again;
        /// neither side trusts the other's check.
        private const val DEEP_LINK_MAX_LENGTH = 512
        private const val CONTACT_PICK_REQUEST_CODE = 7341
    }

    private val volumeDetector = VolumeButtonDetector()
    private lateinit var emergencyPlatformHandler: EmergencyPlatformHandler
    private var pendingContactPickResult: MethodChannel.Result? = null

    /// The most recent unconsumed link. One slot, not a queue: a burst of links
    /// means the user pressed something repeatedly, and it must not accumulate
    /// navigations that all fire after the PIN gate.
    private var pendingDeepLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // FLAG_SECURE blocks screenshots, screen recording and the recents
        // thumbnail for the whole app. Under the duress model the screens that
        // matter are the PIN pad, the emergency contact list and the safety
        // timeline — and screen-capturing stalkerware is precisely the threat
        // that harvests a PIN as it is typed. It is applied window-wide rather
        // than per screen because a per-screen list is one forgotten route
        // away from leaking the thing it was meant to protect.
        //
        // Debug builds are exempt so `scripts/capture_screenshots.sh` can still
        // produce the store assets; the shipped release build is protected.
        if (!BuildConfig.DEBUG) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
        // Quick-access requests are NO LONGER read from this Activity's intent.
        // MainActivity is the exported launcher component, so any app could set
        // the PANIC_SOURCE extra and drop the user into a real, PIN-gated
        // countdown. The request is now written by QuickPanicTrampolineActivity,
        // which is not exported and therefore only reachable from our own
        // PendingIntents. Verified on device: Activity.launchedFromUid returns
        // -1 here both before and after super.onCreate(), so a UID check at this
        // point is not a usable defence.
        super.onCreate(savedInstanceState)
        captureDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // launchMode is singleTop, so a tap while the app is already running
        // arrives here rather than through onCreate.
        setIntent(intent)
        captureDeepLink(intent)
    }

    /// Records a VIEW intent's data for Dart to collect.
    ///
    /// Read-and-clear, like the quick-access request: Dart asks on init and on
    /// resume, and one incoming link must produce at most one navigation. The
    /// link is only PARKED here — nothing in this Activity acts on it, and the
    /// Dart side cannot navigate until every gate has completed.
    private fun captureDeepLink(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val data = intent.data ?: return
        if (data.scheme != DEEP_LINK_SCHEME) return
        val asString = data.toString()
        if (asString.length > DEEP_LINK_MAX_LENGTH) return
        pendingDeepLink = asString
    }

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
            } catch (_: Exception) {
                android.util.Log.e("MainActivity", "VOLUME_EVENT_CHANNEL_CONFIG_FAILED")
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
                        } catch (_: Exception) {
                            android.util.Log.e("MainActivity", "VOLUME_CONTROL_ERROR")
                            result.error("ERROR", "Volume control failed", null)
                        }
                    }
                android.util.Log.d("MainActivity", "Volume detector MethodChannel configured")
            } catch (_: Exception) {
                android.util.Log.e("MainActivity", "VOLUME_METHOD_CHANNEL_CONFIG_FAILED")
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
                        } catch (_: Exception) {
                            android.util.Log.e("MainActivity", "AUDIO_CONTROL_ERROR")
                            result.error("AUDIO_CONTROL_ERROR", "Audio control failed", null)
                        }
                    }
                android.util.Log.d("MainActivity", "Audio control MethodChannel configured")
            } catch (_: Exception) {
                android.util.Log.e("MainActivity", "AUDIO_CONTROL_CHANNEL_CONFIG_FAILED")
            }

            try {
                MethodChannel(messenger, EmergencyChannels.METHOD)
                    .setMethodCallHandler(emergencyPlatformHandler)
                EventChannel(messenger, EmergencyChannels.EVENTS)
                    .setStreamHandler(EmergencyEventStreamHandler())
                android.util.Log.d("MainActivity", "Emergency platform configured")
            } catch (_: Exception) {
                android.util.Log.e("MainActivity", "EMERGENCY_PLATFORM_CONFIG_FAILED")
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
                        } catch (_: Exception) {
                            android.util.Log.e("MainActivity", "ANDROID_INTENTS_ERROR")
                            result.error("ANDROID_INTENTS_ERROR", "Intent request failed", null)
                        }
                    }
                android.util.Log.d("MainActivity", "Android intent channel configured")
            } catch (_: Exception) {
                android.util.Log.e("MainActivity", "ANDROID_INTENT_CHANNEL_CONFIG_FAILED")
            }
            
            // Settings channel — notification and explicit OEM settings links.
            // Battery exemption authority belongs exclusively to
            // EmergencyPlatformHandler.
            try {
                MethodChannel(messenger, SETTINGS_CHANNEL)
                    .setMethodCallHandler { call, result ->
                        try {
                            when (call.method) {
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
                                "getDeviceManufacturer" -> {
                                    // Build.MANUFACTURER needs no permission and
                                    // identifies no user. The OEM background guide
                                    // uses it to pick which settings screens exist
                                    // on this device.
                                    result.success(Build.MANUFACTURER)
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
                        } catch (_: ActivityNotFoundException) {
                            result.error("NOT_FOUND", "Settings screen not available", null)
                        } catch (_: Exception) {
                            result.error("ERROR", "Settings request failed", null)
                        }
                    }
                android.util.Log.d("MainActivity", "Settings channel (extended) configured")
            } catch (_: Exception) {
                android.util.Log.e("MainActivity", "SETTINGS_CHANNEL_CONFIG_FAILED")
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
            } catch (_: Exception) {
                android.util.Log.e("MainActivity", "CONTACTS_PICKER_CHANNEL_CONFIG_FAILED")
            }

            // Quick-access hand-off. Read-and-clear only; the widget and the
            // tile cannot arm anything through this channel.
            try {
                MethodChannel(messenger, DEEP_LINK_CHANNEL)
                    .setMethodCallHandler { call, result ->
                        when (call.method) {
                            "consumeDeepLink" -> {
                                val link = pendingDeepLink
                                pendingDeepLink = null
                                result.success(link)
                            }
                            else -> result.notImplemented()
                        }
                    }

                MethodChannel(messenger, QUICK_PANIC_CHANNEL)
                    .setMethodCallHandler { call, result ->
                        try {
                            when (call.method) {
                                "consumePanicRequest" -> {
                                    result.success(
                                        PanicRequestStore.consume(applicationContext),
                                    )
                                }
                                else -> result.notImplemented()
                            }
                        } catch (_: Exception) {
                            android.util.Log.e("MainActivity", "QUICK_PANIC_ERROR")
                            result.error("ERROR", "Quick panic request failed", null)
                        }
                    }
                android.util.Log.d("MainActivity", "Quick panic channel configured")
            } catch (_: Exception) {
                android.util.Log.e("MainActivity", "QUICK_PANIC_CHANNEL_CONFIG_FAILED")
            }

            android.util.Log.i("MainActivity", "All platform channels configured successfully")
        } catch (_: Exception) {
            android.util.Log.e("MainActivity", "FLUTTER_ENGINE_CONFIG_FAILED")
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
        } catch (_: Exception) {
            android.util.Log.e("MainActivity", "LIFECYCLE_CLEANUP_FAILED")
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
        } catch (_: Exception) {
            android.util.Log.e("MainActivity", "CONTACT_PICK_QUERY_FAILED")
            result.error("PICK_FAILED", "Contact query failed", null)
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
        // Use the same side-effect-free target boundary as the safety kernel.
        val cleaned = com.poyrazoncel.korubeni.emergency.EmergencyTargetValidator
            .normalizedCallableOrNull(number) ?: return false

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
        } catch (_: ActivityNotFoundException) {
            android.util.Log.e("MainActivity", "INTENT_LAUNCH_NOT_FOUND")
            false
        }
    }
}
