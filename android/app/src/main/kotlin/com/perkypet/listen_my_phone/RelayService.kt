package com.perkypet.listen_my_phone

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import org.json.JSONObject

/**
 * Foreground service that keeps a Firestore listener alive so this phone receives
 * notifications forwarded from the other phone EVEN WHEN THE APP IS CLOSED.
 */
class RelayService : Service() {

    companion object {
        private const val TAG = "RelayService"
    }

    private var registration: ListenerRegistration? = null
    private var firstSnapshot = true

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = AppNotifications.buildForegroundNotification(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                AppNotifications.FG_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(AppNotifications.FG_NOTIFICATION_ID, notification)
        }
        startListening()
        return START_STICKY
    }

    private fun startListening() {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            Log.w(TAG, "not signed in — stopping relay service")
            stopSelf()
            return
        }

        val deviceId = AppStore.getDeviceId(this)
        firstSnapshot = true
        registration?.remove()
        registration = FirebaseFirestore.getInstance()
            .collection("users").document(uid).collection("events")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(50)
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) {
                    Log.w(TAG, "listen error", error)
                    return@addSnapshotListener
                }
                for (change in snapshot.documentChanges) {
                    val data = change.document.data
                    val id = data["id"] as? String ?: change.document.id
                    when (change.type) {
                        DocumentChange.Type.REMOVED -> AppStore.removeEvent(this, id)
                        DocumentChange.Type.ADDED -> {
                            if (data["sourceDeviceId"] == deviceId) continue // our own
                            val appName = data["appName"] as? String ?: ""
                            val title = data["title"] as? String ?: ""
                            val text = data["text"] as? String ?: ""
                            val ts = (data["timestamp"] as? Number)?.toLong()
                                ?: System.currentTimeMillis()

                            AppStore.addEvent(
                                this,
                                JSONObject()
                                    .put("id", id)
                                    .put("package", data["package"] as? String ?: "")
                                    .put("appName", appName)
                                    .put("title", title)
                                    .put("text", text)
                                    .put("timestamp", ts),
                            )

                            // Don't pop the whole history on first load — only new ones.
                            if (!firstSnapshot) {
                                val notifTitle =
                                    if (title.isBlank()) appName else "$appName · $title"
                                AppNotifications.show(
                                    this,
                                    notifTitle,
                                    text.ifBlank { title },
                                )
                            }
                        }
                        else -> {}
                    }
                }
                firstSnapshot = false

                // Nudge the Flutter UI to refresh its feed, if the app is open.
                Handler(Looper.getMainLooper()).post {
                    MainActivity.notifEventSink?.success(mapOf("relay" to true))
                }
            }
    }

    override fun onDestroy() {
        registration?.remove()
        registration = null
        super.onDestroy()
    }
}
