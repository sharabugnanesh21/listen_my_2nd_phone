package com.perkypet.listen_my_phone

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Open a one-way pipe from native Android -> Flutter (an EventChannel is the
        // "streaming" version of a MethodChannel). When Flutter starts listening we
        // keep the sink so SmsReceiver can push each incoming SMS through it.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    companion object {
        const val SMS_CHANNEL = "com.perkypet.listen_my_phone/sms"

        // Shared with SmsReceiver. Non-null only while Flutter is actively listening
        // (i.e. while the "Listen" switch is ON and the app process is alive).
        var eventSink: EventChannel.EventSink? = null
    }
}
