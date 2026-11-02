package com.studybuddy.studybuddy

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** Home screen widget: shows this month's money left. Tap to open the app. */
class StudyWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            mgr.updateAppWidget(id, build(ctx))
        }
    }

    companion object {
        private const val PREFS = "widget"

        fun save(ctx: Context, title: String, big: String, line: String) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("title", title).putString("big", big).putString("line", line).apply()
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, StudyWidget::class.java))
            for (id in ids) {
                mgr.updateAppWidget(id, build(ctx))
            }
        }

        fun build(ctx: Context): RemoteViews {
            val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val v = RemoteViews(ctx.packageName, R.layout.widget_study)
            v.setTextViewText(R.id.w_title, p.getString("title", "StudyBuddy"))
            v.setTextViewText(R.id.w_big, p.getString("big", "Open app"))
            v.setTextViewText(R.id.w_line, p.getString("line", "Tap to open StudyBuddy"))
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: Intent()
            val open = PendingIntent.getActivity(
                ctx, 1, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            v.setOnClickPendingIntent(R.id.w_root, open)
            return v
        }
    }
}
