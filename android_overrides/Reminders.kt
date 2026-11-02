package com.studybuddy.studybuddy

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/** Schedules local reminders with AlarmManager and remembers them so they survive a reboot. */
object Reminders {
    private const val PREFS = "reminders"
    private const val KEY = "list"

    private fun pending(ctx: Context, id: Int, title: String, body: String): PendingIntent {
        val i = Intent(ctx, ReminderReceiver::class.java)
            .putExtra("id", id).putExtra("title", title).putExtra("body", body)
        return PendingIntent.getBroadcast(
            ctx, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun scheduleOne(ctx: Context, id: Int, time: Long, title: String, body: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.set(AlarmManager.RTC_WAKEUP, time, pending(ctx, id, title, body))
    }

    private fun cancelOne(ctx: Context, id: Int) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(ctx, id, "", ""))
    }

    fun replaceAll(ctx: Context, items: List<*>) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val old = JSONArray(prefs.getString(KEY, "[]"))
        for (k in 0 until old.length()) {
            cancelOne(ctx, old.getJSONObject(k).getInt("id"))
        }
        val arr = JSONArray()
        for (item in items) {
            val m = item as? Map<*, *> ?: continue
            val id = (m["id"] as Number).toInt()
            val time = (m["time"] as Number).toLong()
            val title = (m["title"] as? String) ?: "StudyBuddy"
            val body = (m["body"] as? String) ?: ""
            scheduleOne(ctx, id, time, title, body)
            arr.put(JSONObject().put("id", id).put("time", time).put("title", title).put("body", body))
        }
        prefs.edit().putString(KEY, arr.toString()).apply()
    }

    /** Called after the phone restarts. */
    fun restore(ctx: Context) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString(KEY, "[]"))
        val now = System.currentTimeMillis()
        for (k in 0 until arr.length()) {
            val o = arr.getJSONObject(k)
            val time = o.getLong("time")
            if (time > now) {
                scheduleOne(ctx, o.getInt("id"), time, o.getString("title"), o.getString("body"))
            }
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "StudyBuddy"
        val body = intent.getStringExtra("body") ?: ""
        val id = intent.getIntExtra("id", 0)
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = "reminders"
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(channel, "Reminders", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: Intent()
        val open = PendingIntent.getActivity(
            ctx, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, channel) else Notification.Builder(ctx)
        b.setSmallIcon(ctx.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
        nm.notify(id, b.build())
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Reminders.restore(ctx)
        }
    }
}
