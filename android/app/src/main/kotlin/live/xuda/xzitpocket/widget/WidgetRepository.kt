package live.xuda.xzitpocket.widget

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

internal object WidgetPrefsRepository {
    private const val PREFS_NAME = "HomeWidgetPreferences"
    private const val KEY_SCHEDULE_DATA = "schedule_data"
    private const val KEY_WIDGET_SNAPSHOT = "widget_snapshot_v2"

    fun readScheduleSource(context: Context): ScheduleSource? {
        val raw = prefs(context).getString(KEY_SCHEDULE_DATA, null)
        return ScheduleSource.fromJson(raw)
    }

    fun readSnapshot(context: Context): WidgetSnapshot {
        val raw = prefs(context).getString(KEY_WIDGET_SNAPSHOT, null)
        return WidgetSnapshot.fromJson(raw) ?: WidgetSnapshot.empty()
    }

    fun saveSnapshot(context: Context, snapshot: WidgetSnapshot) {
        prefs(context).edit().putString(KEY_WIDGET_SNAPSHOT, snapshot.toJson()).commit()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}

internal object WidgetTimeUtils {
    fun todayIsoDate(): String = formatIsoDate(Calendar.getInstance())

    fun tomorrowIsoDate(): String {
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, 1)
        return formatIsoDate(calendar)
    }

    fun todayDisplayDate(): String = formatDisplayDate(Calendar.getInstance())

    fun tomorrowDisplayDate(): String {
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, 1)
        return formatDisplayDate(calendar)
    }

    fun formatIsoDate(calendar: Calendar): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(calendar.time)
    }

    fun formatDisplayDate(calendar: Calendar): String {
        return SimpleDateFormat("M.d E", Locale.getDefault()).format(calendar.time)
    }

    fun parseIsoDate(date: String?): Calendar? {
        if (date.isNullOrBlank()) return null
        return try {
            val parsed = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(date) ?: return null
            Calendar.getInstance().apply {
                time = parsed
                normalizeToStartOfDay(this)
            }
        } catch (_: Exception) {
            null
        }
    }

    fun normalizeToStartOfDay(calendar: Calendar) {
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
    }

    fun copy(calendar: Calendar): Calendar = calendar.clone() as Calendar

    fun isoWeekday(calendar: Calendar): Int {
        val day = calendar.get(Calendar.DAY_OF_WEEK)
        return if (day == Calendar.SUNDAY) 7 else day - 1
    }

    fun nowMinutes(): Int {
        val now = Calendar.getInstance()
        return now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
    }

    fun parseTimeToMinutes(time: String): Int? {
        val parts = time.split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return hour * 60 + minute
    }

    fun calculateCurrentWeek(
        semesterStart: String?,
        totalWeeks: Int,
        reference: Calendar = Calendar.getInstance(),
    ): Int {
        val startCalendar = parseIsoDate(semesterStart) ?: return 0
        if (totalWeeks <= 0) return 0

        val normalizedReference = copy(reference)
        normalizeToStartOfDay(normalizedReference)
        val diffMillis = normalizedReference.timeInMillis - startCalendar.timeInMillis
        if (diffMillis < 0) return 0

        val week = (diffMillis / (7L * 24 * 60 * 60 * 1000)).toInt() + 1
        return if (week in 1..totalWeeks) week else 0
    }

    fun isBeforeSemesterStart(
        semesterStart: String?,
        reference: Calendar = Calendar.getInstance(),
    ): Boolean {
        val startCalendar = parseIsoDate(semesterStart) ?: return false
        val normalizedReference = copy(reference)
        normalizeToStartOfDay(normalizedReference)
        return normalizedReference.before(startCalendar)
    }

    fun calculateWeekAtDate(
        semesterStart: String?,
        totalWeeks: Int,
        date: String,
    ): Int {
        val calendar = parseIsoDate(date) ?: return 0
        return calculateCurrentWeek(semesterStart, totalWeeks, calendar)
    }
}
