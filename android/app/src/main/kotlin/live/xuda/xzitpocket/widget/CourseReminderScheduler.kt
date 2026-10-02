package live.xuda.xzitpocket.widget

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import live.xuda.xzitpocket.MainActivity
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

internal object CourseReminderScheduler {
    private const val WORK_NAME = "xzit_course_reminder_sync"
    private const val REQUEST_BASE = 51000
    private const val REQUEST_COUNT = 100

    fun enqueueWork(context: Context) {
        WorkManager.getInstance(context).enqueueUniqueWork(
            WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<CourseReminderWorker>().build(),
        )
    }

    internal fun refreshNow(context: Context) {
        WorkManagerHelper.reconcilePeriodicWork(context)
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        cancelAlarms(context, alarmManager)

        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        if (!prefs.getBoolean("flutter.course_reminder_enabled", false)) return

        val minutes = prefs.getInt("flutter.course_reminder_minutes", 15).coerceIn(1, 60)
        val snapshot = WidgetPrefsRepository.readSnapshot(context)
        val now = System.currentTimeMillis()
        val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US)
        var slot = 0
        snapshot.courses
            .asSequence()
            .sortedWith(compareBy({ it.date }, { it.startTime }, { it.title }))
            .forEach { course ->
                if (slot >= REQUEST_COUNT) return@forEach
                val start = runCatching {
                    dateFormat.parse("${course.date} ${course.startTime}")?.time
                }.getOrNull() ?: return@forEach
                val triggerAt = start - minutes * 60_000L
                if (triggerAt <= now) return@forEach
                val requestCode = REQUEST_BASE + slot++
                val intent = Intent(context, CourseReminderReceiver::class.java).apply {
                    action = ACTION_REMINDER
                    putExtra(EXTRA_REQUEST_CODE, requestCode)
                    putExtra(EXTRA_COURSE_ID, course.id)
                    putExtra(EXTRA_TITLE, course.title)
                    putExtra(EXTRA_PLACE, course.place)
                    putExtra(EXTRA_TEACHER, "")
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                val exactAlarmsAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                    alarmManager.canScheduleExactAlarms()
                if (exactAlarmsAllowed) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                } else {
                    // Android 12+ may deny exact alarms. Keep reminders useful
                    // with an inexact idle-safe alarm instead of dropping them.
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                }
            }
    }

    private fun cancelAlarms(context: Context, alarmManager: AlarmManager) {
        repeat(REQUEST_COUNT) { index ->
            val requestCode = REQUEST_BASE + index
            val intent = Intent(context, CourseReminderReceiver::class.java).apply {
                action = ACTION_REMINDER
            }
            PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )?.let {
                alarmManager.cancel(it)
                it.cancel()
            }
        }
    }
}

internal class CourseReminderWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        CourseReminderScheduler.refreshNow(applicationContext)
        return Result.success()
    }
}

internal const val ACTION_REMINDER = "live.xuda.xzitpocket.action.COURSE_REMINDER"
internal const val EXTRA_REQUEST_CODE = "request_code"
internal const val EXTRA_COURSE_ID = "course_id"
internal const val EXTRA_TITLE = "course_title"
internal const val EXTRA_PLACE = "course_place"
internal const val EXTRA_TEACHER = "course_teacher"
private const val CHANNEL_ID = "course_reminders"

internal class CourseReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val notificationManager =
            context.getSystemService(NotificationManager::class.java) ?: return
        if (intent?.action == ACTION_DISMISS) {
            notificationManager.cancel(intent.getIntExtra(EXTRA_REQUEST_CODE, 0))
            return
        }
        if (intent?.action != ACTION_REMINDER) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "课程提醒",
            NotificationManager.IMPORTANCE_HIGH,
        )
        notificationManager.createNotificationChannel(channel)

        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        val compatibility = prefs.getBoolean(
            "flutter.wearable_notification_compatibility",
            false,
        )
        val requestCode = intent.getIntExtra(EXTRA_REQUEST_CODE, 0)
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty().ifBlank { "即将上课" }
        val place = intent.getStringExtra(EXTRA_PLACE).orEmpty()
        val dismissIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            Intent(context, CourseReminderReceiver::class.java).apply {
                action = ACTION_DISMISS
                putExtra(EXTRA_REQUEST_CODE, requestCode)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(if (place.isBlank()) "课程即将开始" else place)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setShowWhen(true)
            .setOngoing(!compatibility)
            .setAutoCancel(compatibility)
            .setRequestPromotedOngoing(!compatibility)
            .setShortCriticalText(title)
            .addAction(0, "关闭", dismissIntent)
            .setContentIntent(
                PendingIntent.getActivity(
                    context,
                    requestCode,
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        notificationManager.notify(requestCode, builder.build())
        CourseReminderScheduler.enqueueWork(context)
    }

    companion object {
        private const val ACTION_DISMISS =
            "live.xuda.xzitpocket.action.DISMISS_COURSE_REMINDER"
    }
}
