package com.poyrazoncel.korubeni

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val smsPlugin = SmsPlugin(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SmsPlugin.CHANNEL
        ).setMethodCallHandler(smsPlugin)
    }
}
