package com.poyrazoncel.korubeni.emergency

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject

object EmergencyEventBus {
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    fun attach(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun detach() {
        eventSink = null
    }

    fun emit(payload: Map<String, Any?>) {
        val sink = eventSink ?: return
        mainHandler.post {
            try {
                sink.success(HashMap(payload))
            } catch (_: Exception) {
                // Sink may have been detached between capture and post
            }
        }
    }

    fun emitOrPersist(context: Context, payload: Map<String, Any?>) {
        val sink = eventSink
        if (sink != null) {
            mainHandler.post {
                try {
                    sink.success(HashMap(payload))
                } catch (_: Exception) {
                    persist(context, payload)
                }
            }
            return
        }
        persist(context, payload)
    }

    fun persist(context: Context, payload: Map<String, Any?>) {
        EmergencyPrefs.prefs(context).edit()
            .putString(EmergencyPrefs.KEY_PENDING_TRIGGER, JSONObject(payload).toString())
            .commit()
    }

    fun consumePendingTrigger(context: Context): Map<String, Any?>? {
        val prefs = EmergencyPrefs.prefs(context)
        val raw = prefs.getString(EmergencyPrefs.KEY_PENDING_TRIGGER, null) ?: return null
        prefs.edit().remove(EmergencyPrefs.KEY_PENDING_TRIGGER).commit()
        return try {
            val json = JSONObject(raw)
            val data = hashMapOf<String, Any?>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                data[key] = json.get(key)
            }
            data
        } catch (_: Exception) {
            null
        }
    }
}
