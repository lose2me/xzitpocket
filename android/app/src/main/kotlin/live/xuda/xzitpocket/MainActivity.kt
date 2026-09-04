package live.xuda.xzitpocket

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import live.xuda.xzitpocket.automation.ClassAutomationController
import live.xuda.xzitpocket.widget.WidgetDataSynchronizer
import live.xuda.xzitpocket.widget.WidgetUpdateHelper
import java.io.File

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

                "canRequestPackageInstalls" -> {
                    result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls(),
                    )
                }

                "openInstallUnknownSourcesSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                        }
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                    }
                    startActivity(intent)
                    result.success(null)
                }

                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("install_apk_error", "APK 路径为空", null)
                    } else {
                        try {
                            installApk(filePath)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("install_apk_error", error.message, null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(filePath: String) {
        val apkFile = File(filePath)
        require(apkFile.exists()) { "更新包不存在" }
        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile,
        )
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
        )
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
