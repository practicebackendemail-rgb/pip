package com.personal.assistant.personal_assistant

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Reads incoming notifications into a small local inbox so Pip can answer
 * "what did I miss?". Runs whenever notification access is granted, even if
 * Pip is closed. Stores only app, title, a trimmed text and time; skips Pip's
 * own, ongoing (music, navigation), group summaries, and apps the user muted.
 *
 * The inbox lives in Flutter's SharedPreferences file under
 * `flutter.pip_notification_inbox`, so Dart reads it with shared_preferences.
 */
class PipNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            if (shouldSkip(sbn)) return
            val extras = sbn.notification.extras
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
            val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()?.trim().orEmpty()
            if (title.isEmpty() && text.isEmpty()) return

            val entry = JSONObject()
                .put("key", sbn.key)
                .put("package", sbn.packageName)
                .put("app", appLabel(sbn.packageName))
                .put("title", title.take(MAX_TITLE))
                .put("text", text.take(MAX_TEXT))
                .put("category", sbn.notification.category ?: "")
                .put("posted", sbn.postTime)
            append(applicationContext, entry)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun shouldSkip(sbn: StatusBarNotification): Boolean {
        val n = sbn.notification
        if (sbn.packageName == packageName) return true
        if (sbn.isOngoing || (n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return true
        return mutedApps(applicationContext).contains(sbn.packageName)
    }

    private fun appLabel(pkg: String): String = try {
        val info = packageManager.getApplicationInfo(pkg, 0)
        packageManager.getApplicationLabel(info).toString()
    } catch (e: Exception) {
        pkg
    }

    companion object {
        private const val PREFS = "FlutterSharedPreferences"
        const val INBOX_KEY = "flutter.pip_notification_inbox"
        const val MUTED_KEY = "flutter.pip_notification_muted"
        private const val MAX_ENTRIES = 200
        private const val MAX_TITLE = 120
        private const val MAX_TEXT = 300

        @Synchronized
        fun append(context: Context, entry: JSONObject) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val existing = try {
                JSONArray(prefs.getString(INBOX_KEY, "[]"))
            } catch (e: Exception) {
                JSONArray()
            }
            // Replace an updated notification (same key) instead of duplicating it.
            val kept = JSONArray()
            for (i in 0 until existing.length()) {
                val item = existing.optJSONObject(i) ?: continue
                if (item.optString("key") != entry.optString("key")) kept.put(item)
            }
            kept.put(entry)
            val start = maxOf(0, kept.length() - MAX_ENTRIES)
            val trimmed = JSONArray()
            for (i in start until kept.length()) trimmed.put(kept.get(i))
            prefs.edit().putString(INBOX_KEY, trimmed.toString()).apply()
        }

        /** Muted package names, written by Dart as a JSON list string. */
        fun mutedApps(context: Context): Set<String> {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(MUTED_KEY, "[]")
            return try {
                val arr = JSONArray(raw)
                (0 until arr.length()).map { arr.getString(it) }.toSet()
            } catch (e: Exception) {
                emptySet()
            }
        }
    }
}
