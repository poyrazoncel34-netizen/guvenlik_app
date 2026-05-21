package com.poyrazoncel.korubeni

import android.view.KeyEvent
import io.flutter.plugin.common.EventChannel

/**
 * Ses tuşlarına art arda basılmasını tespit eder.
 *
 * Kullanıcı, belirlenen süre içinde belirlenen sayıda ses tuşuna basarsa
 * (varsayılan: 2 saniye içinde 3 basış), Flutter tarafına "volume_panic"
 * event'i gönderilir.
 *
 * Sadece uygulama ön plandayken (Activity visible) çalışır.
 */
class VolumeButtonDetector : EventChannel.StreamHandler {

    companion object {
        const val CHANNEL = "com.poyrazoncel.korubeni/volume_button"

        /** Tetikleme için gereken basış sayısı */
        private const val REQUIRED_PRESS_COUNT = 3

        /** Basışların sayılacağı zaman penceresi (ms) */
        private const val TIME_WINDOW_MS = 2000L

        /** Tetikleme sonrası bekleme süresi (ms) - çift tetiklemeyi önler */
        private const val COOLDOWN_MS = 5000L
        
        /** Maximum timestamp list size - prevent memory leak */
        private const val MAX_TIMESTAMP_SIZE = 10
    }

    private var eventSink: EventChannel.EventSink? = null
    private var isEnabled = false

    // Ses tuşu basılma zamanlarını tutan liste
    private val pressTimestamps = mutableListOf<Long>()
    private var lastTriggerTime = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /**
     * Özelliği etkinleştir/devre dışı bırak. Flutter tarafından çağrılır.
     */
    fun setEnabled(enabled: Boolean) {
        isEnabled = enabled
        if (!enabled) {
            pressTimestamps.clear()
        }
    }

    /**
     * MainActivity onKeyDown/onKeyUp callback'lerinden çağrılır.
     * true dönerse event consume edilmiştir (ses değişikliği engellenir).
     * false dönerse event normal şekilde işlenir.
     */
    fun onKeyEvent(event: KeyEvent): Boolean {
        if (!isEnabled) return false
        if (eventSink == null) return false

        // Sadece VOLUME_DOWN veya VOLUME_UP tuşlarına tepki ver
        if (event.keyCode != KeyEvent.KEYCODE_VOLUME_DOWN &&
            event.keyCode != KeyEvent.KEYCODE_VOLUME_UP) {
            return false
        }

        // Sadece KEY_DOWN event'lerini say (KEY_UP'ı yoksay)
        if (event.action != KeyEvent.ACTION_DOWN) {
            // KEY_UP event'ini de consume et ki ses seviyesi değişmesin
            return true
        }

        val now = System.currentTimeMillis()

        // Cooldown kontrolü - son tetiklemeden sonra bekleme süresi
        if (now - lastTriggerTime < COOLDOWN_MS) {
            return true // Event'i yut ama tetikleme yapma
        }

        // Zaman penceresi dışındaki eski basışları temizle
        pressTimestamps.removeAll { now - it > TIME_WINDOW_MS }
        
        // Memory leak prevention - limit list size
        if (pressTimestamps.size >= MAX_TIMESTAMP_SIZE) {
            pressTimestamps.removeAt(0)
        }

        // Bu basışı kaydet
        pressTimestamps.add(now)

        // Gereken sayıya ulaşıldı mı kontrol et
        if (pressTimestamps.size >= REQUIRED_PRESS_COUNT) {
            pressTimestamps.clear()
            lastTriggerTime = now

            // Flutter'a tetikleme event'i gönder
            eventSink?.success("volume_panic")
            return true
        }

        // Event'i consume et (ses seviyesi değişmesin)
        return true
    }
}
