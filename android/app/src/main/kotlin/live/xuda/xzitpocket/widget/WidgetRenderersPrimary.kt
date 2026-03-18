package live.xuda.xzitpocket.widget

import android.view.View
import android.widget.RemoteViews
import live.xuda.xzitpocket.R

internal object TinyWidgetRenderer {
    fun render(context: android.content.Context, snapshot: RenderSnapshot): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_tiny)
        WidgetRenderSupport.attachRootClick(context, views)
        WidgetRenderSupport.setBackgroundResource(
            views,
            R.id.widget_root,
            R.drawable.widget_background,
        )

        when {
            !snapshot.hasSchedule -> {
                WidgetRenderSupport.showNotLoggedStatus(
                    context,
                    views,
                    R.id.container_content,
                    R.id.container_status,
                    R.id.tv_status_title,
                    R.id.tv_status_sub,
                )
            }

            snapshot.currentWeek == 0 -> {
                WidgetRenderSupport.showOutOfTermStatus(
                    context,
                    snapshot,
                    views,
                    R.id.container_content,
                    R.id.container_status,
                    R.id.tv_status_title,
                    R.id.tv_status_sub,
                )
            }

            else -> {
                val remainingToday = WidgetRenderSupport.todayRemaining(snapshot)
                val nextCourse = remainingToday.firstOrNull()
                if (nextCourse == null) {
                    WidgetRenderSupport.showNoCoursesStatus(
                        context,
                        views,
                        R.id.container_content,
                        R.id.container_status,
                        R.id.tv_status_title,
                        R.id.tv_status_sub,
                    )
                } else {
                    WidgetRenderSupport.showContent(
                        views,
                        R.id.container_content,
                        R.id.container_status,
                    )
                    WidgetRenderSupport.setBackgroundResource(
                        views,
                        R.id.widget_root,
                        if (nextCourse.isConflict) {
                            R.drawable.widget_background_conflict
                        } else {
                            R.drawable.widget_background
                        },
                    )
                    views.setTextViewText(R.id.tv_course_title, nextCourse.title)
                    views.setTextViewText(
                        R.id.tv_course_place,
                        listOf(nextCourse.campus, nextCourse.place)
                            .filter { it.isNotBlank() }
                            .joinToString(" "),
                    )
                    views.setTextViewText(
                        R.id.tv_course_time,
                        "${nextCourse.startTime.take(5)}-${nextCourse.endTime.take(5)}",
                    )
                }
            }
        }

        return views
    }
}

internal object CompactWidgetRenderer {
    fun render(context: android.content.Context, snapshot: RenderSnapshot): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_compact)
        WidgetRenderSupport.attachRootClick(context, views)
        views.setTextViewText(R.id.tv_week, WidgetRenderSupport.weekLabel(snapshot))
        WidgetRenderSupport.setHeaderDateText(
            context,
            views,
            R.id.tv_header_title,
            WidgetTimeUtils.todayDisplayDate(),
        )
        views.setViewVisibility(R.id.tv_footer, View.GONE)

        when {
            !snapshot.hasSchedule -> {
                WidgetRenderSupport.showNotLoggedStatus(
                    context,
                    views,
                    R.id.container_content,
                    R.id.container_status,
                    R.id.tv_status_title,
                    R.id.tv_status_sub,
                )
            }

            snapshot.currentWeek == 0 -> {
                WidgetRenderSupport.showOutOfTermStatus(
                    context,
                    snapshot,
                    views,
                    R.id.container_content,
                    R.id.container_status,
                    R.id.tv_status_title,
                    R.id.tv_status_sub,
                )
            }

            else -> {
                val remainingToday = WidgetRenderSupport.todayRemaining(snapshot)
                if (remainingToday.isNotEmpty()) {
                    WidgetRenderSupport.showContent(
                        views,
                        R.id.container_content,
                        R.id.container_status,
                    )
                    WidgetRenderSupport.setHeaderDateText(
                        context,
                        views,
                        R.id.tv_header_title,
                        WidgetTimeUtils.todayDisplayDate(),
                    )
                    WidgetRenderSupport.fillVerticalContainer(
                        context,
                        views,
                        R.id.container_courses,
                        remainingToday.take(2),
                        showExtra = true,
                        targetSlots = 2,
                        itemLayoutRes = R.layout.widget_course_item_compact,
                        dividerLayoutRes = R.layout.widget_divider_horizontal_compact,
                    )
                } else {
                    WidgetRenderSupport.showNoCoursesStatus(
                        context,
                        views,
                        R.id.container_content,
                        R.id.container_status,
                        R.id.tv_status_title,
                        R.id.tv_status_sub,
                    )
                }
            }
        }

        return views
    }
}

internal object ModerateWidgetRenderer {
    fun render(context: android.content.Context, snapshot: RenderSnapshot): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_moderate)
        WidgetRenderSupport.attachRootClick(context, views)
        views.setViewVisibility(R.id.tv_week, View.VISIBLE)
        views.setTextViewText(R.id.tv_week, WidgetRenderSupport.weekLabel(snapshot))
        WidgetRenderSupport.setHeaderDateText(
            context,
            views,
            R.id.tv_header_title,
            WidgetTimeUtils.todayDisplayDate(),
        )
        views.setViewVisibility(R.id.tv_footer, View.GONE)

        when {
            !snapshot.hasSchedule -> {
                WidgetRenderSupport.showNotLoggedStatus(
                    context,
                    views,
                    R.id.container_content,
                    R.id.container_status,
                    R.id.tv_status_title,
                    R.id.tv_status_sub,
                )
            }

            snapshot.currentWeek == 0 -> {
                WidgetRenderSupport.showOutOfTermStatus(
                    context,
                    snapshot,
                    views,
                    R.id.container_content,
                    R.id.container_status,
                    R.id.tv_status_title,
                    R.id.tv_status_sub,
                )
            }

            else -> {
                val remainingToday = WidgetRenderSupport.todayRemaining(snapshot)
                val tomorrowCourses = WidgetRenderSupport.tomorrowCourses(snapshot)
                when {
                    remainingToday.isNotEmpty() -> {
                        WidgetRenderSupport.showContent(
                            views,
                            R.id.container_content,
                            R.id.container_status,
                        )
                        WidgetRenderSupport.setHeaderDateText(
                            context,
                            views,
                            R.id.tv_header_title,
                            WidgetTimeUtils.todayDisplayDate(),
                        )
                        WidgetRenderSupport.fillSplitColumns(
                            context,
                            views,
                            R.id.container_left_column,
                            R.id.container_right_column,
                            remainingToday.take(4),
                            showExtra = true,
                            slotsPerColumn = 2,
                        )
                    }

                    tomorrowCourses.isNotEmpty() -> {
                        WidgetRenderSupport.showContent(
                            views,
                            R.id.container_content,
                            R.id.container_status,
                        )
                        WidgetRenderSupport.setTomorrowPreviewText(
                            context,
                            views,
                            R.id.tv_header_title,
                        )
                        WidgetRenderSupport.fillSplitColumns(
                            context,
                            views,
                            R.id.container_left_column,
                            R.id.container_right_column,
                            tomorrowCourses.take(4),
                            showExtra = true,
                            slotsPerColumn = 2,
                        )
                    }

                    else -> {
                        WidgetRenderSupport.showNoCoursesStatus(
                            context,
                            views,
                            R.id.container_content,
                            R.id.container_status,
                            R.id.tv_status_title,
                            R.id.tv_status_sub,
                        )
                    }
                }
            }
        }

        return views
    }
}
