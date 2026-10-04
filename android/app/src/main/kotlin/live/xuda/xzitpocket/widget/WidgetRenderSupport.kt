package live.xuda.xzitpocket.widget

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.ColorRes
import androidx.annotation.LayoutRes
import live.xuda.xzitpocket.R
import java.io.File

internal object WidgetRenderSupport {
    private const val PLACEHOLDER_TEXT = " "
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val FLUTTER_DOUBLE_PREFIX =
        "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

    internal data class WidgetStyle(
        val fontScale: Float,
        val backgroundAlpha: Float,
        val textOpacity: Float,
        val backgroundColor: Int?,
        val backgroundImagePath: String?,
        val textColor: Int?,
        val hideTeacher: Boolean,
        val hideLocation: Boolean,
        val hideDate: Boolean,
    )

    fun readStyle(context: Context): WidgetStyle {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val useLightBackground = prefs.getBoolean(
            "flutter.widget_use_light_background_in_dark_mode",
            true,
        )
        val backgroundImagePath = if (
            WidgetThemeSupport.resolveThemeMode(context) == WidgetThemeMode.DARK &&
            !useLightBackground
        ) {
            prefs.getString("flutter.widget_dark_background_path", null)
        } else {
            prefs.getString("flutter.widget_background_path", null)
        }
        return WidgetStyle(
            fontScale = readFloat(prefs, "flutter.widget_font_scale", 1f)
                .coerceIn(0.5f, 2f),
            backgroundAlpha = readFloat(prefs, "flutter.widget_background_alpha", 1f)
                .coerceIn(0f, 1f),
            textOpacity = readFloat(prefs, "flutter.widget_text_opacity", 1f)
                .coerceIn(0f, 1f),
            backgroundColor = readColor(prefs, "flutter.widget_background_color"),
            backgroundImagePath = backgroundImagePath,
            textColor = readColor(prefs, "flutter.widget_text_color"),
            hideTeacher = prefs.getBoolean("flutter.widget_hide_teacher", false),
            hideLocation = prefs.getBoolean("flutter.widget_hide_location", false),
            hideDate = prefs.getBoolean("flutter.widget_hide_date", false),
        )
    }

    private fun readColor(
        prefs: android.content.SharedPreferences,
        key: String,
    ): Int? = (prefs.all[key] as? Number)?.toLong()?.toInt()

    private fun readFloat(
        prefs: android.content.SharedPreferences,
        key: String,
        defaultValue: Float,
    ): Float {
        return when (val value = prefs.all[key]) {
            is Number -> value.toFloat()
            is String -> value.removePrefix(FLUTTER_DOUBLE_PREFIX).toFloatOrNull() ?: defaultValue
            else -> defaultValue
        }
    }

    fun applyRootStyle(
        context: Context,
        views: RemoteViews,
    ): WidgetStyle {
        val style = readStyle(context)
        val backgroundBitmap = WidgetBackgroundImageCache.load(style.backgroundImagePath)
        setBackgroundResource(
            views,
            R.id.widget_background,
            if (backgroundBitmap == null) {
                WidgetThemeSupport.backgroundDrawableRes(context)
            } else {
                R.drawable.widget_background_image
            },
        )
        views.setImageViewResource(R.id.widget_background, android.R.color.transparent)
        backgroundBitmap?.let { bitmap ->
            views.setImageViewBitmap(R.id.widget_background, bitmap)
        }
        views.setFloat(R.id.widget_background, "setAlpha", style.backgroundAlpha)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setColorStateList(
                R.id.widget_background,
                "setBackgroundTintList",
                if (backgroundBitmap == null) {
                    style.backgroundColor?.let(ColorStateList::valueOf)
                } else {
                    null
                },
            )
        } else if (backgroundBitmap == null) {
            style.backgroundColor?.let { color ->
                views.setInt(R.id.widget_background, "setBackgroundColor", color)
            }
        }
        return style
    }

    fun applyTextScale(
        views: RemoteViews,
        style: WidgetStyle,
        vararg specs: TextSpec,
    ) {
        specs.forEach { spec ->
            views.setTextViewTextSize(
                spec.viewId,
                android.util.TypedValue.COMPLEX_UNIT_SP,
                spec.baseSizeSp * style.fontScale,
            )
            views.setFloat(spec.viewId, "setAlpha", style.textOpacity)
        }
    }

    data class TextSpec(val viewId: Int, val baseSizeSp: Float)

    fun applyDateVisibility(
        views: RemoteViews,
        style: WidgetStyle,
        vararg dateIds: Int,
    ) {
        dateIds.forEach { id ->
            views.setViewVisibility(id, if (style.hideDate) View.GONE else View.VISIBLE)
        }
    }

    fun courseDetails(course: WidgetCourse, style: WidgetStyle): String {
        val details = mutableListOf<String>()
        if (!style.hideLocation) {
            val location = listOf(course.campus, course.place)
                .filter { it.isNotBlank() }
                .joinToString(" ")
            if (location.isNotBlank()) details += location
        }
        if (!style.hideTeacher && course.teacher.isNotBlank()) {
            details += course.teacher
        }
        return details.joinToString(" · ")
    }

    fun setTextColor(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        @ColorRes colorResId: Int,
    ) {
        val color = readStyle(context).textColor
            ?: WidgetThemeSupport.color(context, colorResId)
        views.setInt(viewId, "setTextColor", color)
    }

    fun setHeaderDateText(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        text: String,
        adjusted: Boolean = false,
        markerOffset: Int = 0,
    ) {
        setTextColor(context, views, viewId, R.color.widget_sub_color)
        views.setTextViewText(
            viewId,
            adjustedDateText(context, text, adjusted, markerOffset),
        )
    }

    fun setTomorrowPreviewText(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        adjusted: Boolean = false,
    ) {
        setTextColor(context, views, viewId, R.color.widget_preview_blue)
        views.setTextViewText(
            viewId,
            adjustedDateText(
                context,
                context.getString(R.string.widget_tomorrow_preview),
                adjusted,
            ),
        )
    }

    fun adjustedDateText(
        context: Context,
        text: String,
        adjusted: Boolean,
        markerOffset: Int = 0,
    ): CharSequence {
        if (!adjusted) return text
        val offset = markerOffset.coerceIn(0, text.length)
        val marker = "【调】"
        return SpannableString(text.substring(0, offset) + marker + text.substring(offset)).apply {
            setSpan(
                ForegroundColorSpan(WidgetThemeSupport.primaryColor(context)),
                offset,
                offset + marker.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
        }
    }

    fun isAdjusted(snapshot: RenderSnapshot, date: String): Boolean =
        snapshot.adjustedDates.contains(date)

    fun weekLabel(snapshot: RenderSnapshot): String {
        return if (snapshot.hasSchedule && snapshot.currentWeek > 0) {
            "第${snapshot.currentWeek}周"
        } else if (snapshot.hasSchedule) {
            if (snapshot.isUpcoming) "未开学" else "已结课"
        } else {
            ""
        }
    }

    fun todayRemaining(snapshot: RenderSnapshot): List<WidgetCourse> {
        val today = WidgetTimeUtils.todayIsoDate()
        val nowMinutes = WidgetTimeUtils.nowMinutes()
        return snapshot.courses
            .filter { it.date == today }
            .filter {
                val endMinutes = WidgetTimeUtils.parseTimeToMinutes(it.endTime)
                endMinutes == null || endMinutes > nowMinutes
            }
            .sortedBy { it.sortOrder }
    }

    fun tomorrowCourses(snapshot: RenderSnapshot): List<WidgetCourse> {
        val tomorrow = WidgetTimeUtils.tomorrowIsoDate()
        return snapshot.courses
            .filter { it.date == tomorrow }
            .sortedBy { it.sortOrder }
    }

    fun showContent(
        views: RemoteViews,
        contentId: Int,
        statusId: Int,
    ) {
        views.setViewVisibility(contentId, View.VISIBLE)
        views.setViewVisibility(statusId, View.GONE)
    }

    fun showStatus(
        context: Context,
        views: RemoteViews,
        contentId: Int,
        statusId: Int,
        titleId: Int,
        subtitleId: Int,
        title: String,
        subtitle: String? = null,
    ) {
        views.setViewVisibility(contentId, View.GONE)
        views.setViewVisibility(statusId, View.VISIBLE)
        setTextColor(context, views, titleId, R.color.widget_sub_color)
        views.setTextViewText(titleId, title)

        if (subtitle.isNullOrBlank()) {
            views.setViewVisibility(subtitleId, View.GONE)
        } else {
            views.setViewVisibility(subtitleId, View.VISIBLE)
            setTextColor(context, views, subtitleId, R.color.widget_sub_color)
            views.setTextViewText(subtitleId, subtitle)
        }
    }

    fun setBackgroundResource(
        views: RemoteViews,
        viewId: Int,
        drawableResId: Int,
    ) {
        views.setInt(viewId, "setBackgroundResource", drawableResId)
    }

    fun showNotLoggedStatus(
        context: Context,
        views: RemoteViews,
        contentId: Int,
        statusId: Int,
        titleId: Int,
        subtitleId: Int,
    ) {
        showStatus(
            views = views,
            context = context,
            contentId = contentId,
            statusId = statusId,
            titleId = titleId,
            subtitleId = subtitleId,
            title = context.getString(R.string.widget_face_alert),
            subtitle = context.getString(R.string.widget_status_not_logged),
        )
    }

    fun showNoCoursesStatus(
        context: Context,
        views: RemoteViews,
        contentId: Int,
        statusId: Int,
        titleId: Int,
        subtitleId: Int,
    ) {
        showStatus(
            views = views,
            context = context,
            contentId = contentId,
            statusId = statusId,
            titleId = titleId,
            subtitleId = subtitleId,
            title = context.getString(R.string.widget_face_happy),
            subtitle = context.getString(R.string.widget_status_no_courses),
        )
    }

    fun showUpcomingStatus(
        context: Context,
        views: RemoteViews,
        contentId: Int,
        statusId: Int,
        titleId: Int,
        subtitleId: Int,
    ) {
        showStatus(
            views = views,
            context = context,
            contentId = contentId,
            statusId = statusId,
            titleId = titleId,
            subtitleId = subtitleId,
            title = context.getString(R.string.widget_face_upcoming),
            subtitle = context.getString(R.string.widget_status_upcoming),
        )
    }

    fun showSemesterFinishedStatus(
        context: Context,
        views: RemoteViews,
        contentId: Int,
        statusId: Int,
        titleId: Int,
        subtitleId: Int,
    ) {
        showStatus(
            views = views,
            context = context,
            contentId = contentId,
            statusId = statusId,
            titleId = titleId,
            subtitleId = subtitleId,
            title = context.getString(R.string.widget_face_finished),
            subtitle = context.getString(R.string.widget_status_finished_term),
        )
    }

    fun showOutOfTermStatus(
        context: Context,
        snapshot: RenderSnapshot,
        views: RemoteViews,
        contentId: Int,
        statusId: Int,
        titleId: Int,
        subtitleId: Int,
    ) {
        if (snapshot.isUpcoming) {
            showUpcomingStatus(
                context = context,
                views = views,
                contentId = contentId,
                statusId = statusId,
                titleId = titleId,
                subtitleId = subtitleId,
            )
        } else {
            showSemesterFinishedStatus(
                context = context,
                views = views,
                contentId = contentId,
                statusId = statusId,
                titleId = titleId,
                subtitleId = subtitleId,
            )
        }
    }

    fun buildCourseItem(
        context: Context,
        course: WidgetCourse,
        showExtra: Boolean,
        @LayoutRes itemLayoutRes: Int = R.layout.widget_course_item,
    ): RemoteViews {
        val item = RemoteViews(context.packageName, itemLayoutRes)
        val style = applyCourseItemStyle(context, item, itemLayoutRes)
        setBackgroundResource(
            item,
            R.id.course_item_root,
            WidgetThemeSupport.courseItemBackgroundDrawableRes(
                context,
                conflict = course.isConflict,
            ),
        )
        if (course.isConflict) {
            item.setViewVisibility(R.id.course_indicator, View.GONE)
        } else {
            item.setViewVisibility(R.id.course_indicator, View.VISIBLE)
            item.setInt(R.id.course_indicator, "setBackgroundColor", course.color)
            item.setFloat(R.id.course_indicator, "setAlpha", style.backgroundAlpha)
        }
        setTextColor(context, item, R.id.tv_course_title, R.color.widget_title_color)
        setTextColor(context, item, R.id.tv_course_meta, R.color.widget_sub_color)
        setTextColor(context, item, R.id.tv_course_extra, R.color.widget_hint_color)
        item.setTextViewText(R.id.tv_course_title, course.title)
        item.setTextViewText(
            R.id.tv_course_meta,
            "${course.startTime.take(5)}-${course.endTime.take(5)}",
        )

        val extra = courseDetails(course, style)
        if (showExtra && extra.isNotBlank()) {
            item.setViewVisibility(R.id.tv_course_extra, View.VISIBLE)
            item.setTextViewText(R.id.tv_course_extra, extra)
        } else {
            item.setViewVisibility(R.id.tv_course_extra, View.GONE)
        }
        return item
    }

    fun buildPlaceholderItem(
        context: Context,
        showExtra: Boolean,
        @LayoutRes itemLayoutRes: Int = R.layout.widget_course_item,
    ): RemoteViews {
        val item = RemoteViews(context.packageName, itemLayoutRes)
        applyCourseItemStyle(context, item, itemLayoutRes)
        setBackgroundResource(
            item,
            R.id.course_item_root,
            R.drawable.widget_course_item_background,
        )
        item.setViewVisibility(R.id.course_indicator, View.INVISIBLE)
        setTextColor(context, item, R.id.tv_course_title, R.color.widget_title_color)
        setTextColor(context, item, R.id.tv_course_meta, R.color.widget_sub_color)
        setTextColor(context, item, R.id.tv_course_extra, R.color.widget_hint_color)
        item.setTextViewText(R.id.tv_course_title, PLACEHOLDER_TEXT)
        item.setTextViewText(R.id.tv_course_meta, PLACEHOLDER_TEXT)

        if (showExtra) {
            item.setViewVisibility(R.id.tv_course_extra, View.VISIBLE)
            item.setTextViewText(R.id.tv_course_extra, PLACEHOLDER_TEXT)
        } else {
            item.setViewVisibility(R.id.tv_course_extra, View.GONE)
        }
        return item
    }

    private fun applyCourseItemStyle(
        context: Context,
        item: RemoteViews,
        @LayoutRes itemLayoutRes: Int,
    ): WidgetStyle {
        val style = readStyle(context)
        val sizes = if (itemLayoutRes == R.layout.widget_course_item_compact) {
            listOf(13f, 10f, 10f)
        } else {
            listOf(14f, 12f, 11f)
        }
        applyTextScale(
            item,
            style,
            TextSpec(R.id.tv_course_title, sizes[0]),
            TextSpec(R.id.tv_course_meta, sizes[1]),
            TextSpec(R.id.tv_course_extra, sizes[2]),
        )
        return style
    }

    fun fillVerticalContainer(
        context: Context,
        views: RemoteViews,
        containerId: Int,
        courses: List<WidgetCourse>,
        showExtra: Boolean,
        targetSlots: Int = courses.size,
        @LayoutRes itemLayoutRes: Int = R.layout.widget_course_item,
        @LayoutRes dividerLayoutRes: Int = R.layout.widget_divider_horizontal,
    ) {
        views.removeAllViews(containerId)
        val items = courses
            .map { buildCourseItem(context, it, showExtra, itemLayoutRes) }
            .toMutableList()

        repeat(maxOf(targetSlots - courses.size, 0)) {
            items.add(buildPlaceholderItem(context, showExtra, itemLayoutRes))
        }

        items.forEachIndexed { index, item ->
            views.addView(containerId, item)
            if (index != items.lastIndex) {
                val divider = RemoteViews(context.packageName, dividerLayoutRes)
                divider.setInt(
                    R.id.divider_root,
                    "setBackgroundColor",
                    WidgetThemeSupport.color(context, R.color.widget_divider_color),
                )
                views.addView(
                    containerId,
                    divider,
                )
            }
        }
    }

    fun fillSplitColumns(
        context: Context,
        views: RemoteViews,
        leftId: Int,
        rightId: Int,
        courses: List<WidgetCourse>,
        showExtra: Boolean,
        slotsPerColumn: Int = 0,
        @LayoutRes itemLayoutRes: Int = R.layout.widget_course_item,
        @LayoutRes dividerLayoutRes: Int = R.layout.widget_divider_horizontal,
    ) {
        views.removeAllViews(leftId)
        views.removeAllViews(rightId)

        val leftCourses = mutableListOf<WidgetCourse>()
        val rightCourses = mutableListOf<WidgetCourse>()
        courses.forEachIndexed { index, course ->
            if (index % 2 == 0) {
                leftCourses.add(course)
            } else {
                rightCourses.add(course)
            }
        }

        fillVerticalContainer(
            context,
            views,
            leftId,
            leftCourses,
            showExtra,
            targetSlots = if (slotsPerColumn > 0) slotsPerColumn else leftCourses.size,
            itemLayoutRes = itemLayoutRes,
            dividerLayoutRes = dividerLayoutRes,
        )
        fillVerticalContainer(
            context,
            views,
            rightId,
            rightCourses,
            showExtra,
            targetSlots = if (slotsPerColumn > 0) slotsPerColumn else rightCourses.size,
            itemLayoutRes = itemLayoutRes,
            dividerLayoutRes = dividerLayoutRes,
        )
    }

    fun attachRootClick(context: Context, views: RemoteViews) {
        views.setOnClickPendingIntent(R.id.widget_root, WidgetUpdateHelper.createLaunchPendingIntent(context))
    }

    fun applyPanelBackgrounds(
        context: Context,
        views: RemoteViews,
        conflict: Boolean = false,
    ) {
        val hasBackgroundImage = WidgetBackgroundImageCache
            .load(readStyle(context).backgroundImagePath) != null
        setBackgroundResource(
            views,
            R.id.widget_background,
            if (hasBackgroundImage) {
                R.drawable.widget_background_image
            } else {
                WidgetThemeSupport.backgroundDrawableRes(context, conflict)
            },
        )
    }
}

private object WidgetBackgroundImageCache {
    private const val MAX_DIMENSION = 1024
    private var cachedPath: String? = null
    private var cachedBitmap: Bitmap? = null

    @Synchronized
    fun load(path: String?): Bitmap? {
        if (path.isNullOrBlank()) {
            cachedPath = null
            cachedBitmap = null
            return null
        }
        if (path == cachedPath) return cachedBitmap
        val file = File(path)
        if (!file.isFile) {
            cachedPath = path
            cachedBitmap = null
            return null
        }

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sampleSize = 1
        while (
            bounds.outWidth / (sampleSize * 2) >= MAX_DIMENSION ||
            bounds.outHeight / (sampleSize * 2) >= MAX_DIMENSION
        ) {
            sampleSize *= 2
        }
        val decoded = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = Bitmap.Config.ARGB_8888
            },
        ) ?: return null
        val largestDimension = maxOf(decoded.width, decoded.height)
        val bitmap = if (largestDimension > MAX_DIMENSION) {
            val scale = MAX_DIMENSION.toFloat() / largestDimension
            Bitmap.createScaledBitmap(
                decoded,
                (decoded.width * scale).toInt().coerceAtLeast(1),
                (decoded.height * scale).toInt().coerceAtLeast(1),
                true,
            ).also { decoded.recycle() }
        } else {
            decoded
        }
        cachedPath = path
        cachedBitmap = bitmap
        return bitmap
    }
}
