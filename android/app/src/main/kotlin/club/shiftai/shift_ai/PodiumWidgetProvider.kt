package club.shiftai.shift_ai

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** This week's top 3 — the medium podium widget. */
class PodiumWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_podium)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            setSpot(views, widgetData, 1, R.id.podium_1_name, R.id.podium_1_earnings)
            setSpot(views, widgetData, 2, R.id.podium_2_name, R.id.podium_2_earnings)
            setSpot(views, widgetData, 3, R.id.podium_3_name, R.id.podium_3_earnings)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun setSpot(
        views: RemoteViews,
        data: SharedPreferences,
        rank: Int,
        nameId: Int,
        earningsId: Int,
    ) {
        val name = data.getString("podium_${rank}_name", null)
        val earnings = data.getString("podium_${rank}_earnings", null)?.toDoubleOrNull()
        views.setTextViewText(nameId, name ?: "—")
        views.setTextViewText(earningsId, earnings?.let { "$" + formatMoney(it) } ?: "")
    }
}
