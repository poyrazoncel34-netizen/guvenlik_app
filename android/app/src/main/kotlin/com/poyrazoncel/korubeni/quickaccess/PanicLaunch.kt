package com.poyrazoncel.korubeni.quickaccess

import android.content.Context
import android.content.Intent
import com.poyrazoncel.korubeni.MainActivity

/**
 * Builds the launch Intent shared by the widget and the Quick Settings tile.
 *
 * Both surfaces launch the Activity directly rather than storing the request
 * from a BroadcastReceiver: background activity starts from a receiver are
 * blocked on Android 10+, so a receiver-mediated tap would work on the bench
 * and fail on a real device. MainActivity records the request when it sees the
 * extra.
 */
object PanicLaunch {
    const val EXTRA_PANIC_SOURCE = "com.poyrazoncel.korubeni.extra.PANIC_SOURCE"

    fun intent(context: Context, source: String): Intent =
        Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            // singleTop + CLEAR_TOP: reuse the existing task instead of stacking
            // a second instance over a countdown that may already be running.
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
            putExtra(EXTRA_PANIC_SOURCE, source)
        }
}
