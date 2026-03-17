package live.xuda.xzitpocket.widget

import android.content.Context
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.ColorRes
import androidx.annotation.LayoutRes
import androidx.core.content.ContextCompat
import live.xuda.xzitpocket.R

internal object WidgetRenderSupport {
    private const val PLACEHOLDER_TEXT = " "

    fun setTextColor(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        @ColorRes colorResId: Int,
    ) {
        views.setInt(viewId, "setTextColor", ContextCompat.getColor(context, colorResId))
    }

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

    fun hasCoursesToday(snapshot: RenderSnapshot): Boolean {
        return snapshot.courses.any { it.date == WidgetTimeUtils.todayIsoDate() }
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
        @ColorRes titleColorRes: Int = R.color.widget_title_color,
        @ColorRes subtitleColorRes: Int = R.color.widget_sub_color,
    ) {
        views.setViewVisibility(contentId, View.GONE)
        views.setViewVisibility(statusId, View.VISIBLE)
        setTextColor(context, views, titleId, titleColorRes)
        setTextColor(context, views, subtitleId, subtitleColorRes)
        views.setTextViewText(titleId, title)

        if (subtitle.isNullOrBlank()) {
            views.setViewVisibility(subtitleId, View.GONE)
        } else {
            views.setViewVisibility(subtitleId, View.VISIBLE)
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
            context = context,
            views = views,
            contentId = contentId,
            statusId = statusId,
            titleId = titleId,
            subtitleId = subtitleId,
            title = context.getString(R.string.widget_face_alert),
            subtitle = context.getString(R.string.widget_status_not_logged),
            titleColorRes = R.color.widget_sub_color,
            subtitleColorRes = R.color.widget_sub_color,
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
            context = context,
            views = views,
            contentId = contentId,
            statusId = statusId,
            titleId = titleId,
            subtitleId = subtitleId,
            title = context.getString(R.string.widget_face_happy),
            subtitle = context.getString(R.string.widget_status_no_courses),
            titleColorRes = R.color.widget_sub_color,
            subtitleColorRes = R.color.widget_sub_color,
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
            context = context,
            views = views,
            contentId = contentId,
            statusId = statusId,
            titleId = titleId,
            subtitleId = subtitleId,
            title = context.getString(R.string.widget_face_upcoming),
            subtitle = context.getString(R.string.widget_status_upcoming),
            titleColorRes = R.color.widget_sub_color,
            subtitleColorRes = R.color.widget_sub_color,
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
            context = context,
            views = views,
            contentId = contentId,
            statusId = statusId,
            titleId = titleId,
            subtitleId = subtitleId,
            title = context.getString(R.string.widget_face_finished),
            subtitle = context.getString(R.string.widget_status_finished_term),
            titleColorRes = R.color.widget_sub_color,
            subtitleColorRes = R.color.widget_sub_color,
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
        setBackgroundResource(
            item,
            R.id.course_item_root,
            if (course.isConflict) {
                R.drawable.widget_course_item_conflict_background
            } else {
                R.drawable.widget_course_item_background
            },
        )
        if (course.isConflict) {
            item.setViewVisibility(R.id.course_indicator, View.GONE)
        } else {
            item.setViewVisibility(R.id.course_indicator, View.VISIBLE)
            item.setInt(R.id.course_indicator, "setBackgroundColor", course.color)
        }
        item.setTextViewText(R.id.tv_course_title, course.title)
        item.setTextViewText(
            R.id.tv_course_meta,
            "${course.startTime.take(5)}-${course.endTime.take(5)}",
        )

        val extra = listOf(course.campus, course.place)
            .filter { it.isNotBlank() }
            .joinToString(" ")
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
        setBackgroundResource(
            item,
            R.id.course_item_root,
            R.drawable.widget_course_item_background,
        )
        item.setViewVisibility(R.id.course_indicator, View.INVISIBLE)
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
                views.addView(
                    containerId,
                    RemoteViews(context.packageName, dividerLayoutRes),
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
}
