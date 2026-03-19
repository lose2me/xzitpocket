package live.xuda.xzitpocket

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import live.xuda.xzitpocket.automation.ClassAutomationController
import live.xuda.xzitpocket.widget.WidgetDataSynchronizer
import live.xuda.xzitpocket.widget.WidgetUpdateHelper

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "live.xuda.xzitpocket/widget_bridge",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncWidgets" -> runBackgroundTask(result) {
                    WidgetDataSynchronizer.syncNow(applicationContext)
                }

                "refreshWidgets" -> runBackgroundTask(result) {
                    WidgetUpdateHelper.updateAllWidgets(applicationContext)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "live.xuda.xzitpocket/app_bridge",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "refreshClassAutomation" -> runBackgroundTask(result) {
                    ClassAutomationController.refreshNow(applicationContext)
                }

                "getAutomationPermissions" -> {
                    result.success(
                        mapOf(
                            "hasDndPermission" to
                                ClassAutomationController.hasDndPermission(applicationContext),
                            "hasExactAlarmPermission" to
                                ClassAutomationController.hasExactAlarmPermission(applicationContext),
                        ),
                    )
                }

                "openDndSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                    }
                    startActivity(intent)
                    result.success(null)
                }

                "openExactAlarmSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                    }
                    startActivity(intent)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun runBackgroundTask(
        result: MethodChannel.Result,
        task: () -> Unit,
    ) {
        Thread {
            try {
                task()
                runOnUiThread { result.success(null) }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("widget_bridge_error", e.message, null)
                }
            }
        }.start()
    }
}
