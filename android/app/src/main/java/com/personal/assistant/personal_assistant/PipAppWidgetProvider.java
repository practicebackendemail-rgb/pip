package com.personal.assistant.personal_assistant;

import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.widget.RemoteViews;
import es.antonborri.home_widget.HomeWidgetProvider;

public class PipAppWidgetProvider extends HomeWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds, SharedPreferences widgetData) {
        for (int appWidgetId : appWidgetIds) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.pip_app_widget);

            String status = widgetData.getString("pip_status", "Standing by");
            int pending = widgetData.getInt("pip_pending_tasks", 0);

            views.setTextViewText(R.id.pip_widget_status, status);
            views.setTextViewText(R.id.pip_widget_tasks, "Tasks Pending: " + pending);

            appWidgetManager.updateAppWidget(appWidgetId, views);
        }
    }
}
