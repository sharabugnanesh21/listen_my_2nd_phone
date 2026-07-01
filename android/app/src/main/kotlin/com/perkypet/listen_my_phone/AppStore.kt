package com.perkypet.listen_my_phone

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Tiny SharedPreferences-backed store shared by BOTH the Activity and the
 * background listener service (same process, so the cache is shared).
 *
 * This is what lets state survive the app being closed: the service writes here
 * even when no Flutter UI is running, and Flutter reads it on next launch.
 */
object AppStore {
    private const val PREFS = "listen_state"
    private const val KEY_ENABLED = "enabled_packages"
    private const val KEY_CAPTURE_ALL = "capture_all"
    private const val KEY_EVENTS = "events"
    private const val MAX_EVENTS = 200

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun getEnabled(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_ENABLED, emptySet())?.toSet() ?: emptySet()

    fun setEnabled(context: Context, packages: List<String>) {
        prefs(context).edit().putStringSet(KEY_ENABLED, packages.toHashSet()).apply()
    }

    fun getCaptureAll(context: Context): Boolean =
        prefs(context).getBoolean(KEY_CAPTURE_ALL, false)

    fun setCaptureAll(context: Context, value: Boolean) {
        prefs(context).edit().putBoolean(KEY_CAPTURE_ALL, value).apply()
    }

    fun getEventsJson(context: Context): String =
        prefs(context).getString(KEY_EVENTS, "[]") ?: "[]"

    /** Prepends the newest event and keeps only the most recent [MAX_EVENTS]. */
    fun addEvent(context: Context, event: JSONObject) {
        val existing = JSONArray(getEventsJson(context))
        val updated = JSONArray()
        updated.put(event)
        val keep = minOf(existing.length(), MAX_EVENTS - 1)
        for (i in 0 until keep) updated.put(existing.get(i))
        prefs(context).edit().putString(KEY_EVENTS, updated.toString()).apply()
    }

    /** Removes a single event by its unique id (used by swipe-to-delete). */
    fun removeEvent(context: Context, id: String) {
        val existing = JSONArray(getEventsJson(context))
        val updated = JSONArray()
        for (i in 0 until existing.length()) {
            val obj = existing.optJSONObject(i) ?: continue
            if (obj.optString("id") != id) updated.put(obj)
        }
        prefs(context).edit().putString(KEY_EVENTS, updated.toString()).apply()
    }

    fun clearEvents(context: Context) {
        prefs(context).edit().remove(KEY_EVENTS).apply()
    }
}
