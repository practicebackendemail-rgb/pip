package com.personal.assistant.personal_assistant

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * Pip's home-screen widgets. The app writes mood, Pip's line, the next tasks
 * and a rendered image of Pip through `PipHomeWidgetService` (home_widget);
 * these providers only draw them.
 *
 * Small (2x1): Pip, the next thing due, and a mic.
 * Medium (4x2): adds the next three tasks; tapping one ticks it off in the
 * background (`pipWidgetCallback` in Dart) without opening the app.
 */
open class PipAppWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, build(context, widgetData))
        }
    }

    protected open fun build(context: Context, data: SharedPreferences): RemoteViews =
        RemoteViews(context.packageName, R.layout.pip_app_widget).apply {
            val mood = data.getString("pip_mood", null)
            setTextViewText(R.id.pip_widget_title, if (mood.isNullOrBlank()) "Pip" else "Pip · $mood")
            setTextViewText(R.id.pip_widget_next, data.getString("pip_next", null) ?: "Tap to talk to Pip")
            bindCommon(context, this, data)
        }

    protected fun bindCommon(context: Context, views: RemoteViews, data: SharedPreferences) {
        data.getString("pip_face", null)?.let { path ->
            if (File(path).exists()) BitmapFactory.decodeFile(path)?.let { views.setImageViewBitmap(R.id.pip_widget_face, it) }
        }
        views.setOnClickPendingIntent(
            R.id.pip_widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
        views.setOnClickPendingIntent(
            R.id.pip_widget_mic,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("pip://listen")),
        )
    }
}

class PipAppWidgetMediumProvider : PipAppWidgetProvider() {
    private val rows = listOf(
        Triple(R.id.pip_task_0, R.id.pip_task_0_title, R.id.pip_task_0_when),
        Triple(R.id.pip_task_1, R.id.pip_task_1_title, R.id.pip_task_1_when),
        Triple(R.id.pip_task_2, R.id.pip_task_2_title, R.id.pip_task_2_when),
    )

    override fun build(context: Context, data: SharedPreferences): RemoteViews =
        RemoteViews(context.packageName, R.layout.pip_app_widget_medium).apply {
            setTextViewText(R.id.pip_widget_status, data.getString("pip_status", null) ?: "Tap to talk to Pip")
            val count = data.getInt("pip_pending_tasks", 0)
            setTextViewText(
                R.id.pip_widget_tasks,
                when (count) {
                    0 -> "Nothing on your plate"
                    1 -> "1 open task"
                    else -> "$count open tasks"
                },
            )
            rows.forEachIndexed { i, (row, title, whenView) ->
                val id = data.getString("pip_task_${i}_id", null)
                if (id == null) {
                    setViewVisibility(row, View.GONE)
                } else {
                    setViewVisibility(row, View.VISIBLE)
                    setTextViewText(title, data.getString("pip_task_${i}_title", ""))
                    setTextViewText(whenView, data.getString("pip_task_${i}_when", ""))
                    setOnClickPendingIntent(
                        row,
                        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("pip://task/done?id=" + Uri.encode(id))),
                    )
                }
            }
            bindCommon(context, this, data)
        }
}
