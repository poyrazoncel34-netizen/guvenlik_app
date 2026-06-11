package com.poyrazoncel.korubeni.emergency

import android.content.Context
import java.util.Locale

object NativeNotificationText {
    data class NotificationCopy(
        val title: String,
        val body: String,
    )

    private enum class Language {
        TR,
        EN,
    }

    fun channelName(context: Context, channelId: String): String {
        val strings = strings(context)
        return when (channelId) {
            EmergencyNotificationHelper.CHANNEL_ALERTS -> strings.emergencyChannelName
            EmergencyNotificationHelper.CHANNEL_SERVICE -> strings.serviceChannelName
            EmergencyNotificationHelper.CHANNEL_GENERAL -> strings.generalChannelName
            else -> strings.generalChannelName
        }
    }

    fun channelDescription(context: Context, channelId: String): String {
        val strings = strings(context)
        return when (channelId) {
            EmergencyNotificationHelper.CHANNEL_ALERTS -> strings.emergencyChannelDescription
            EmergencyNotificationHelper.CHANNEL_SERVICE -> strings.serviceChannelDescription
            EmergencyNotificationHelper.CHANNEL_GENERAL -> strings.generalChannelDescription
            else -> strings.generalChannelDescription
        }
    }

    fun graceStarted(
        context: Context,
        sessionId: String,
        restoredAfterBoot: Boolean = false,
    ): NotificationCopy {
        val strings = strings(context)
        return when (CheckInScheduler.normalizeSession(sessionId)) {
            CheckInScheduler.SESSION_SAFE_WALK -> {
                if (restoredAfterBoot) strings.safeWalkBootGraceStarted else strings.safeWalkGraceStarted
            }
            else -> {
                if (restoredAfterBoot) strings.checkInBootGraceStarted else strings.checkInGraceStarted
            }
        }
    }

    fun expired(
        context: Context,
        sessionId: String,
        restoredAfterBoot: Boolean = false,
    ): NotificationCopy {
        val strings = strings(context)
        return when (CheckInScheduler.normalizeSession(sessionId)) {
            CheckInScheduler.SESSION_SAFE_WALK -> {
                if (restoredAfterBoot) strings.safeWalkBootExpired else strings.safeWalkExpired
            }
            else -> {
                if (restoredAfterBoot) strings.checkInBootExpired else strings.checkInExpired
            }
        }
    }

    fun emergencyTriggered(context: Context): NotificationCopy = strings(context).emergencyTriggered

    /**
     * F1 fail-safe copy: the native backup call could not be dispatched
     * (ACTION_CALL and ACTION_DIAL both failed). The body embeds the primary
     * number so the user can dial manually straight from the lock screen.
     */
    fun dispatchFailed(context: Context, number: String): NotificationCopy {
        val template = strings(context).dispatchFailed
        return NotificationCopy(
            title = template.title,
            body = template.body.replace("{number}", number.trim()),
        )
    }

    fun serviceActive(context: Context): NotificationCopy = strings(context).serviceActive

    private fun strings(context: Context): Strings {
        return when (resolveLanguage(context)) {
            Language.TR -> trStrings
            Language.EN -> enStrings
        }
    }

    private fun resolveLanguage(context: Context): Language {
        // Audit F8: the product is TR-locked (startLocale tr_TR; non-TR
        // persisted locales are wiped at startup), so the lock-screen copy
        // defaults to Turkish instead of following the system locale. If an
        // EN locale unlock ever ships, revisit this default together with
        // main.dart's locale wipe.
        return languageFromPersistedLocale(context) ?: Language.TR
    }

    private fun languageFromPersistedLocale(context: Context): Language? {
        val preferenceFiles = listOf(
            "FlutterSharedPreferences",
            "${context.packageName}_preferences",
        )
        val keys = listOf(
            "flutter.locale",
            "locale",
            "flutter.app_locale",
            "app_locale",
            "flutter.languageCode",
            "languageCode",
        )

        for (file in preferenceFiles) {
            val prefs = context.getSharedPreferences(file, Context.MODE_PRIVATE)
            for (key in keys) {
                val language = languageFromRaw(prefs.getString(key, null))
                if (language != null) return language
            }
        }
        return null
    }

    private fun languageFromRaw(raw: String?): Language? {
        val normalized = raw
            ?.trim()
            ?.lowercase(Locale.US)
            ?.replace("-", "_")
            ?: return null

        return when {
            normalized == "tr" || normalized.startsWith("tr_") -> Language.TR
            normalized == "en" || normalized.startsWith("en_") -> Language.EN
            else -> null
        }
    }

    private data class Strings(
        val emergencyChannelName: String,
        val emergencyChannelDescription: String,
        val serviceChannelName: String,
        val serviceChannelDescription: String,
        val generalChannelName: String,
        val generalChannelDescription: String,
        val checkInGraceStarted: NotificationCopy,
        val checkInExpired: NotificationCopy,
        val safeWalkGraceStarted: NotificationCopy,
        val safeWalkExpired: NotificationCopy,
        val checkInBootGraceStarted: NotificationCopy,
        val checkInBootExpired: NotificationCopy,
        val safeWalkBootGraceStarted: NotificationCopy,
        val safeWalkBootExpired: NotificationCopy,
        val emergencyTriggered: NotificationCopy,
        val serviceActive: NotificationCopy,
        val dispatchFailed: NotificationCopy,
    )

    private val enStrings = Strings(
        emergencyChannelName = "Emergency Alerts",
        emergencyChannelDescription = "Critical safety and check-in notifications",
        serviceChannelName = "Service Status",
        serviceChannelDescription = "Background safety service status",
        generalChannelName = "General Notifications",
        generalChannelDescription = "General app notifications",
        checkInGraceStarted = NotificationCopy(
            title = "Check-in expired",
            body = "Please confirm that you are safe.",
        ),
        checkInExpired = NotificationCopy(
            title = "Check-in emergency",
            body = "Your check-in timer ended.",
        ),
        safeWalkGraceStarted = NotificationCopy(
            title = "Safe Walk timed out",
            body = "Please confirm that you are safe.",
        ),
        safeWalkExpired = NotificationCopy(
            title = "Safe Walk emergency",
            body = "Your Safe Walk timer ended.",
        ),
        checkInBootGraceStarted = NotificationCopy(
            title = "Check-in restored after restart",
            body = "Your check-in timer expired. Please confirm that you are safe.",
        ),
        checkInBootExpired = NotificationCopy(
            title = "Check-in emergency after restart",
            body = "Your check-in timer ended while the device was restarting.",
        ),
        safeWalkBootGraceStarted = NotificationCopy(
            title = "Safe Walk restored after restart",
            body = "Your Safe Walk timer expired. Please confirm that you are safe.",
        ),
        safeWalkBootExpired = NotificationCopy(
            title = "Safe Walk emergency after restart",
            body = "Your Safe Walk timer ended while the device was restarting.",
        ),
        emergencyTriggered = NotificationCopy(
            title = "Emergency triggered",
            body = "The emergency call flow is starting.",
        ),
        serviceActive = NotificationCopy(
            title = "KoruBeni active",
            body = "Safety flow is being monitored in the background.",
        ),
        dispatchFailed = NotificationCopy(
            title = "Emergency call could not be started",
            body = "Automatic dialing failed. Please call manually: {number}",
        ),
    )

    private val trStrings = Strings(
        emergencyChannelName = "Acil Bildirimler",
        emergencyChannelDescription = "Kritik güvenlik ve check-in bildirimleri",
        serviceChannelName = "Servis Durumu",
        serviceChannelDescription = "Arka plan güvenlik servis durumu",
        generalChannelName = "Genel Bildirimler",
        generalChannelDescription = "Genel uygulama bildirimleri",
        checkInGraceStarted = NotificationCopy(
            title = "Check-in süresi doldu",
            body = "Lütfen güvende olduğunuzu onaylayın.",
        ),
        checkInExpired = NotificationCopy(
            title = "Check-in acil durumu",
            body = "Check-in süresi doldu.",
        ),
        safeWalkGraceStarted = NotificationCopy(
            title = "Güvenli yürüyüş süresi doldu",
            body = "Lütfen güvende olduğunuzu onaylayın.",
        ),
        safeWalkExpired = NotificationCopy(
            title = "Güvenli yürüyüş acil durumu",
            body = "Güvenli yürüyüş zamanlayıcısı sona erdi.",
        ),
        checkInBootGraceStarted = NotificationCopy(
            title = "Check-in yeniden başlatma sonrası geri yüklendi",
            body = "Check-in süresi doldu. Lütfen güvende olduğunuzu onaylayın.",
        ),
        checkInBootExpired = NotificationCopy(
            title = "Yeniden başlatma sonrası check-in acil durumu",
            body = "Cihaz yeniden başlatılırken check-in zamanlayıcısı sona erdi.",
        ),
        safeWalkBootGraceStarted = NotificationCopy(
            title = "Güvenli yürüyüş yeniden başlatma sonrası geri yüklendi",
            body = "Güvenli yürüyüş süresi doldu. Lütfen güvende olduğunuzu onaylayın.",
        ),
        safeWalkBootExpired = NotificationCopy(
            title = "Yeniden başlatma sonrası güvenli yürüyüş acil durumu",
            body = "Cihaz yeniden başlatılırken güvenli yürüyüş zamanlayıcısı sona erdi.",
        ),
        emergencyTriggered = NotificationCopy(
            title = "Acil durum tetiklendi",
            body = "Acil arama akışı başlatılıyor.",
        ),
        serviceActive = NotificationCopy(
            title = "KoruBeni aktif",
            body = "Güvenlik akışı arka planda izleniyor.",
        ),
        dispatchFailed = NotificationCopy(
            title = "Acil arama başlatılamadı",
            body = "Otomatik arama yapılamadı. Lütfen elle arayın: {number}",
        ),
    )
}
