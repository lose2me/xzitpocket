package live.xuda.xzitpocket.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

private object WidgetTaskRunner {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    fun run(task: () -> Unit) {
        executor.execute(task)
    }
}

abstract class BaseScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        WidgetTaskRunner.run {
            WidgetUpdateHelper.updateAllWidgets(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WorkManagerHelper.reconcilePeriodicWork(context)
        WidgetTaskRunner.run {
            WidgetDataSynchronizer.syncNow(context)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetTaskRunner.run {
            WorkManagerHelper.reconcilePeriodicWork(context)
        }
    }
}

class TinyWidgetProvider : BaseScheduleWidgetProvider()

class CompactWidgetProvider : BaseScheduleWidgetProvider()

class ModerateWidgetProvider : BaseScheduleWidgetProvider()

class DoubleDaysWidgetProvider : BaseScheduleWidgetProvider()

class LargeWidgetProvider : BaseScheduleWidgetProvider()
