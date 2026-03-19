package live.xuda.xzitpocket.widget

import android.content.Context
import live.xuda.xzitpocket.automation.ClassAutomationScheduler
import java.util.Calendar

internal object WidgetDataSynchronizer {
    private const val SYNC_DAYS = 8

    fun syncNow(context: Context) {
        val snapshot = buildSnapshot(context)
        WidgetPrefsRepository.saveSnapshot(context, snapshot)
        ClassAutomationScheduler.enqueueWork(context)
        WidgetUpdateHelper.updateAllWidgets(context)
    }

    fun refreshSnapshotIfNeeded(context: Context): Boolean {
        val source = WidgetPrefsRepository.readScheduleSource(context)
        val currentSnapshot = WidgetPrefsRepository.readSnapshot(context)
        if (snapshotMatches(source, currentSnapshot)) {
            return false
        }

        WidgetPrefsRepository.saveSnapshot(context, buildSnapshot(context, source))
        return true
    }

    private fun buildSnapshot(
        context: Context,
        source: ScheduleSource? = WidgetPrefsRepository.readScheduleSource(context),
    ): WidgetSnapshot {
        if (source == null || source.semesterStart.isBlank() || source.totalWeeks <= 0) {
            return WidgetSnapshot.empty()
        }

        val startCalendar = WidgetTimeUtils.parseIsoDate(source.semesterStart)
        if (startCalendar == null) {
            return WidgetSnapshot.empty()
        }

        val syncStart = calculateSyncStart(startCalendar)

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

        return WidgetSnapshot(
            hasSchedule = true,
            semesterStart = source.semesterStart,
            totalWeeks = source.totalWeeks,
            windowStartDate = WidgetTimeUtils.formatIsoDate(syncStart),
            windowDays = SYNC_DAYS,
            courses = courses.sortedWith(compareBy({ it.date }, { it.sortOrder }, { it.title })),
        )
    }

    private fun snapshotMatches(
        source: ScheduleSource?,
        snapshot: WidgetSnapshot,
    ): Boolean {
        val semesterStart = source?.semesterStart
        if (source == null || semesterStart.isNullOrBlank() || source.totalWeeks <= 0) {
            return !snapshot.hasSchedule && snapshot.courses.isEmpty()
        }

        val parsedStart = WidgetTimeUtils.parseIsoDate(semesterStart) ?: return !snapshot.hasSchedule
        val expectedStartDate = WidgetTimeUtils.formatIsoDate(calculateSyncStart(parsedStart))

        return snapshot.hasSchedule &&
            snapshot.semesterStart == semesterStart &&
            snapshot.totalWeeks == source.totalWeeks &&
            snapshot.windowStartDate == expectedStartDate &&
            snapshot.windowDays == SYNC_DAYS
    }

    private fun calculateSyncStart(startCalendar: Calendar): Calendar {
        val today = Calendar.getInstance()
        WidgetTimeUtils.normalizeToStartOfDay(today)
        return if (today.before(startCalendar)) {
            WidgetTimeUtils.copy(startCalendar)
        } else {
            WidgetTimeUtils.copy(today)
        }
    }

    private fun coursesOverlap(a: ScheduleSourceCourse, b: ScheduleSourceCourse): Boolean {
        return a.startSession <= b.endSession && b.startSession <= a.endSession
    }
}
