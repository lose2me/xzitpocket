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
    private const val KEY_WIDGET_THEME_PREFERENCE = "flutter.widget_theme_preference"
    private const val KEY_THEME_COLOR = "flutter.theme_color"
    private const val KEY_CUSTOM_THEME_COLOR = "flutter.custom_theme_color"

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

    @ColorInt
    fun primaryColor(context: Context): Int {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        (prefs.all[KEY_CUSTOM_THEME_COLOR] as? Number)?.let { return it.toLong().toInt() }
        val dark = resolveThemeMode(context) == WidgetThemeMode.DARK
        return when (prefs.getString(KEY_THEME_COLOR, "rose")) {
            "blue" -> if (dark) 0xFF8AB4FF.toInt() else 0xFF2563EB.toInt()
            "green" -> if (dark) 0xFF7BE495.toInt() else 0xFF15803D.toInt()
            "orange" -> if (dark) 0xFFFFB36B.toInt() else 0xFFC2410C.toInt()
            "purple" -> if (dark) 0xFFC4A1FF.toInt() else 0xFF7C3AED.toInt()
            "teal" -> if (dark) 0xFF5EEAD4.toInt() else 0xFF0F766E.toInt()
            else -> if (dark) 0xFFFF8DB7.toInt() else 0xFFBE185D.toInt()
        }
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
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val value = prefs.getString(KEY_WIDGET_THEME_PREFERENCE, null)
            ?: prefs.getString(KEY_THEME_PREFERENCE, WidgetThemePreference.SYSTEM.value)
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
