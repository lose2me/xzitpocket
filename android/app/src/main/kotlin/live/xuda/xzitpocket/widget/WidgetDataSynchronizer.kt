package live.xuda.xzitpocket.widget

import android.content.Context
import java.util.Calendar

internal object WidgetDataSynchronizer {
    private const val SYNC_DAYS = 7

    fun syncNow(context: Context) {
        val source = WidgetPrefsRepository.readScheduleSource(context)
        if (source == null || source.semesterStart.isBlank() || source.totalWeeks <= 0) {
            WidgetPrefsRepository.saveSnapshot(context, WidgetSnapshot.empty())
            WidgetUpdateHelper.updateAllWidgets(context)
            return
        }

        val startCalendar = WidgetTimeUtils.parseIsoDate(source.semesterStart)
        if (startCalendar == null) {
            WidgetPrefsRepository.saveSnapshot(context, WidgetSnapshot.empty())
            WidgetUpdateHelper.updateAllWidgets(context)
            return
        }

        val today = Calendar.getInstance()
        WidgetTimeUtils.normalizeToStartOfDay(today)
        val syncStart = if (today.before(startCalendar)) {
            WidgetTimeUtils.copy(startCalendar)
        } else {
            WidgetTimeUtils.copy(today)
        }

        val courses = mutableListOf<WidgetCourse>()
        val cursor = WidgetTimeUtils.copy(syncStart)

        repeat(SYNC_DAYS) {
            val dateString = WidgetTimeUtils.formatIsoDate(cursor)
            val weekNumber = WidgetTimeUtils.calculateWeekAtDate(
                source.semesterStart,
                source.totalWeeks,
                dateString,
            )

            if (weekNumber > 0) {
                val weekday = WidgetTimeUtils.isoWeekday(cursor)
                val dayCourses = source.courses
                    .filter { it.weekday == weekday && it.weeks.contains(weekNumber) }
                    .sortedBy { it.sortOrder }
                dayCourses.forEachIndexed { index, course ->
                    val hasConflict = dayCourses.any { other ->
                        other !== course && coursesOverlap(course, other)
                    }
                    courses.add(
                        WidgetCourse(
                            id = "${dateString}-${course.sortOrder}-${index}",
                            title = course.title,
                            place = course.place,
                            campus = course.campus,
                            startTime = course.startTime,
                            endTime = course.endTime,
                            color = course.color,
                            date = dateString,
                            sortOrder = course.sortOrder,
                            isConflict = hasConflict,
                        ),
                    )
                }
            }

            cursor.add(Calendar.DAY_OF_YEAR, 1)
        }

        WidgetPrefsRepository.saveSnapshot(
            context,
            WidgetSnapshot(
                hasSchedule = true,
                semesterStart = source.semesterStart,
                totalWeeks = source.totalWeeks,
                courses = courses.sortedWith(compareBy({ it.date }, { it.sortOrder }, { it.title })),
            ),
        )

        WidgetUpdateHelper.updateAllWidgets(context)
    }

    private fun coursesOverlap(a: ScheduleSourceCourse, b: ScheduleSourceCourse): Boolean {
        return a.startSession <= b.endSession && b.startSession <= a.endSession
    }
}
