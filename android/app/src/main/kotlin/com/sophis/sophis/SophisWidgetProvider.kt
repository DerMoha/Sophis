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
                val caloriesGoal = widgetData.getFloat("calories_goal", 2500.0f).toDouble()
                val caloriesRemaining = widgetData.getFloat("calories_remaining", 0.0f).toDouble()
                
                val protein = widgetData.getFloat("protein_eaten", 0.0f).toDouble()
                val carbs = widgetData.getFloat("carbs_eaten", 0.0f).toDouble()
                val fat = widgetData.getFloat("fat_eaten", 0.0f).toDouble()
                val water = widgetData.getFloat("water_ml", 0.0f).toDouble()

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
