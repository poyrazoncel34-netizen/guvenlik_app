package com.poyrazoncel.korubeni

import android.os.SystemClock
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
 *
 * Tüm çağrılar (tuş olayları, setEnabled, onListen/onCancel) ana iş
 * parçacığından gelir; durum bu yüzden senkronize edilmez.
 */
class VolumeButtonDetector(
    /**
     * Monotonik saat (ms). Duvar saati ileri/geri alınsa da 2 sn pencere ve
     * cooldown bozulmaz. Testler sahte saat verir.
     */
    private val elapsedRealtimeMs: () -> Long = { SystemClock.elapsedRealtime() },
) : EventChannel.StreamHandler {

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
    // null = henüz tetiklenmedi. 0L olamaz: elapsedRealtime açılışta 0'dan
    // başlar ve ilk deseni hayali bir cooldown engellerdi.
    private var lastTriggerTime: Long? = null

    // KEY_DOWN'u yutulan, KEY_UP'ı henüz gelmemiş tuşlar. UP yalnızca eşi
    // yutulduysa yutulur.
    private val consumedKeyCodes = mutableSetOf<Int>()

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
     *
     * Yalnızca tetiklemeyi tamamlayan basış (DOWN'u, otomatik tekrarları ve
     * UP'ı) consume edilir; diğer bütün basışlarda ses normal değişir.
     */
    fun onKeyEvent(event: KeyEvent): Boolean {
        // Sadece VOLUME_DOWN veya VOLUME_UP tuşlarına tepki ver
        if (event.keyCode != KeyEvent.KEYCODE_VOLUME_DOWN &&
            event.keyCode != KeyEvent.KEYCODE_VOLUME_UP) {
            return false
        }

        // KEY_UP, eşi KEY_DOWN'un kararını izler. isEnabled/eventSink'ten ÖNCE:
        // tetiklemeden hemen sonra dinleyici düşebilir (inactive -> onCancel) ve
        // yutulmuş bir DOWN'un UP'ı sisteme tek başına ulaşmamalı.
        if (event.action != KeyEvent.ACTION_DOWN) {
            return consumedKeyCodes.remove(event.keyCode)
        }

        // Basılı tutulan tuşun otomatik tekrarları yeni basış değildir: sayılmaz,
        // ilk DOWN'un kararını izler. Yoksa sesi ayarlamak için tuşu yarım saniye
        // basılı tutmak paniği tetiklerdi.
        if (event.repeatCount > 0) {
            return event.keyCode in consumedKeyCodes
        }

        // Yeni basış: UP'ı kaybolmuş eski bir karar bu basışı yutmasın.
        consumedKeyCodes.remove(event.keyCode)

        if (!isEnabled) return false
        if (eventSink == null) return false

        val now = elapsedRealtimeMs()

        // Cooldown kontrolü - son tetiklemeden sonra bekleme süresi.
        // Basış sayılmaz ama yutulmaz da: ses normal değişir.
        val lastTrigger = lastTriggerTime
        if (lastTrigger != null && now - lastTrigger < COOLDOWN_MS) {
            return false
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
            // Yalnızca tetikleyen basış yutulur; eşi KEY_UP da yutulacak.
            consumedKeyCodes.add(event.keyCode)

            // Flutter'a tetikleme event'i gönder
            eventSink?.success("volume_panic")
            return true
        }

        // Tetiklemeyen basış sisteme bırakılır: ses normal değişir.
        return false
    }
}
