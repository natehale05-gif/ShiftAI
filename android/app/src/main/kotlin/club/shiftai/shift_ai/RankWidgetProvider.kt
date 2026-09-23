package club.shiftai.shift_ai

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Your rank and this week's earnings — the small widget. */
class RankWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_rank)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            val rank = widgetData.getString("you_rank", null)
            val earnings = widgetData.getString("you_earnings", null)
            val movement = widgetData.getString("you_movement", null)?.toIntOrNull() ?: 0

            if (rank == null) {
                views.setTextViewText(R.id.rank_value, "—")
                views.setTextViewText(R.id.rank_label, "Open ShiftAi")
                views.setTextViewText(R.id.rank_earnings, "")
                views.setTextViewText(R.id.rank_movement, "")
            } else {
                views.setTextViewText(R.id.rank_value, "#$rank")
                views.setTextViewText(R.id.rank_label, "RANK")
                views.setTextViewText(
                    R.id.rank_earnings,
                    "$" + (earnings?.toDoubleOrNull()?.let { formatMoney(it) } ?: "0"),
                )
                views.setTextViewText(R.id.rank_movement, movementLabel(movement))
                views.setTextColor(
                    R.id.rank_movement,
                    context.getColor(
                        if (movement < 0) R.color.widget_danger else R.color.widget_success,
                    ),
                )
            }

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
