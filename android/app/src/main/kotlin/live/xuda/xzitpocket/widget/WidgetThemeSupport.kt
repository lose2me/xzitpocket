package live.xuda.xzitpocket.widget

import android.content.Context
import android.content.res.Configuration
import androidx.annotation.ColorInt
import androidx.annotation.ColorRes
import androidx.core.content.ContextCompat
import live.xuda.xzitpocket.R

private enum class WidgetThemePreference(val value: String) {
    SYSTEM("system"),
    LIGHT("light"),
    DARK("dark"),
    ;

    companion object {
        fun fromValue(value: String?): WidgetThemePreference {
            return entries.firstOrNull { it.value == value } ?: SYSTEM
        }
    }
}

internal enum class WidgetThemeMode {
    LIGHT,
    DARK,
}

internal object WidgetThemeSupport {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_THEME_PREFERENCE = "flutter.theme_preference"

    fun resolveThemeMode(context: Context): WidgetThemeMode {
        return when (readPreference(context)) {
            WidgetThemePreference.LIGHT -> WidgetThemeMode.LIGHT
            WidgetThemePreference.DARK -> WidgetThemeMode.DARK
            WidgetThemePreference.SYSTEM -> {
                if (isSystemDark(context)) WidgetThemeMode.DARK else WidgetThemeMode.LIGHT
            }
        }
    }

    @ColorInt
    fun color(
        context: Context,
        @ColorRes colorResId: Int,
    ): Int {
        return ContextCompat.getColor(themedContext(context), colorResId)
    }

    fun backgroundDrawableRes(
        context: Context,
        conflict: Boolean = false,
    ): Int {
        return when (resolveThemeMode(context)) {
            WidgetThemeMode.LIGHT -> {
                if (conflict) {
                    R.drawable.widget_background_conflict_light
                } else {
                    R.drawable.widget_background_light
                }
            }

            WidgetThemeMode.DARK -> {
                if (conflict) {
                    R.drawable.widget_background_conflict_dark
                } else {
                    R.drawable.widget_background_dark
                }
            }
        }
    }

    fun courseItemBackgroundDrawableRes(
        context: Context,
        conflict: Boolean = false,
    ): Int {
        if (!conflict) return R.drawable.widget_course_item_background
        return when (resolveThemeMode(context)) {
            WidgetThemeMode.LIGHT -> R.drawable.widget_course_item_conflict_background_light
            WidgetThemeMode.DARK -> R.drawable.widget_course_item_conflict_background_dark
        }
    }

    private fun readPreference(context: Context): WidgetThemePreference {
        val value = context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(KEY_THEME_PREFERENCE, WidgetThemePreference.SYSTEM.value)
        return WidgetThemePreference.fromValue(value)
    }

    private fun themedContext(context: Context): Context {
        val configuration = Configuration(context.resources.configuration)
        val nightMode = when (resolveThemeMode(context)) {
            WidgetThemeMode.LIGHT -> Configuration.UI_MODE_NIGHT_NO
            WidgetThemeMode.DARK -> Configuration.UI_MODE_NIGHT_YES
        }
        configuration.uiMode =
            (configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or nightMode
        return context.createConfigurationContext(configuration)
    }

    private fun isSystemDark(context: Context): Boolean {
        val currentNightMode =
            context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return currentNightMode == Configuration.UI_MODE_NIGHT_YES
    }
}
