package com.poyrazoncel.korubeni.emergency

import io.flutter.plugin.common.EventChannel

class EmergencyEventStreamHandler : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        EmergencyEventBus.attach(events)
    }

    override fun onCancel(arguments: Any?) {
        EmergencyEventBus.detach()
    }
}
