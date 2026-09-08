package live.xuda.xzitpocket.widget

import org.json.JSONArray
import org.json.JSONObject

internal data class ScheduleSource(
    val semesterStart: String,
    val totalWeeks: Int,
    val courses: List<ScheduleSourceCourse>,
) {
    companion object {
        fun fromJson(json: String?): ScheduleSource? {
            if (json.isNullOrBlank()) return null
            return try {
                val root = JSONObject(json)
                val semesterStart = root.optString("semesterStart", "")
                val totalWeeks = root.optInt("totalWeeks", 16)
                val courseArray = root.optJSONArray("courses") ?: JSONArray()
                val courses = mutableListOf<ScheduleSourceCourse>()

                for (i in 0 until courseArray.length()) {
                    val courseObject = courseArray.optJSONObject(i) ?: continue
                    val weeksArray = courseObject.optJSONArray("weeks") ?: JSONArray()
                    val weeks = mutableListOf<Int>()
                    for (w in 0 until weeksArray.length()) {
                        weeks.add(weeksArray.optInt(w))
                    }

                    courses.add(
                        ScheduleSourceCourse(
                            title = courseObject.optString("title", ""),
                            weekday = courseObject.optInt("weekday", 0),
                            weeks = weeks,
                            place = courseObject.optString("place", ""),
                            campus = courseObject.optString("campus", ""),
                            startSession = courseObject.optInt("startSession", 0),
                            endSession = courseObject.optInt("endSession", 0),
                            startTime = courseObject.optString("startTime", ""),
                            endTime = courseObject.optString("endTime", ""),
                            color = courseObject.optInt("color", DEFAULT_COURSE_COLOR),
                            sortOrder = courseObject.optInt("startSession", 0),
                        ),
                    )
                }

                ScheduleSource(
                    semesterStart = semesterStart,
                    totalWeeks = totalWeeks,
                    courses = courses,
                )
            } catch (_: Exception) {
                null
            }
        }

        private const val DEFAULT_COURSE_COLOR = 0xFF2655FE.toInt()
    }
}

internal data class ScheduleSourceCourse(
    val title: String,
    val weekday: Int,
    val weeks: List<Int>,
    val place: String,
    val campus: String,
    val startSession: Int,
    val endSession: Int,
    val startTime: String,
    val endTime: String,
    val color: Int,
    val sortOrder: Int,
)

internal data class WidgetCourse(
    val id: String,
    val title: String,
    val place: String,
    val campus: String,
    val startTime: String,
    val endTime: String,
    val color: Int,
    val date: String,
    val sortOrder: Int,
    val isConflict: Boolean,
)

internal data class WidgetSnapshot(
    val hasSchedule: Boolean,
    val semesterStart: String?,
    val totalWeeks: Int,
    val windowStartDate: String?,
    val windowDays: Int,
    val courses: List<WidgetCourse>,
) {
    fun toJson(): String {
        val root = JSONObject()
        root.put("hasSchedule", hasSchedule)
        root.put("semesterStart", semesterStart ?: "")
        root.put("totalWeeks", totalWeeks)
        root.put("windowStartDate", windowStartDate ?: "")
        root.put("windowDays", windowDays)

        val courseArray = JSONArray()
        courses.forEach { course ->
            courseArray.put(
                JSONObject().apply {
                    put("id", course.id)
                    put("title", course.title)
                    put("place", course.place)
                    put("campus", course.campus)
                    put("startTime", course.startTime)
                    put("endTime", course.endTime)
                    put("color", course.color)
                    put("date", course.date)
                    put("sortOrder", course.sortOrder)
                    put("isConflict", course.isConflict)
                },
            )
        }
        root.put("courses", courseArray)
        return root.toString()
    }

    companion object {
        fun empty(hasSchedule: Boolean = false): WidgetSnapshot {
            return WidgetSnapshot(
                hasSchedule = hasSchedule,
                semesterStart = null,
                totalWeeks = 0,
                windowStartDate = null,
                windowDays = 0,
                courses = emptyList(),
            )
        }

        fun fromJson(json: String?): WidgetSnapshot? {
            if (json.isNullOrBlank()) return null
            return try {
                val root = JSONObject(json)
                val courseArray = root.optJSONArray("courses") ?: JSONArray()
                val courses = mutableListOf<WidgetCourse>()
                for (i in 0 until courseArray.length()) {
                    val obj = courseArray.optJSONObject(i) ?: continue
                    courses.add(
                        WidgetCourse(
                            id = obj.optString("id", ""),
                            title = obj.optString("title", ""),
                            place = obj.optString("place", ""),
                            campus = obj.optString("campus", ""),
                            startTime = obj.optString("startTime", ""),
                            endTime = obj.optString("endTime", ""),
                            color = obj.optInt("color", 0xFF2655FE.toInt()),
                            date = obj.optString("date", ""),
                            sortOrder = obj.optInt("sortOrder", 0),
                            isConflict = obj.optBoolean("isConflict", false),
                        ),
                    )
                }

                WidgetSnapshot(
                    hasSchedule = root.optBoolean("hasSchedule", false),
                    semesterStart = root.optString("semesterStart", "").ifBlank { null },
                    totalWeeks = root.optInt("totalWeeks", 0),
                    windowStartDate = root.optString("windowStartDate", "").ifBlank { null },
                    windowDays = root.optInt("windowDays", 0),
                    courses = courses,
                )
            } catch (_: Exception) {
                null
            }
        }
    }
}

internal data class RenderSnapshot(
    val hasSchedule: Boolean,
    val currentWeek: Int,
    val isUpcoming: Boolean,
    val courses: List<WidgetCourse>,
)
