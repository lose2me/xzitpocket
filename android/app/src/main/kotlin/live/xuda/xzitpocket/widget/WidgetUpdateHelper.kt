package live.xuda.xzitpocket.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import live.xuda.xzitpocket.MainActivity

internal object WidgetUpdateHelper {
    private const val TAG = "WidgetUpdateHelper"

    private data class Binding(
        val providerClass: Class<out AppWidgetProvider>,
        val renderer: (Context, RenderSnapshot) -> RemoteViews,
    )

    private val bindings = listOf(
        Binding(TinyWidgetProvider::class.java, TinyWidgetRenderer::render),
        Binding(CompactWidgetProvider::class.java, CompactWidgetRenderer::render),
        Binding(ModerateWidgetProvider::class.java, ModerateWidgetRenderer::render),
        Binding(DoubleDaysWidgetProvider::class.java, DoubleDaysWidgetRenderer::render),
        Binding(LargeWidgetProvider::class.java, LargeWidgetRenderer::render),
    )

    fun updateAllWidgets(context: Context) {
        try {
            val storedSnapshot = WidgetPrefsRepository.readSnapshot(context)
            val renderSnapshot = RenderSnapshot(
                hasSchedule = storedSnapshot.hasSchedule,
                currentWeek = WidgetTimeUtils.calculateCurrentWeek(
                    storedSnapshot.semesterStart,
                    storedSnapshot.totalWeeks,
                ),
                isUpcoming = WidgetTimeUtils.isBeforeSemesterStart(
                    storedSnapshot.semesterStart,
                ),
                courses = storedSnapshot.courses,
            )

            val appWidgetManager = AppWidgetManager.getInstance(context)
            bindings.forEach { binding ->
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, binding.providerClass))
                if (ids.isEmpty()) return@forEach

                val remoteViews = binding.renderer(context, renderSnapshot)
                ids.forEach { id ->
                    appWidgetManager.updateAppWidget(id, remoteViews)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update widgets", e)
        }
    }

    fun hasAnyWidgetInstances(context: Context): Boolean {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        return bindings.any { binding ->
            appWidgetManager.getAppWidgetIds(ComponentName(context, binding.providerClass)).isNotEmpty()
        }
    }

    fun createLaunchPendingIntent(context: Context): PendingIntent {
        return HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("xzitpocket://timetable"),
        )
    }
}
