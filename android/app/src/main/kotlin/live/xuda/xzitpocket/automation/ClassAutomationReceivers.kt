package live.xuda.xzitpocket.automation

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

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
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> ClassAutomationScheduler.enqueueWork(context)
        }
    }
}
