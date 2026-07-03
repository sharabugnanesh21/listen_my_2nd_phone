package com.perkypet.listen_my_phone

import android.content.ComponentName
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Make sure the notification channel exists so its sound is editable in Settings.
        AppNotifications.ensureChannel(this)

        // Stream of captured notifications: native service -> Flutter (live updates).
        EventChannel(messenger, NOTIF_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    notifEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    notifEventSink = null
                }
            },
        )

        // Request/response control channel.
        MethodChannel(messenger, CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessGranted" -> result.success(isNotificationAccessGranted())
                "openAccessSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                "openSoundSettings" -> {
                    openSoundSettings()
                    result.success(null)
                }
                "getInstalledApps" -> getInstalledApps(result)
                "getAppIcon" -> result.success(
                    (call.arguments as? String)?.let { appIconBase64(it) },
                )
                "getEnabledPackages" -> result.success(AppStore.getEnabled(this).toList())
                "setEnabledPackages" -> {
                    val packages = (call.arguments as? List<*>)?.mapNotNull { it as? String }
                        ?: emptyList()
                    AppStore.setEnabled(this, packages)
                    result.success(null)
                }
                "getCaptureAll" -> result.success(AppStore.getCaptureAll(this))
                "setCaptureAll" -> {
                    AppStore.setCaptureAll(this, call.arguments as? Boolean ?: false)
                    result.success(null)
                }
                "getEvents" -> result.success(AppStore.getEventsJson(this))
                "removeEvent" -> {
                    (call.arguments as? String)?.let { AppStore.removeEvent(this, it) }
                    result.success(null)
                }
                "clearEvents" -> {
                    AppStore.clearEvents(this)
                    result.success(null)
                }
                "getForward" -> result.success(AppStore.getForward(this))
                "setForward" -> {
                    AppStore.setForward(this, call.arguments as? Boolean ?: false)
                    result.success(null)
                }
                "getReceive" -> result.success(AppStore.getReceive(this))
                "setReceive" -> {
                    AppStore.setReceive(this, call.arguments as? Boolean ?: false)
                    result.success(null)
                }
                "getDeviceId" -> result.success(AppStore.getDeviceId(this))
                "addReceivedEvent" -> {
                    addReceivedEvent(call.arguments)
                    result.success(null)
                }
                "startRelayService" -> {
                    val svc = Intent(this, RelayService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(svc)
                    } else {
                        startService(svc)
                    }
                    result.success(null)
                }
                "stopRelayService" -> {
                    stopService(Intent(this, RelayService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Opens the system screen where the user can change OUR app's notification sound. */
    private fun openSoundSettings() {
        AppNotifications.ensureChannel(this)
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, AppNotifications.CHANNEL_ID)
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            )
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    /** Stores an event forwarded from another phone, and optionally notifies. */
    @Suppress("UNCHECKED_CAST")
    private fun addReceivedEvent(args: Any?) {
        val map = args as? Map<String, Any?> ?: return
        val appName = map["appName"] as? String ?: ""
        val title = map["title"] as? String ?: ""
        val text = map["text"] as? String ?: ""
        val notify = map["notify"] as? Boolean ?: false

        AppStore.addEvent(
            this,
            JSONObject()
                .put("id", map["id"] as? String ?: UUID.randomUUID().toString())
                .put("package", map["package"] as? String ?: "")
                .put("appName", appName)
                .put("title", title)
                .put("text", text)
                .put("timestamp", (map["timestamp"] as? Number)?.toLong()
                    ?: System.currentTimeMillis()),
        )

        if (notify) {
            val notifTitle = if (title.isBlank()) appName else "$appName · $title"
            AppNotifications.show(this, notifTitle, text.ifBlank { title })
        }
    }

    /** Has the user turned on "Notification access" for us in system settings? */
    private fun isNotificationAccessGranted(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(":").any {
            ComponentName.unflattenFromString(it)?.packageName == packageName
        }
    }

    /** Returns launchable apps as [{package, name, icon(base64 png)}], sorted by name. */
    private fun getInstalledApps(result: MethodChannel.Result) {
        Thread {
            val pm = packageManager
            val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val apps = pm.queryIntentActivities(mainIntent, 0)
                .map { it.activityInfo.applicationInfo }
                .distinctBy { it.packageName }
                .filter { it.packageName != packageName }
                .map { info ->
                    mapOf(
                        "package" to info.packageName,
                        "name" to pm.getApplicationLabel(info).toString(),
                        "icon" to drawableToBase64(pm.getApplicationIcon(info)),
                    )
                }
                .sortedBy { (it["name"] as String).lowercase() }
            runOnUiThread { result.success(apps) }
        }.start()
    }

    private fun appIconBase64(pkg: String): String? = try {
        drawableToBase64(packageManager.getApplicationIcon(pkg))
    } catch (e: Exception) {
        null
    }

    private fun drawableToBase64(drawable: Drawable): String? = try {
        val size = 72
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    } catch (e: Exception) {
        null
    }

    companion object {
        const val NOTIF_CHANNEL = "com.perkypet.listen_my_phone/notifications"
        const val CONTROL_CHANNEL = "com.perkypet.listen_my_phone/control"

        // Non-null only while Flutter is actively listening.
        var notifEventSink: EventChannel.EventSink? = null
    }
}
