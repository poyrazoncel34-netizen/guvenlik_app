package com.poyrazoncel.korubeni.quickaccess

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.poyrazoncel.korubeni.MainActivity

/**
 * Not exported, and that is the entire point.
 *
 * The widget and the Quick Settings tile used to launch MainActivity directly
 * with a PANIC_SOURCE extra. MainActivity is the exported launcher component,
 * so any installed app could send the same intent and start a real, PIN-gated
 * countdown the user never asked for. The attacker could not choose the number,
 * but could force an unwanted emergency call.
 *
 * A PendingIntent created inside this app can target a non-exported component;
 * a foreign app cannot. So the request is recorded here, and MainActivity is
 * started afterwards with no panic extra at all.
 *
 * The write still happens before the Flutter engine exists, which is what the
 * original ordering protected: the trigger host reads the store once Dart is
 * up, and this activity has already finished by then.
 */
class QuickPanicTrampolineActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val source = intent?.getStringExtra(PanicLaunch.EXTRA_PANIC_SOURCE)
        if (source == PanicRequestStore.SOURCE_WIDGET ||
            source == PanicRequestStore.SOURCE_TILE
        ) {
            try {
                PanicRequestStore.submit(applicationContext, source)
            } catch (_: Exception) {
                android.util.Log.e("QuickPanicTrampoline", "QUICK_PANIC_PERSIST_FAILED")
            }
        }
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
        )
        finish()
    }
}
