package com.sophis.sophis

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class SophisWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val caloriesGoal = widgetData.getDouble("calories_goal", 2500.0)
                val caloriesRemaining = widgetData.getDouble("calories_remaining", 0.0)
                
                val protein = widgetData.getDouble("protein_eaten", 0.0)
                val carbs = widgetData.getDouble("carbs_eaten", 0.0)
                val fat = widgetData.getDouble("fat_eaten", 0.0)
                val water = widgetData.getDouble("water_ml", 0.0)

                // Calculate progress (0-100)
                // Goal - Remaining = Eaten. Progress = Eaten / Goal.
                // Ideally use meaningful goal if 0.
                val goalSafe = if (caloriesGoal > 0) caloriesGoal else 1.0
                val eaten = goalSafe - caloriesRemaining
                val progress = ((eaten / goalSafe) * 100).toInt().coerceIn(0, 100)

                // Update Progress Bar
                setProgressBar(R.id.progress_calories, 100, progress, false)

                // Update text views
                setTextViewText(R.id.tv_calories_remaining, "${caloriesRemaining.toInt()}")
                setTextViewText(R.id.tv_protein, "${protein.toInt()}g")
                setTextViewText(R.id.tv_carbs, "${carbs.toInt()}g")
                setTextViewText(R.id.tv_fat, "${fat.toInt()}g")
                setTextViewText(R.id.tv_water, "${water.toInt()} ml")
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
