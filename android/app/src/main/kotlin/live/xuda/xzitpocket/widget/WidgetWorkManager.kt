package live.xuda.xzitpocket.widget

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import live.xuda.xzitpocket.automation.ClassAutomationMode
import live.xuda.xzitpocket.automation.ClassAutomationPrefs
import java.util.concurrent.TimeUnit

internal object WorkManagerHelper {
    private const val UI_UPDATE_WORK_NAME = "xzit_widget_ui_update"
    private const val DATA_SYNC_WORK_NAME = "xzit_widget_data_sync"

    fun reconcilePeriodicWork(context: Context) {
        val hasWidgets = WidgetUpdateHelper.hasAnyWidgetInstances(context)
        val automationEnabled =
            ClassAutomationPrefs.getMode(context) != ClassAutomationMode.OFF

        if (hasWidgets) {
            scheduleUiUpdateWork(context)
        } else {
            cancelUniqueWork(context, UI_UPDATE_WORK_NAME)
        }

        if (hasWidgets || automationEnabled) {
            scheduleDataSyncWork(context)
        } else {
            cancelUniqueWork(context, DATA_SYNC_WORK_NAME)
        }
    }

    private fun scheduleUiUpdateWork(context: Context) {
        val workManager = WorkManager.getInstance(context)
        val uiUpdateWorkRequest = PeriodicWorkRequestBuilder<WidgetUiUpdateWorker>(
            15,
            TimeUnit.MINUTES,
        ).build()
        workManager.enqueueUniquePeriodicWork(
            UI_UPDATE_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            uiUpdateWorkRequest,
        )
    }

    private fun scheduleDataSyncWork(context: Context) {
        val workManager = WorkManager.getInstance(context)
        val dataSyncWorkRequest = PeriodicWorkRequestBuilder<WidgetDataSyncWorker>(
            1,
            TimeUnit.DAYS,
        ).build()
        workManager.enqueueUniquePeriodicWork(
            DATA_SYNC_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            dataSyncWorkRequest,
        )
    }

    private fun cancelUniqueWork(
        context: Context,
        workName: String,
    ) {
        WorkManager.getInstance(context).cancelUniqueWork(workName)
    }
}

class WidgetUiUpdateWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        WidgetUpdateHelper.updateAllWidgets(applicationContext)
        return Result.success()
    }
}

class WidgetDataSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        WidgetDataSynchronizer.syncNow(applicationContext)
        return Result.success()
    }
}
