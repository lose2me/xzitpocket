package live.xuda.xzitpocket

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

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
        scheduleNextUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == ACTION_AUTO_UPDATE ||
            action == Intent.ACTION_BOOT_COMPLETED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, TimetableWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                onUpdate(context, appWidgetManager, ids)
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleNextUpdate(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelScheduledUpdate(context)
    }

    companion object {
        private const val TAG = "TimetableWidget"
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val ACTION_AUTO_UPDATE = "live.xuda.xzitpocket.ACTION_AUTO_UPDATE"
        private const val UPDATE_INTERVAL_MS = 30_000L

        private const val DEFAULT_BAR_COLOR = 0xFF2655FE.toInt()
        private const val BAR_ACTIVE = 0xFF4CAF50.toInt()
        private const val BAR_EMPTY = 0xFFD0D0D0.toInt()

        private val WEEKDAY_NAMES = arrayOf("", "周一", "周二", "周三", "周四", "周五", "周六", "周日")

        // 14 time slots matching time_slots.dart
        private val TIME_SLOTS = arrayOf(
            intArrayOf(1, 8, 0, 8, 45),    // index, startH, startM, endH, endM
            intArrayOf(2, 8, 55, 9, 40),
            intArrayOf(3, 10, 5, 10, 50),
            intArrayOf(4, 11, 0, 11, 45),
            intArrayOf(5, 12, 0, 12, 45),
            intArrayOf(6, 12, 55, 13, 40),
            intArrayOf(7, 14, 0, 14, 45),
            intArrayOf(8, 14, 55, 15, 40),
            intArrayOf(9, 16, 5, 16, 50),
            intArrayOf(10, 17, 0, 17, 45),
            intArrayOf(11, 17, 55, 18, 40),
            intArrayOf(12, 18, 45, 19, 30),
            intArrayOf(13, 19, 40, 20, 25),
            intArrayOf(14, 20, 35, 21, 20),
        )

        // 24 course colors matching Course.colors in course.dart
        private val COURSE_COLORS = intArrayOf(
            0xFFF8D2D7.toInt(), 0xFFD2E5F8.toInt(), 0xFFD2F0E5.toInt(),
            0xFFF8F3D2.toInt(), 0xFFE5D2F8.toInt(), 0xFFF8E5D2.toInt(),
            0xFFF2C6D0.toInt(), 0xFFC6E0F2.toInt(), 0xFFC6F2E0.toInt(),
            0xFFF2F0C6.toInt(), 0xFFE0C6F2.toInt(), 0xFFF2E0C6.toInt(),
            0xFFEBBFC9.toInt(), 0xFFBFD8EB.toInt(), 0xFFBFEBDC.toInt(),
            0xFFEBE8BF.toInt(), 0xFFD8BFEB.toInt(), 0xFFEBD8BF.toInt(),
            0xFFF6D9DF.toInt(), 0xFFD9EAF6.toInt(), 0xFFD9F6EC.toInt(),
            0xFFF6F4D9.toInt(), 0xFFEAD9F6.toInt(), 0xFFF6EAD9.toInt(),
        )

        // ── Data class for parsed courses ──────────────────────────────────

        private data class NativeCourse(
            val title: String,
            val weekday: Int,
            val startSession: Int,
            val endSession: Int,
            val weeks: List<Int>,
            val place: String,
            val campus: String,
            val colorIndex: Int,
        )

        // ── AlarmManager scheduling ────────────────────────────────────────

        private fun scheduleNextUpdate(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TimetableWidgetProvider::class.java).apply {
                action = ACTION_AUTO_UPDATE
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + UPDATE_INTERVAL_MS,
                pendingIntent
            )
        }

        private fun cancelScheduledUpdate(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TimetableWidgetProvider::class.java).apply {
                action = ACTION_AUTO_UPDATE
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }

        // ── Helpers ────────────────────────────────────────────────────────

        /** Compute current week number from semester start date string (yyyy-MM-dd). */
        private fun currentWeek(semesterStart: String): Int {
            return try {
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val start = sdf.parse(semesterStart) ?: return 0
                val cal = Calendar.getInstance()
                val nowMs = cal.timeInMillis
                // Normalize start to midnight
                val startCal = Calendar.getInstance().apply { time = start }
                startCal.set(Calendar.HOUR_OF_DAY, 0)
                startCal.set(Calendar.MINUTE, 0)
                startCal.set(Calendar.SECOND, 0)
                startCal.set(Calendar.MILLISECOND, 0)
                val diffMs = nowMs - startCal.timeInMillis
                if (diffMs < 0) 0
                else (diffMs / (7 * 24 * 60 * 60 * 1000L)).toInt() + 1
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing semesterStart", e)
                0
            }
        }

        /** ISO weekday: Monday=1 … Sunday=7 */
        private fun isoWeekday(): Int {
            val dow = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) // Sunday=1
            return if (dow == Calendar.SUNDAY) 7 else dow - 1
        }

        /** Find time slot by session index, returns [startMin, endMin] */
        private fun slotMinutes(session: Int): IntArray? {
            val slot = TIME_SLOTS.firstOrNull { it[0] == session } ?: return null
            return intArrayOf(slot[1] * 60 + slot[2], slot[3] * 60 + slot[4])
        }

        /** Format slot time as HH:mm */
        private fun slotTimeString(session: Int, isStart: Boolean): String {
            val slot = TIME_SLOTS.firstOrNull { it[0] == session } ?: return ""
            return if (isStart) {
                "%02d:%02d".format(slot[1], slot[2])
            } else {
                "%02d:%02d".format(slot[3], slot[4])
            }
        }

        /** Get color for a course by colorIndex */
        private fun courseColor(colorIndex: Int): Int {
            return when {
                colorIndex in COURSE_COLORS.indices -> COURSE_COLORS[colorIndex]
                colorIndex != 0 -> colorIndex
                else -> DEFAULT_BAR_COLOR
            }
        }

        // ── JSON parsing ───────────────────────────────────────────────────

        private fun parseScheduleData(json: String): Triple<String, Int, List<NativeCourse>>? {
            return try {
                val root = JSONObject(json)
                val semesterStart = root.getString("semesterStart")
                val totalWeeks = root.optInt("totalWeeks", 16)
                val arr = root.getJSONArray("courses")
                val courses = mutableListOf<NativeCourse>()
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    val weeksArr = obj.getJSONArray("weeks")
                    val weeksList = mutableListOf<Int>()
                    for (w in 0 until weeksArr.length()) {
                        weeksList.add(weeksArr.getInt(w))
                    }
                    courses.add(
                        NativeCourse(
                            title = obj.optString("title", ""),
                            weekday = obj.optInt("weekday", 0),
                            startSession = obj.optInt("startSession", 0),
                            endSession = obj.optInt("endSession", 0),
                            weeks = weeksList,
                            place = obj.optString("place", ""),
                            campus = obj.optString("campus", ""),
                            colorIndex = obj.optInt("colorIndex", 0),
                        )
                    )
                }
                Triple(semesterStart, totalWeeks, courses)
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing schedule_data", e)
                null
            }
        }

        // ── Core widget update ─────────────────────────────────────────────

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val scheduleJson = prefs.getString("schedule_data", null)

            if (scheduleJson != null) {
                val parsed = parseScheduleData(scheduleJson)
                if (parsed != null) {
                    renderFromSchedule(context, appWidgetManager, appWidgetId, parsed)
                    return
                }
            }
            // Fallback to old capsule-based rendering
            renderFromCapsules(context, appWidgetManager, appWidgetId, prefs)
        }

        // ── Native schedule rendering ──────────────────────────────────────

        private fun renderFromSchedule(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            data: Triple<String, Int, List<NativeCourse>>
        ) {
            val (semesterStart, _, allCourses) = data
            val views = RemoteViews(context.packageName, R.layout.widget_timetable)

            val now = Calendar.getInstance()
            val week = currentWeek(semesterStart)
            val weekday = isoWeekday()
            val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

            // Header
            if (allCourses.isNotEmpty()) {
                views.setViewVisibility(R.id.header, View.VISIBLE)
                val weekText = if (week > 0) "第${week}周" else "未开学"
                val dateText = "${now.get(Calendar.MONTH) + 1}.${now.get(Calendar.DAY_OF_MONTH)}"
                val weekdayText = if (weekday in 1..7) WEEKDAY_NAMES[weekday] else ""
                views.setTextViewText(R.id.tv_week, weekText)
                views.setTextViewText(R.id.tv_date, dateText)
                views.setTextViewText(R.id.tv_weekday, weekdayText)
            } else {
                views.setViewVisibility(R.id.header, View.GONE)
            }

            // Filter today's courses in current week
            val todayCourses = allCourses
                .filter { it.weekday == weekday && it.weeks.contains(week) }
                .sortedBy { it.startSession }

            // Find current and next courses
            var currentCourse: NativeCourse? = null
            var currentRemaining = -1
            var nextCourse: NativeCourse? = null
            var nextNextCourse: NativeCourse? = null

            for (i in todayCourses.indices) {
                val c = todayCourses[i]
                val startMin = slotMinutes(c.startSession) ?: continue
                val endMin = slotMinutes(c.endSession) ?: continue

                if (nowMinutes >= startMin[0] && nowMinutes < endMin[1]) {
                    currentCourse = c
                    currentRemaining = endMin[1] - nowMinutes
                    if (i + 1 < todayCourses.size) {
                        nextCourse = todayCourses[i + 1]
                    }
                    break
                } else if (nowMinutes < startMin[0]) {
                    nextCourse = c
                    if (i + 1 < todayCourses.size) {
                        nextNextCourse = todayCourses[i + 1]
                    }
                    break
                }
            }

            // Determine capsule1 / capsule2
            val isInClass = currentCourse != null
            val cap1Course = if (isInClass) currentCourse else nextCourse
            val cap2Course = if (isInClass) nextCourse else nextNextCourse

            if (cap1Course == null) {
                // No more classes today
                views.setViewVisibility(R.id.items_container, View.GONE)
                views.setViewVisibility(R.id.empty_state, View.VISIBLE)
                views.setTextViewText(R.id.tv_empty_emoji, "(✿◡‿◡)")
                views.setTextViewText(R.id.tv_empty_text, "今天没有课啦")
            } else {
                views.setViewVisibility(R.id.empty_state, View.GONE)
                views.setViewVisibility(R.id.items_container, View.VISIBLE)
                views.setViewVisibility(R.id.item1, View.VISIBLE)

                if (isInClass) {
                    views.setInt(R.id.item1_bar, "setColorFilter", BAR_ACTIVE)
                    views.setTextViewText(R.id.item1_title, cap1Course.title)
                    views.setTextViewText(
                        R.id.item1_sub,
                        if (currentRemaining >= 0) "还剩 $currentRemaining 分钟下课" else ""
                    )
                } else {
                    val timeRange = "${slotTimeString(cap1Course.startSession, true)}-${
                        slotTimeString(cap1Course.endSession, false)
                    }"
                    views.setInt(R.id.item1_bar, "setColorFilter", courseColor(cap1Course.colorIndex))
                    views.setTextViewText(R.id.item1_title, cap1Course.title)
                    views.setTextViewText(R.id.item1_sub, timeRange)
                }

                if (cap2Course != null) {
                    views.setViewVisibility(R.id.item2, View.VISIBLE)
                    views.setViewVisibility(R.id.item2_bar, View.VISIBLE)
                    views.setViewVisibility(R.id.item2_title, View.VISIBLE)
                    val timeRange2 = "${slotTimeString(cap2Course.startSession, true)}-${
                        slotTimeString(cap2Course.endSession, false)
                    }"
                    views.setInt(R.id.item2_bar, "setColorFilter", courseColor(cap2Course.colorIndex))
                    views.setTextViewText(R.id.item2_title, cap2Course.title)
                    views.setTextViewText(R.id.item2_sub, timeRange2)
                    views.setInt(R.id.item2_title, "setGravity", android.view.Gravity.START)
                    views.setInt(R.id.item2_sub, "setGravity", android.view.Gravity.START)
                    views.setTextColor(R.id.item2_title, context.getColor(R.color.widget_title_color))
                } else {
                    views.setViewVisibility(R.id.item2, View.VISIBLE)
                    views.setViewVisibility(R.id.item2_bar, View.GONE)
                    views.setViewVisibility(R.id.item2_title, View.GONE)
                    views.setTextViewText(R.id.item2_title, "")
                    views.setTextViewText(R.id.item2_sub, "没有更多课啦")
                    views.setInt(R.id.item2_sub, "setGravity", android.view.Gravity.CENTER_HORIZONTAL)
                }
            }

            // Click → open timetable
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java,
                Uri.parse("xzitpocket://timetable")
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        // ── Fallback: old capsule-based rendering ──────────────────────────

        private fun renderFromCapsules(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            prefs: android.content.SharedPreferences
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_timetable)

            // Header
            val hasTimetable = prefs.getString("has_timetable", "false") == "true"
            if (hasTimetable) {
                views.setViewVisibility(R.id.header, View.VISIBLE)
                val week = prefs.getString("week", "") ?: ""
                val date = prefs.getString("date", "") ?: ""
                val weekday = prefs.getString("weekday", "") ?: ""
                views.setTextViewText(R.id.tv_week, week)
                views.setTextViewText(R.id.tv_date, date)
                views.setTextViewText(R.id.tv_weekday, weekday)
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
                if (hasTimetable) {
                    views.setTextViewText(R.id.tv_empty_emoji, "(✿◡‿◡)")
                    views.setTextViewText(R.id.tv_empty_text, "今天没有课啦")
                } else {
                    views.setTextViewText(R.id.tv_empty_emoji, "╰（‵□′）╯")
                    views.setTextViewText(R.id.tv_empty_text, "未登录教务系统")
                }
            } else {
                views.setViewVisibility(R.id.empty_state, View.GONE)
                views.setViewVisibility(R.id.items_container, View.VISIBLE)
                views.setViewVisibility(R.id.item1, View.VISIBLE)

                if (isInClass) {
                    renderItemCurrent(
                        views, R.id.item1_bar,
                        R.id.item1_title, R.id.item1_sub,
                        json1
                    )
                } else {
                    renderItemStandard(
                        views, R.id.item1_bar,
                        R.id.item1_title, R.id.item1_sub,
                        json1
                    )
                }

                if (json2.isNotEmpty()) {
                    views.setViewVisibility(R.id.item2, View.VISIBLE)
                    views.setViewVisibility(R.id.item2_bar, View.VISIBLE)
                    views.setViewVisibility(R.id.item2_title, View.VISIBLE)
                    renderItemStandard(
                        views, R.id.item2_bar,
                        R.id.item2_title, R.id.item2_sub,
                        json2
                    )
                    views.setInt(R.id.item2_title, "setGravity", android.view.Gravity.START)
                    views.setInt(R.id.item2_sub, "setGravity", android.view.Gravity.START)
                    views.setTextColor(R.id.item2_title, context.getColor(R.color.widget_title_color))
                } else {
                    views.setViewVisibility(R.id.item2, View.VISIBLE)
                    views.setViewVisibility(R.id.item2_bar, View.GONE)
                    views.setViewVisibility(R.id.item2_title, View.GONE)
                    views.setTextViewText(R.id.item2_title, "")
                    views.setTextViewText(R.id.item2_sub, "没有更多课啦")
                    views.setInt(R.id.item2_sub, "setGravity", android.view.Gravity.CENTER_HORIZONTAL)
                }
            }

            // Click → open timetable
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java,
                Uri.parse("xzitpocket://timetable")
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        // ── Capsule item renderers (for fallback) ──────────────────────────

        private fun renderItemCurrent(
            views: RemoteViews,
            barId: Int, titleId: Int, subId: Int,
            json: String
        ) {
            try {
                val obj = JSONObject(json)
                val title = obj.optString("title", "")
                val remaining = if (obj.isNull("remainingMinutes")) -1
                else obj.optInt("remainingMinutes", -1)

                views.setInt(barId, "setColorFilter", BAR_ACTIVE)
                views.setTextViewText(titleId, title)
                views.setTextViewText(
                    subId,
                    if (remaining >= 0) "还剩 ${remaining} 分钟下课" else ""
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing current item", e)
                setItemError(views, barId, titleId, subId)
            }
        }

        private fun renderItemStandard(
            views: RemoteViews,
            barId: Int, titleId: Int, subId: Int,
            json: String
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
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing standard item", e)
                setItemError(views, barId, titleId, subId)
            }
        }

        private fun setItemError(
            views: RemoteViews,
            barId: Int, titleId: Int, subId: Int
        ) {
            views.setInt(barId, "setColorFilter", BAR_EMPTY)
            views.setTextViewText(titleId, "数据异常")
            views.setTextViewText(subId, "")
        }
    }
}
