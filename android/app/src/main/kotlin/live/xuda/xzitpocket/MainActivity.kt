package live.xuda.xzitpocket

import android.app.Activity
import android.content.Intent
import android.Manifest
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import live.xuda.xzitpocket.automation.ClassAutomationController
import live.xuda.xzitpocket.widget.WidgetDataSynchronizer
import live.xuda.xzitpocket.widget.WidgetUpdateHelper
import live.xuda.xzitpocket.widget.CourseReminderScheduler
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val backgroundExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val widgetRefreshExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveFile: File? = null
    private val saveDocumentRequest = 9002

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Ask Android to schedule frames at the panel's high refresh rate when
        // available. Flutter still falls back automatically on 60 Hz devices.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            window.attributes = window.attributes.apply {
                preferredRefreshRate = 120f
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == saveDocumentRequest) {
            val result = pendingSaveResult
            val file = pendingSaveFile
            pendingSaveResult = null
            pendingSaveFile = null
            if (result == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null || file == null) {
                result.success(false)
                return
            }
            try {
                contentResolver.openOutputStream(uri)?.use { output ->
                    file.inputStream().use { input -> input.copyTo(output) }
                }
                result.success(true)
            } catch (error: Exception) {
                result.error("save_failed", error.message, null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        backgroundExecutor.shutdownNow()
        widgetRefreshExecutor.shutdownNow()
        super.onDestroy()
    }

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

                "refreshWidgets" -> runWidgetRefreshTask(result) {
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

                "refreshCourseReminders" -> runBackgroundTask(result) {
                    CourseReminderScheduler.refreshNow(applicationContext)
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            android.content.pm.PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            9001,
                        )
                    }
                    result.success(null)
                }

                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }

                "getCourseReminderPermissions" -> {
                    val powerManager =
                        getSystemService(android.os.PowerManager::class.java)
                    result.success(
                        mapOf(
                            "notificationsGranted" to
                                (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                                        android.content.pm.PackageManager.PERMISSION_GRANTED),
                            "exactAlarmGranted" to
                                ClassAutomationController.hasExactAlarmPermission(applicationContext),
                            "dndGranted" to
                                ClassAutomationController.hasDndPermission(applicationContext),
                            "batteryOptimizationIgnored" to
                                (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                                    powerManager?.isIgnoringBatteryOptimizations(packageName) == true),
                        ),
                    )
                }

                "openBackgroundAndAutostartSettings" -> {
                    openApplicationSettings()
                    result.success(null)
                }

                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(null)
                }

                "saveLocalFile" -> {
                    val path = call.argument<String>("path")
                    val fileName = call.argument<String>("fileName") ?: "document.pdf"
                    val mime = call.argument<String>("mime") ?: "application/pdf"
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "path is required", null)
                    } else {
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("missing_file", "file does not exist", null)
                        } else {
                            pendingSaveResult = result
                            pendingSaveFile = file
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = mime
                                putExtra(Intent.EXTRA_TITLE, fileName)
                            }
                            startActivityForResult(intent, saveDocumentRequest)
                        }
                    }
                }

                "openLocalFile" -> {
                    val path = call.argument<String>("path")
                    val mime = call.argument<String>("mime") ?: "application/pdf"
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "path is required", null)
                    } else {
                        try {
                            val file = File(path)
                            if (!file.exists()) {
                                result.error("missing_file", "file does not exist", null)
                            } else {
                                val uri = FileProvider.getUriForFile(
                                    this,
                                    "$packageName.fileprovider",
                                    file,
                                )
                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, mime)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            }
                        } catch (error: Exception) {
                            result.error("open_failed", error.message, null)
                        }
                    }
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
        val apkFile = File(filePath).canonicalFile
        val updatesRoot = File(filesDir, "updates").canonicalFile
        require(
            apkFile.path.startsWith(updatesRoot.path + File.separator) &&
                apkFile.extension.equals("apk", ignoreCase = true),
        ) { "更新包路径无效" }
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

    private fun openApplicationSettings() {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            },
        )
    }

    private fun openBatteryOptimizationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        }
        try {
            startActivity(intent)
        } catch (_: android.content.ActivityNotFoundException) {
            openApplicationSettings()
        }
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        }
        startActivity(intent)
    }

    private fun runBackgroundTask(
        result: MethodChannel.Result,
        task: () -> Unit,
    ) {
        backgroundExecutor.execute {
            try {
                task()
                runOnUiThread { result.success(null) }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("widget_bridge_error", e.message, null)
                }
            }
        }
    }

    private fun runWidgetRefreshTask(
        result: MethodChannel.Result,
        task: () -> Unit,
    ) {
        widgetRefreshExecutor.execute {
            try {
                task()
                runOnUiThread { result.success(null) }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("widget_refresh_error", e.message, null)
                }
            }
        }
    }
}
