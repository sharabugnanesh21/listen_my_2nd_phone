package com.perkypet.listen_my_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log

/**
 * Fires whenever the phone receives an SMS. Reads the sender + text and pushes it
 * to Flutter through the EventChannel that MainActivity opened.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive fired, action=${intent.action}")

        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return

        // A long SMS arrives as several parts; the sender is the same, so join the bodies.
        val sender = messages[0].displayOriginatingAddress ?: "Unknown"
        val body = buildString {
            for (message in messages) append(message.messageBody)
        }
        Log.d(TAG, "SMS from $sender: $body")

        val payload = mapOf(
            "sender" to sender,
            "body" to body,
            "timestamp" to System.currentTimeMillis(),
        )

        // EventSink must be touched on the main thread. If Flutter isn't listening
        // (app killed, or "Listen" switched off) the sink is null and we drop it.
        Handler(Looper.getMainLooper()).post {
            val sink = MainActivity.eventSink
            if (sink == null) {
                Log.w(TAG, "eventSink is NULL - Flutter isn't listening, dropping message")
            } else {
                Log.d(TAG, "Forwarding SMS to Flutter")
                sink.success(payload)
            }
        }
    }
}
