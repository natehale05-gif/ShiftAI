package club.shiftai.shift_ai

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Who you're catching, and who's catching you — the medium rivals widget. */
class RivalsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_rivals)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            val targetName = widgetData.getString("target_name", null)
            val targetGap = widgetData.getString("target_gap", null)?.toDoubleOrNull()
            views.setTextViewText(R.id.target_name, targetName ?: "Nobody left to catch")
            views.setTextViewText(
                R.id.target_gap,
                targetGap?.let { "$" + formatMoney(it) + " away" } ?: "",
            )

            val chaserName = widgetData.getString("chaser_name", null)
            val chaserGap = widgetData.getString("chaser_gap", null)?.toDoubleOrNull()
            views.setTextViewText(R.id.chaser_name, chaserName ?: "Nobody behind you")
            views.setTextViewText(
                R.id.chaser_gap,
                chaserGap?.let { "$" + formatMoney(it) + " behind" } ?: "",
            )

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
