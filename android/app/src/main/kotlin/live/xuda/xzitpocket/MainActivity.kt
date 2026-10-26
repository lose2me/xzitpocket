package live.xuda.xzitpocket

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.Manifest
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
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

    private var pendingDownloadsResult: MethodChannel.Result? = null
    private var pendingDownloadsFile: File? = null
    private var pendingDownloadsName: String? = null
    private var pendingDownloadsMime: String? = null
    private val downloadsPermissionRequest = 9003

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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == downloadsPermissionRequest) {
            val result = pendingDownloadsResult
            val file = pendingDownloadsFile
            val name = pendingDownloadsName
            val mime = pendingDownloadsMime
            pendingDownloadsResult = null
            pendingDownloadsFile = null
            pendingDownloadsName = null
            pendingDownloadsMime = null
            if (result == null || file == null || name == null || mime == null) {
                super.onRequestPermissionsResult(requestCode, permissions, grantResults)
                return
            }
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                runCatching { saveToDownloads(file, name, mime) }
                    .onSuccess { result.success(it) }
                    .onFailure { result.error("save_failed", it.message, null) }
            } else {
                result.error("permission_denied", "storage permission denied", null)
            }
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        backgroundExecutor.shutdownNow()
        widgetRefreshExecutor.shutdownNow()
        super.onDestroy()
    }

    /// Copies [file] into the public Downloads folder and returns its display
    /// path, e.g. "Download/试卷.pdf". Android 10+ uses MediaStore so no
    /// permission is needed and the file shows up in the Downloads app.
    private fun saveToDownloads(file: File, fileName: String, mime: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = contentResolver.insert(collection, values)
                ?: throw IllegalStateException("无法创建下载文件")
            try {
                contentResolver.openOutputStream(uri)?.use { output ->
                    file.inputStream().use { input -> input.copyTo(output) }
                } ?: throw IllegalStateException("无法写入下载文件")
            } catch (error: Exception) {
                contentResolver.delete(uri, null, null)
                throw error
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            val actual = contentResolver
                .query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
                ?: fileName
            return "${Environment.DIRECTORY_DOWNLOADS}/$actual"
        }

        if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("storage permission denied")
        }
        @Suppress("DEPRECATION")
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!dir.exists() && !dir.mkdirs()) throw IllegalStateException("无法创建下载目录")
        val base = fileName.substringBeforeLast('.', fileName)
        val extension = fileName.substringAfterLast('.', "")
        var target = File(dir, fileName)
        var index = 1
        while (target.exists()) {
            val candidate = if (extension.isEmpty()) "$base ($index)" else "$base ($index).$extension"
            target = File(dir, candidate)
            index++
        }
        file.copyTo(target, overwrite = false)
        MediaScannerConnection.scanFile(this, arrayOf(target.absolutePath), arrayOf(mime), null)
        return "${Environment.DIRECTORY_DOWNLOADS}/${target.name}"
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

                "saveToDownloads" -> {
                    val path = call.argument<String>("path")
                    val fileName = call.argument<String>("fileName") ?: "document.pdf"
                    val mime = call.argument<String>("mime") ?: "application/pdf"
                    val file = path?.let { File(it) }
                    when {
                        file == null -> result.error("invalid_path", "path is required", null)
                        !file.exists() -> result.error("missing_file", "file does not exist", null)
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
                            PackageManager.PERMISSION_GRANTED -> {
                            pendingDownloadsResult = result
                            pendingDownloadsFile = file
                            pendingDownloadsName = fileName
                            pendingDownloadsMime = mime
                            requestPermissions(
                                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                                downloadsPermissionRequest,
                            )
                        }
                        else -> runCatching { saveToDownloads(file, fileName, mime) }
                            .onSuccess { result.success(it) }
                            .onFailure { result.error("save_failed", it.message, null) }
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
