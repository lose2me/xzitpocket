# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (referenced by Flutter engine but not used)
-dontwarn com.google.android.play.core.**

# OkHttp / Dio
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Widgets / WorkManager
-keep public class * extends android.appwidget.AppWidgetProvider {
    public <init>();
}
-keep class live.xuda.xzitpocket.widget.** { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
