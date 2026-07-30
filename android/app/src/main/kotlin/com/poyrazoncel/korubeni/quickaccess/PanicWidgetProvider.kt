package com.poyrazoncel.korubeni.quickaccess

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.poyrazoncel.korubeni.R

/**
 * Home-screen widget that opens the app with a pending panic request.
 *
 * The widget is a shortcut, not a second dispatch path: it holds no contact, no
 * deadline and no entitlement decision. Everything that decides whether a
 * session may start stays in the Flutter arm path.
 *
 * Note on scope: Android has no third-party lock-screen widgets (removed in
 * API 21). The lock-screen-reachable surface is the Quick Settings tile.
 */
class PanicWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(widgetId, buildViews(context, widgetId))
        }
    }

    private fun buildViews(context: Context, widgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.panic_widget)
        views.setOnClickPendingIntent(R.id.panic_widget_root, pendingIntent(context, widgetId))
        return views
    }

    private fun pendingIntent(context: Context, widgetId: Int): PendingIntent =
        PendingIntent.getActivity(
            context,
            widgetId,
            PanicLaunch.intent(context, PanicRequestStore.SOURCE_WIDGET),
            // IMMUTABLE: nothing outside this app may rewrite the extras.
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}
