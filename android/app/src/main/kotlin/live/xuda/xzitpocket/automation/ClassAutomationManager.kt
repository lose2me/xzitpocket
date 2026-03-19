package live.xuda.xzitpocket.automation

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import androidx.core.content.getSystemService
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import live.xuda.xzitpocket.widget.WidgetCourse
import live.xuda.xzitpocket.widget.WidgetDataSynchronizer
import live.xuda.xzitpocket.widget.WidgetPrefsRepository
import live.xuda.xzitpocket.widget.WidgetUpdateHelper
import live.xuda.xzitpocket.widget.WorkManagerHelper
import java.text.SimpleDateFormat
import java.util.Locale

internal enum class ClassAutomationMode(val value: String) {
    OFF("off"),
    DND("dnd"),
    DND_KEEP("dnd_keep"),
    SILENT("silent"),
    SILENT_KEEP("silent_keep"),
    ;

    val isSticky: Boolean
        get() = this == DND_KEEP || this == SILENT_KEEP

    companion object {
        fun fromValue(value: String?): ClassAutomationMode {
            return entries.firstOrNull { it.value == value } ?: OFF
        }
    }
}

internal object ClassAutomationPrefs {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_MODE = "flutter.class_automation_mode"

    private const val INTERNAL_PREFS = "class_automation_internal"
    private const val KEY_IS_ACTIVE = "is_active"
    private const val KEY_ACTIVE_MODE = "active_mode"
    private const val KEY_PREVIOUS_INTERRUPTION_FILTER = "previous_interruption_filter"
    private const val KEY_PREVIOUS_RINGER_MODE = "previous_ringer_mode"

    fun getMode(context: Context): ClassAutomationMode {
        val value = context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(KEY_MODE, ClassAutomationMode.OFF.value)
        return ClassAutomationMode.fromValue(value)
    }

    fun isActive(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_IS_ACTIVE, false)
    }

    fun getActiveMode(context: Context): ClassAutomationMode? {
        if (!isActive(context)) return null
        val value = prefs(context).getString(KEY_ACTIVE_MODE, null) ?: return null
        return ClassAutomationMode.fromValue(value)
    }

    fun setActive(
        context: Context,
        mode: ClassAutomationMode,
        previousInterruptionFilter: Int,
        previousRingerMode: Int,
    ) {
        prefs(context).edit()
            .putBoolean(KEY_IS_ACTIVE, true)
            .putString(KEY_ACTIVE_MODE, mode.value)
            .putInt(KEY_PREVIOUS_INTERRUPTION_FILTER, previousInterruptionFilter)
            .putInt(KEY_PREVIOUS_RINGER_MODE, previousRingerMode)
            .apply()
    }

    fun clearActive(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_IS_ACTIVE, false)
            .remove(KEY_ACTIVE_MODE)
            .remove(KEY_PREVIOUS_INTERRUPTION_FILTER)
            .remove(KEY_PREVIOUS_RINGER_MODE)
            .apply()
    }

    fun previousInterruptionFilter(context: Context): Int {
        return prefs(context).getInt(
            KEY_PREVIOUS_INTERRUPTION_FILTER,
            NotificationManager.INTERRUPTION_FILTER_ALL,
        )
    }

    fun previousRingerMode(context: Context): Int {
        return prefs(context).getInt(
            KEY_PREVIOUS_RINGER_MODE,
            AudioManager.RINGER_MODE_NORMAL,
        )
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(INTERNAL_PREFS, Context.MODE_PRIVATE)
}

private data class ClassInterval(
    val startMillis: Long,
    val endMillis: Long,
)

internal object ClassAutomationScheduler {
    private const val WORK_NAME = "xzit_class_automation_sync"

    fun enqueueWork(context: Context) {
        WorkManager.getInstance(context).enqueueUniqueWork(
            WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<ClassAutomationSyncWorker>().build(),
        )
    }
}

class ClassAutomationSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        ClassAutomationController.refreshNow(applicationContext)
        return Result.success()
    }
}

internal object ClassAutomationController {
    private const val ACTION_CLASS_AUTOMATION = "live.xuda.xzitpocket.action.CLASS_AUTOMATION"
    const val EXTRA_BOUNDARY_ACTION = "boundary_action"
    const val BOUNDARY_ACTION_START = "start"
    const val BOUNDARY_ACTION_END = "end"

    private const val REQUEST_START = 62001
    private const val REQUEST_END = 62002
    private val DATE_TIME_FORMAT = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US)

    fun refreshNow(context: Context) {
        WorkManagerHelper.reconcilePeriodicWork(context)
        if (WidgetDataSynchronizer.refreshSnapshotIfNeeded(context)) {
            WidgetUpdateHelper.updateAllWidgets(context)
        }

        val mode = ClassAutomationPrefs.getMode(context)
        if (mode == ClassAutomationMode.OFF) {
            cancelScheduledAlarms(context)
            deactivateIfNeeded(context)
            return
        }

        val intervals = buildIntervals(context)
        val now = System.currentTimeMillis()
        val currentInterval = intervals.firstOrNull { now >= it.startMillis && now < it.endMillis }

        if (currentInterval != null) {
            activateForCurrentMode(context, mode)
        } else {
            if (!mode.isSticky) {
                deactivateIfNeeded(context)
            }
        }

        cancelScheduledAlarms(context)
        if (!hasExactAlarmPermission(context)) return

        scheduleNextBoundary(context, intervals, now, BOUNDARY_ACTION_START)
        if (!mode.isSticky) {
            scheduleNextBoundary(context, intervals, now, BOUNDARY_ACTION_END)
        }
    }

    fun handleBoundary(
        context: Context,
        boundaryAction: String?,
    ) {
        when (boundaryAction) {
            BOUNDARY_ACTION_START -> {
                val mode = ClassAutomationPrefs.getMode(context)
                if (mode != ClassAutomationMode.OFF) {
                    activateForCurrentMode(context, mode)
                }
            }

            BOUNDARY_ACTION_END -> deactivateIfNeeded(context)
        }

        ClassAutomationScheduler.enqueueWork(context)
    }

    fun hasDndPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val notificationManager = context.getSystemService<NotificationManager>()
        return notificationManager?.isNotificationPolicyAccessGranted ?: false
    }

    fun hasExactAlarmPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService<AlarmManager>()
        return alarmManager?.canScheduleExactAlarms() ?: false
    }

    private fun activateForCurrentMode(
        context: Context,
        mode: ClassAutomationMode,
    ) {
        if (!hasDndPermission(context)) return

        val activeMode = ClassAutomationPrefs.getActiveMode(context)
        if (activeMode == mode) return

        if (activeMode != null) {
            applyMode(context, false, activeMode)
            ClassAutomationPrefs.clearActive(context)
        }

        val notificationManager = context.getSystemService<NotificationManager>() ?: return
        val audioManager = context.getSystemService<AudioManager>() ?: return
        val previousInterruptionFilter = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationManager.currentInterruptionFilter
        } else {
            NotificationManager.INTERRUPTION_FILTER_ALL
        }
        val previousRingerMode = audioManager.ringerMode
        if (!applyMode(context, true, mode)) return

        ClassAutomationPrefs.setActive(
            context,
            mode,
            previousInterruptionFilter = previousInterruptionFilter,
            previousRingerMode = previousRingerMode,
        )
    }

    private fun deactivateIfNeeded(context: Context) {
        val activeMode = ClassAutomationPrefs.getActiveMode(context) ?: return
        applyMode(context, false, activeMode)
        ClassAutomationPrefs.clearActive(context)
    }

    private fun applyMode(
        context: Context,
        enable: Boolean,
        mode: ClassAutomationMode,
    ): Boolean {
        val notificationManager = context.getSystemService<NotificationManager>() ?: return false
        val audioManager = context.getSystemService<AudioManager>() ?: return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !notificationManager.isNotificationPolicyAccessGranted
        ) {
            return false
        }

        when (mode) {
            ClassAutomationMode.OFF -> return false

            ClassAutomationMode.DND,
            ClassAutomationMode.DND_KEEP,
            -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
                notificationManager.setInterruptionFilter(
                    if (enable) {
                        NotificationManager.INTERRUPTION_FILTER_PRIORITY
                    } else {
                        ClassAutomationPrefs.previousInterruptionFilter(context)
                    },
                )
            }

            ClassAutomationMode.SILENT,
            ClassAutomationMode.SILENT_KEEP,
            -> {
                audioManager.ringerMode = if (enable) {
                    AudioManager.RINGER_MODE_SILENT
                } else {
                    ClassAutomationPrefs.previousRingerMode(context)
                }
            }
        }

        return true
    }

    private fun scheduleNextBoundary(
        context: Context,
        intervals: List<ClassInterval>,
        now: Long,
        boundaryAction: String,
    ) {
        val triggerAtMillis = when (boundaryAction) {
            BOUNDARY_ACTION_START -> intervals
                .firstOrNull { it.startMillis > now }
                ?.startMillis

            BOUNDARY_ACTION_END -> intervals
                .firstOrNull { it.endMillis > now }
                ?.endMillis

            else -> null
        } ?: return

        val alarmManager = context.getSystemService<AlarmManager>() ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            return
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            if (boundaryAction == BOUNDARY_ACTION_START) REQUEST_START else REQUEST_END,
            Intent(context, ClassAutomationAlarmReceiver::class.java).apply {
                action = ACTION_CLASS_AUTOMATION
                putExtra(EXTRA_BOUNDARY_ACTION, boundaryAction)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            pendingIntent,
        )
    }

    private fun cancelScheduledAlarms(context: Context) {
        val alarmManager = context.getSystemService<AlarmManager>() ?: return
        listOf(REQUEST_START to BOUNDARY_ACTION_START, REQUEST_END to BOUNDARY_ACTION_END)
            .forEach { (requestCode, action) ->
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    Intent(context, ClassAutomationAlarmReceiver::class.java).apply {
                        this.action = ACTION_CLASS_AUTOMATION
                        putExtra(EXTRA_BOUNDARY_ACTION, action)
                    },
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
                )
                pendingIntent?.let {
                    alarmManager.cancel(it)
                    it.cancel()
                }
            }
    }

    private fun buildIntervals(context: Context): List<ClassInterval> {
        val snapshot = WidgetPrefsRepository.readSnapshot(context)
        val rawIntervals = snapshot.courses
            .mapNotNull(::courseToInterval)
            .sortedBy { it.startMillis }

        if (rawIntervals.isEmpty()) return emptyList()

        val merged = mutableListOf<ClassInterval>()
        rawIntervals.forEach { interval ->
            val last = merged.lastOrNull()
            if (last == null || interval.startMillis > last.endMillis) {
                merged.add(interval)
            } else {
                merged[merged.lastIndex] = last.copy(
                    endMillis = maxOf(last.endMillis, interval.endMillis),
                )
            }
        }
        return merged
    }

    private fun courseToInterval(course: WidgetCourse): ClassInterval? {
        val start = parseDateTime(course.date, course.startTime) ?: return null
        val end = parseDateTime(course.date, course.endTime) ?: return null
        if (end <= start) return null
        return ClassInterval(startMillis = start, endMillis = end)
    }

    private fun parseDateTime(
        date: String,
        time: String,
    ): Long? {
        return try {
            synchronized(DATE_TIME_FORMAT) {
                DATE_TIME_FORMAT.parse("$date ${time.take(5)}")?.time
            }
        } catch (_: Exception) {
            null
        }
    }
}
