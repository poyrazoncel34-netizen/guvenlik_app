package com.poyrazoncel.korubeni.quickaccess

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick Settings tile that opens the app with a pending panic request.
 *
 * This is the surface reachable without unlocking to the launcher: the shade is
 * available over the lock screen. `isSecure` tiles still require an unlock
 * before the Activity shows, which is correct under the duress model -- the app
 * is PIN-gated and must not become readable from a locked device.
 *
 * Like the widget, the tile only submits intent. It never arms, never dials.
 */
class PanicTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        qsTile?.let { tile ->
            tile.state = Tile.STATE_INACTIVE
            tile.updateTile()
        }
    }

    // The PendingIntent overload of startActivityAndCollapse arrived in API 34.
    // minSdk is 29, so the Intent overload is not a leftover -- it is the only
    // way to open the app from a tile on API 29-33. Scoped to this method so the
    // deprecation stays visible everywhere else.
    @SuppressLint("StartActivityAndCollapseDeprecated")
    override fun onClick() {
        super.onClick()
        val context = applicationContext
        PanicRequestStore.submit(context, PanicRequestStore.SOURCE_TILE)
        val intent = PanicLaunch.intent(context, PanicRequestStore.SOURCE_TILE)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // API 34 removed the Intent overload; a PendingIntent is required.
            startActivityAndCollapse(
                PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
