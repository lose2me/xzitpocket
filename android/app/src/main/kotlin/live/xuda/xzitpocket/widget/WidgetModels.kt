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

                    val startSession = courseObject.optInt("startSession", 0)
                    val endSession = courseObject.optInt("endSession", startSession)
                    val fallbackTimeRange = legacyTimeRange(startSession, endSession)

                    courses.add(
                        ScheduleSourceCourse(
                            title = courseObject.optString("title", ""),
                            weekday = courseObject.optInt("weekday", 0),
                            weeks = weeks,
                            place = courseObject.optString("place", ""),
                            campus = courseObject.optString("campus", ""),
                            startSession = startSession,
                            endSession = endSession,
                            startTime = courseObject.optString(
                                "startTime",
                                fallbackTimeRange.first,
                            ),
                            endTime = courseObject.optString(
                                "endTime",
                                fallbackTimeRange.second,
                            ),
                            color = when {
                                courseObject.has("color") -> courseObject.optInt(
                                    "color",
                                    DEFAULT_COURSE_COLOR,
                                )

                                courseObject.has("colorIndex") -> legacyColor(
                                    courseObject.optInt("colorIndex", -1),
                                )

                                else -> DEFAULT_COURSE_COLOR
                            },
                            sortOrder = startSession,
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

        private val LEGACY_TIME_SLOTS = mapOf(
            1 to ("08:00" to "08:45"),
            2 to ("08:55" to "09:40"),
            3 to ("10:05" to "10:50"),
            4 to ("11:00" to "11:45"),
            5 to ("12:00" to "12:45"),
            6 to ("12:55" to "13:40"),
            7 to ("14:00" to "14:45"),
            8 to ("14:55" to "15:40"),
            9 to ("16:05" to "16:50"),
            10 to ("17:00" to "17:45"),
            11 to ("17:55" to "18:40"),
            12 to ("18:45" to "19:30"),
            13 to ("19:40" to "20:25"),
            14 to ("20:35" to "21:20"),
        )

        private val LEGACY_COLORS = intArrayOf(
            0xFFF8D2D7.toInt(),
            0xFFD2E5F8.toInt(),
            0xFFD2F0E5.toInt(),
            0xFFF8F3D2.toInt(),
            0xFFE5D2F8.toInt(),
            0xFFF8E5D2.toInt(),
            0xFFF2C6D0.toInt(),
            0xFFC6E0F2.toInt(),
            0xFFC6F2E0.toInt(),
            0xFFF2F0C6.toInt(),
            0xFFE0C6F2.toInt(),
            0xFFF2E0C6.toInt(),
            0xFFEBBFC9.toInt(),
            0xFFBFD8EB.toInt(),
            0xFFBFEBDC.toInt(),
            0xFFEBE8BF.toInt(),
            0xFFD8BFEB.toInt(),
            0xFFEBD8BF.toInt(),
            0xFFF6D9DF.toInt(),
            0xFFD9EAF6.toInt(),
            0xFFD9F6EC.toInt(),
            0xFFF6F4D9.toInt(),
            0xFFEAD9F6.toInt(),
            0xFFF6EAD9.toInt(),
        )

        private const val DEFAULT_COURSE_COLOR = 0xFF2655FE.toInt()

        private fun legacyTimeRange(startSession: Int, endSession: Int): Pair<String, String> {
            val start = LEGACY_TIME_SLOTS[startSession]?.first.orEmpty()
            val end = LEGACY_TIME_SLOTS[endSession]?.second.orEmpty()
            return start to end
        }

        private fun legacyColor(colorIndex: Int): Int {
            return if (colorIndex in LEGACY_COLORS.indices) {
                LEGACY_COLORS[colorIndex]
            } else {
                DEFAULT_COURSE_COLOR
            }
        }
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
    val courses: List<WidgetCourse>,
) {
    fun toJson(): String {
        val root = JSONObject()
        root.put("hasSchedule", hasSchedule)
        root.put("semesterStart", semesterStart ?: "")
        root.put("totalWeeks", totalWeeks)

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
