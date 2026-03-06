package live.xuda.xzitpocket

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.res.Configuration
import android.widget.RemoteViews
import android.net.Uri
import android.util.Log
import android.view.View
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONObject

class TimetableWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget $appWidgetId", e)
            }
        }
    }

    companion object {
        private const val TAG = "TimetableWidget"
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val DEFAULT_BAR_COLOR = 0xFF2655FE.toInt()
        private const val BAR_ACTIVE = 0xFF4CAF50.toInt()
        private const val BAR_EMPTY_LIGHT = 0xFFD0D0D0.toInt()
        private const val BAR_EMPTY_DARK = 0xFF404060.toInt()
        private const val SUB_TEXT_LIGHT = 0x99000000.toInt()
        private const val SUB_TEXT_DARK = 0x99FFFFFF.toInt()

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.widget_timetable)

            val isDark = (context.resources.configuration.uiMode and
                    Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            val subColor = if (isDark) SUB_TEXT_DARK else SUB_TEXT_LIGHT
            val titleColor = if (isDark) 0xFFE8EAF0.toInt() else 0xFF1A1A1A.toInt()

            views.setInt(R.id.widget_root, "setBackgroundResource",
                if (isDark) R.drawable.widget_background_dark
                else R.drawable.widget_background)

            // Header — hide when no timetable data
            val hasTimetable = prefs.getString("has_timetable", "false") == "true"
            if (hasTimetable) {
                views.setViewVisibility(R.id.header, View.VISIBLE)
                val week = prefs.getString("week", "") ?: ""
                val date = prefs.getString("date", "") ?: ""
                val weekday = prefs.getString("weekday", "") ?: ""
                views.setTextViewText(R.id.tv_week, week)
                views.setTextViewText(R.id.tv_date, date)
                views.setTextViewText(R.id.tv_weekday, weekday)
                views.setTextColor(R.id.tv_week, subColor)
                views.setTextColor(R.id.tv_date, subColor)
                views.setTextColor(R.id.tv_weekday, subColor)
            } else {
                views.setViewVisibility(R.id.header, View.GONE)
            }

            // Items
            val isInClass = prefs.getString("is_in_class", "false") == "true"
            val json1 = prefs.getString("capsule1", "") ?: ""
            val json2 = prefs.getString("capsule2", "") ?: ""

            if (json1.isEmpty()) {
                views.setViewVisibility(R.id.items_container, View.GONE)
                views.setViewVisibility(R.id.empty_state, View.VISIBLE)
                views.setTextViewText(R.id.tv_empty_emoji, "ヾ(≧▽≦*)o")
                views.setTextViewText(R.id.tv_empty_text, "后面没有课啦!")
                views.setTextColor(R.id.tv_empty_emoji, titleColor)
                views.setTextColor(R.id.tv_empty_text, subColor)
            } else {
                views.setViewVisibility(R.id.empty_state, View.GONE)
                views.setViewVisibility(R.id.items_container, View.VISIBLE)
                views.setViewVisibility(R.id.item1, View.VISIBLE)

                if (isInClass) {
                    renderItemCurrent(views, R.id.item1_bar,
                        R.id.item1_title, R.id.item1_sub,
                        json1, titleColor, subColor)
                } else {
                    renderItemStandard(views, R.id.item1_bar,
                        R.id.item1_title, R.id.item1_sub,
                        json1, titleColor, subColor)
                }

                if (json2.isNotEmpty()) {
                    views.setViewVisibility(R.id.item2, View.VISIBLE)
                    renderItemStandard(views, R.id.item2_bar,
                        R.id.item2_title, R.id.item2_sub,
                        json2, titleColor, subColor)
                } else {
                    views.setViewVisibility(R.id.item2, View.GONE)
                }
            }

            // Click → open timetable
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java,
                Uri.parse("xzitpocket://timetable"))
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        // In-class: course name + countdown, green bar
        private fun renderItemCurrent(
            views: RemoteViews,
            barId: Int, titleId: Int, subId: Int,
            json: String, titleColor: Int, subColor: Int
        ) {
            try {
                val obj = JSONObject(json)
                val title = obj.optString("title", "")
                val remaining = if (obj.isNull("remainingMinutes")) -1
                    else obj.optInt("remainingMinutes", -1)

                views.setInt(barId, "setColorFilter", BAR_ACTIVE)
                views.setTextViewText(titleId, title)
                views.setTextViewText(subId,
                    if (remaining >= 0) "还剩 ${remaining} 分钟下课" else "")
                views.setTextColor(titleId, titleColor)
                views.setTextColor(subId, subColor)
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing current item", e)
                setItemError(views, barId, titleId, subId, subColor)
            }
        }

        // Standard: course name + time range, course color bar
        private fun renderItemStandard(
            views: RemoteViews,
            barId: Int, titleId: Int, subId: Int,
            json: String, titleColor: Int, subColor: Int
        ) {
            try {
                val obj = JSONObject(json)
                val title = obj.optString("title", "")
                val timeRange = obj.optString("timeRange", "")
                val courseColor = if (obj.isNull("color")) DEFAULT_BAR_COLOR
                    else obj.optLong("color", DEFAULT_BAR_COLOR.toLong()).toInt()

                views.setInt(barId, "setColorFilter", courseColor)
                views.setTextViewText(titleId, title)
                views.setTextViewText(subId, timeRange)
                views.setTextColor(titleId, titleColor)
                views.setTextColor(subId, subColor)
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing standard item", e)
                setItemError(views, barId, titleId, subId, subColor)
            }
        }

        private fun setItemError(
            views: RemoteViews,
            barId: Int, titleId: Int, subId: Int,
            subColor: Int
        ) {
            views.setInt(barId, "setColorFilter", BAR_EMPTY_LIGHT)
            views.setTextViewText(titleId, "数据异常")
            views.setTextViewText(subId, "")
            views.setTextColor(titleId, subColor)
        }
    }
}
