package com.personal.assistant.personal_assistant

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Pip's home-screen widget. The app writes mood, status and the open-task
 * count through `PipHomeWidgetService` (home_widget); this draws them and
 * opens Pip on tap. Declared in AndroidManifest as `.PipAppWidgetProvider`.
 */
class PipAppWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val mood = widgetData.getString("pip_mood", null)
        val status = widgetData.getString("pip_status", null) ?: "Tap to talk to Pip"
        val tasks = widgetData.getInt("pip_pending_tasks", 0)

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.pip_app_widget).apply {
                setTextViewText(R.id.pip_widget_title, if (mood.isNullOrBlank()) "Pip" else "Pip · $mood")
                setTextViewText(R.id.pip_widget_status, status)
                setTextViewText(
                    R.id.pip_widget_tasks,
                    when (tasks) {
                        0 -> "Nothing on your plate"
                        1 -> "1 open task"
                        else -> "$tasks open tasks"
                    },
                )
                setOnClickPendingIntent(
                    R.id.pip_widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
