package com.perkypet.listen_my_phone

import android.app.Notification
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import org.json.JSONObject
import java.util.UUID

/**
 * Captures notifications and (if "Forward" is on) sends them to Firestore so the
 * user's OTHER phones can show them. Runs in the background via notification access.
 */
class NotificationForwarderService : NotificationListenerService() {

    companion object {
        private const val TAG = "NotifForwarder"
        private const val DEDUP_WINDOW_MS = 8000L
        private val recentSignatures = HashMap<String, Long>()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn?.notification ?: return
        val pkg = sbn.packageName ?: return
        if (pkg == packageName) return

        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        if (title.isBlank() && text.isBlank()) return

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
        val id = UUID.randomUUID().toString()
        Log.d(TAG, "capture $appName ($pkg): $title / $text")

        // 1) Save to this phone's local feed.
        AppStore.addEvent(
            this,
            JSONObject()
                .put("id", id)
                .put("package", pkg)
                .put("appName", appName)
                .put("title", title)
                .put("text", text)
                .put("timestamp", now),
        )

        // 2) Forward to the cloud so my OTHER phones can show it.
        if (AppStore.getForward(this)) {
            forwardToCloud(pkg, appName, title, text, now, id)
        }

        // 3) If this phone's UI is open, refresh its live feed.
        val payload = mapOf(
            "id" to id,
            "package" to pkg,
            "appName" to appName,
            "title" to title,
            "text" to text,
            "timestamp" to now,
        )
        Handler(Looper.getMainLooper()).post {
            MainActivity.notifEventSink?.success(payload)
        }
    }

    private fun forwardToCloud(
        pkg: String,
        appName: String,
        title: String,
        text: String,
        timestamp: Long,
        id: String,
    ) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val data = hashMapOf(
            "id" to id,
            "package" to pkg,
            "appName" to appName,
            "title" to title,
            "text" to text,
            "timestamp" to timestamp,
            "sourceDeviceId" to AppStore.getDeviceId(this),
            "sourceDeviceName" to android.os.Build.MODEL,
        )
        FirebaseFirestore.getInstance()
            .collection("users").document(uid)
            .collection("events").add(data)
            .addOnFailureListener { e -> Log.w(TAG, "forward failed", e) }
    }

    private fun friendlyAppName(pkg: String): String = try {
        packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(pkg, 0),
        ).toString()
    } catch (e: Exception) {
        pkg
    }
}
