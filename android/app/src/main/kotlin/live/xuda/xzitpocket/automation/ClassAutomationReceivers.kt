package live.xuda.xzitpocket.automation

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import live.xuda.xzitpocket.widget.CourseReminderScheduler

class ClassAutomationAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent?,
    ) {
        ClassAutomationController.handleBoundary(
            context,
            intent?.getStringExtra(ClassAutomationController.EXTRA_BOUNDARY_ACTION),
        )
    }
}

class ClassAutomationBootReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent?,
    ) {
        val action = intent?.action
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            -> {
                // WorkManager is useful for periodic maintenance, but it may
                // legally defer a one-shot request. A clock/date change needs
                // the RTC alarms rebuilt immediately or a reminder can remain
                // attached to the old wall-clock timestamp.
                val pendingResult = goAsync()
                val appContext = context.applicationContext
                Thread {
                    try {
                        ClassAutomationController.refreshNow(appContext)
                        CourseReminderScheduler.refreshNow(appContext)
                    } finally {
                        pendingResult.finish()
                    }
                }.start()
            }
        }
    }
}
