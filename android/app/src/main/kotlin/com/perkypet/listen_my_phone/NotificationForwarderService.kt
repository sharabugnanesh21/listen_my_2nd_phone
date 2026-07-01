package com.perkypet.listen_my_phone

import android.app.Notification
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONObject
import java.util.UUID

/**
 * Kept alive by the system once "Notification access" is granted — so it runs even
 * when the app UI is closed. It filters, saves, and notifies entirely natively, then
 * (if the UI is open) forwards the event to Flutter for a live update.
 */
class NotificationForwarderService : NotificationListenerService() {

    companion object {
        private const val TAG = "NotifForwarder"

        // De-dupe: apps re-post/update the same notification repeatedly. We skip a
        // notification whose (package|title|text) we already saw within this window.
        private const val DEDUP_WINDOW_MS = 8000L
        private val recentSignatures = HashMap<String, Long>()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn?.notification ?: return
        val pkg = sbn.packageName ?: return

        // Ignore our own notifications so we don't loop forever.
        if (pkg == packageName) return

        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        if (title.isBlank() && text.isBlank()) return

        // Only handle the apps the user chose (or everything, in discovery mode).
        val captureAll = AppStore.getCaptureAll(this)
        val enabled = AppStore.getEnabled(this)
        if (!captureAll && !enabled.contains(pkg)) return

        // Skip repeats: same app + title + text seen within the dedup window.
        val now = System.currentTimeMillis()
        val signature = "$pkg|$title|$text"
        val last = recentSignatures[signature]
        if (last != null && now - last < DEDUP_WINDOW_MS) {
            Log.d(TAG, "skip duplicate: $signature")
            return
        }
        recentSignatures[signature] = now
        if (recentSignatures.size > 200) {
            recentSignatures.entries.removeAll { now - it.value > DEDUP_WINDOW_MS }
        }

        val appName = friendlyAppName(pkg)
        val timestamp = now
        val id = UUID.randomUUID().toString()
        Log.d(TAG, "capture $appName ($pkg): $title / $text")

        // 1) Persist — so the list survives even if the app UI was never opened.
        AppStore.addEvent(
            this,
            JSONObject()
                .put("id", id)
                .put("package", pkg)
                .put("appName", appName)
                .put("title", title)
                .put("text", text)
                .put("timestamp", timestamp),
        )

        // 2) Post a notification from native code — works even when the app is killed.
        AppNotifications.show(
            this,
            if (title.isBlank()) appName else "$appName · $title",
            text.ifBlank { title },
            appIconBitmap(pkg),
        )

        // 3) If the Flutter UI happens to be open, update it live.
        val payload = mapOf(
            "id" to id,
            "package" to pkg,
            "appName" to appName,
            "title" to title,
            "text" to text,
            "timestamp" to timestamp,
        )
        Handler(Looper.getMainLooper()).post {
            MainActivity.notifEventSink?.success(payload)
        }
    }

    private fun friendlyAppName(pkg: String): String = try {
        packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(pkg, 0),
        ).toString()
    } catch (e: Exception) {
        pkg
    }

    private fun appIconBitmap(pkg: String): Bitmap? = try {
        val drawable = packageManager.getApplicationIcon(pkg)
        val size = 128
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        bitmap
    } catch (e: Exception) {
        null
    }
}
