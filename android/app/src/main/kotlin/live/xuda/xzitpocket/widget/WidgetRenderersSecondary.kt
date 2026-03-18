package live.xuda.xzitpocket.widget

import android.view.View
import android.widget.RemoteViews
import live.xuda.xzitpocket.R

internal object DoubleDaysWidgetRenderer {
    fun render(context: android.content.Context, snapshot: RenderSnapshot): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_double_days)
        WidgetRenderSupport.attachRootClick(context, views)
        views.setViewVisibility(R.id.tv_week, View.GONE)
        views.setViewVisibility(R.id.tv_today_footer, View.GONE)
        views.setViewVisibility(R.id.tv_tomorrow_footer, View.GONE)
        views.setTextViewText(
            R.id.tv_today_title,
            "${context.getString(R.string.widget_title_today)} ${WidgetTimeUtils.todayDisplayDate()}",
        )
        views.setTextViewText(
            R.id.tv_tomorrow_title,
            "${context.getString(R.string.widget_title_tomorrow)} ${WidgetTimeUtils.tomorrowDisplayDate()}",
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
                WidgetRenderSupport.showContent(
                    views,
                    R.id.container_content,
                    R.id.container_status,
                )

                val remainingToday = WidgetRenderSupport.todayRemaining(snapshot)
                val tomorrowCourses = WidgetRenderSupport.tomorrowCourses(snapshot)

                if (remainingToday.isEmpty()) {
                    views.setViewVisibility(R.id.container_today, View.GONE)
                    views.setViewVisibility(R.id.tv_empty_today, View.VISIBLE)
                    views.setViewVisibility(R.id.tv_today_footer, View.GONE)
                    WidgetRenderSupport.setTextColor(
                        context,
                        views,
                        R.id.tv_empty_today,
                        R.color.widget_sub_color,
                    )
                    views.setTextViewText(
                        R.id.tv_empty_today,
                        context.getString(R.string.widget_empty_today_friendly),
                    )
                } else {
                    views.setViewVisibility(R.id.container_today, View.VISIBLE)
                    views.setViewVisibility(R.id.tv_empty_today, View.GONE)
                    views.setViewVisibility(R.id.tv_today_footer, View.GONE)
                    WidgetRenderSupport.fillVerticalContainer(
                        context,
                        views,
                        R.id.container_today,
                        remainingToday.take(2),
                        showExtra = false,
                        targetSlots = 2,
                        itemLayoutRes = R.layout.widget_course_item_compact,
                        dividerLayoutRes = R.layout.widget_divider_horizontal_compact,
                    )
                }

                if (tomorrowCourses.isEmpty()) {
                    views.setViewVisibility(R.id.container_tomorrow, View.GONE)
                    views.setViewVisibility(R.id.tv_empty_tomorrow, View.VISIBLE)
                    views.setViewVisibility(R.id.tv_tomorrow_footer, View.GONE)
                    WidgetRenderSupport.setTextColor(
                        context,
                        views,
                        R.id.tv_empty_tomorrow,
                        R.color.widget_sub_color,
                    )
                    views.setTextViewText(
                        R.id.tv_empty_tomorrow,
                        context.getString(R.string.widget_empty_tomorrow_friendly),
                    )
                } else {
                    views.setViewVisibility(R.id.container_tomorrow, View.VISIBLE)
                    views.setViewVisibility(R.id.tv_empty_tomorrow, View.GONE)
                    views.setViewVisibility(R.id.tv_tomorrow_footer, View.GONE)
                    WidgetRenderSupport.fillVerticalContainer(
                        context,
                        views,
                        R.id.container_tomorrow,
                        tomorrowCourses.take(2),
                        showExtra = false,
                        targetSlots = 2,
                        itemLayoutRes = R.layout.widget_course_item_compact,
                        dividerLayoutRes = R.layout.widget_divider_horizontal_compact,
                    )
                }
            }
        }

        return views
    }
}

internal object LargeWidgetRenderer {
    fun render(context: android.content.Context, snapshot: RenderSnapshot): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_large)
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
                            remainingToday.take(6),
                            showExtra = true,
                            slotsPerColumn = 3,
                            itemLayoutRes = R.layout.widget_course_item_large,
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
                            tomorrowCourses.take(6),
                            showExtra = true,
                            slotsPerColumn = 3,
                            itemLayoutRes = R.layout.widget_course_item_large,
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
