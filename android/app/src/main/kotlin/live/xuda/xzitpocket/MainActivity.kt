package live.xuda.xzitpocket

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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
