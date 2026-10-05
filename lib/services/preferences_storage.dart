import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStorage {
  late SharedPreferences _prefs;

  /// Only preferences exposed on the personalization page. The same allowlist
  /// applies to imports, including backups made before reminders were separated.
  static const _personalizationBackupKeys = <String>{
    'theme_preference',
    'theme_color',
    'custom_theme_color',
    'last_custom_theme_color',
    'widget_theme_preference',
    'widget_font_scale',
    'widget_background_alpha',
    'widget_text_opacity',
    'widget_background_color',
    'last_custom_widget_background_color',
    'widget_background_path',
    'widget_dark_background_path',
    'widget_use_light_background_in_dark_mode',
    'widget_text_color',
    'last_custom_widget_text_color',
    'widget_hide_teacher',
    'widget_hide_location',
    'widget_hide_date',
    'timetable_section_height',
    'timetable_time_column_width',
    'timetable_day_header_height',
    'timetable_course_corner_radius',
    'timetable_course_inner_padding',
    'timetable_course_outer_padding',
    'timetable_course_alpha',
    'timetable_course_font_scale',
    'timetable_component_opacity',
    'timetable_add_blank_line_after_title',
    'timetable_dashed_border_density',
    'timetable_hide_section_time',
    'timetable_hide_date_under_day',
    'timetable_show_start_time',
    'timetable_hide_location',
    'timetable_hide_teacher',
    'timetable_hide_teacher_brackets',
    'timetable_remove_location_at',
    'timetable_text_align_center_horizontal',
    'timetable_text_align_center_vertical',
    'timetable_border_type',
    'timetable_page_text_color',
    'timetable_last_custom_page_text_color',
    'timetable_page_text_opacity',
    'timetable_course_text_color',
    'timetable_last_custom_course_text_color',
    'timetable_course_border_color',
    'timetable_last_custom_course_border_color',
    'timetable_background_path',
    'timetable_dark_background_path',
    'timetable_use_light_background_in_dark_mode',
    'page_background_color',
    'custom_page_background_color',
    'last_custom_page_background_color',
    'toast_opacity',
    'timetable_grid_opacity',
    'timetable_grid_line_color',
    'timetable_last_custom_grid_line_color',
    'timetable_grid_line_width',
    'timetable_course_text_size',
    'timetable_time_text_size',
    'timetable_date_text_size',
    'timetable_course_text_opacity',
    'timetable_course_border_width',
    'timetable_course_border_opacity',
    'show_timetable_grid_lines',
    'show_today_grid_lines',
    'timetable_today_line_color',
    'timetable_last_custom_today_line_color',
    'timetable_today_line_width',
    'timetable_today_line_opacity',
  };

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Map<String, dynamic> getPersonalizationSnapshot() {
    final result = <String, dynamic>{};
    for (final key in _personalizationBackupKeys) {
      if (_prefs.containsKey(key)) result[key] = _prefs.get(key);
    }
    return result;
  }

  Future<void> restorePersonalizationSnapshot(
    Map<String, dynamic> values,
  ) async {
    for (final entry in values.entries) {
      if (!_personalizationBackupKeys.contains(entry.key)) continue;
      final value = entry.value;
      if (value == null) {
        await _prefs.remove(entry.key);
      } else if (value is bool) {
        await _prefs.setBool(entry.key, value);
      } else if (value is int) {
        await _prefs.setInt(entry.key, value);
      } else if (value is double) {
        await _prefs.setDouble(entry.key, value);
      } else if (value is num) {
        await _prefs.setDouble(entry.key, value.toDouble());
      } else if (value is String) {
        await _prefs.setString(entry.key, value);
      } else if (value is List) {
        await _prefs.setStringList(
          entry.key,
          value.map((item) => item.toString()).toList(),
        );
      }
    }
  }

  String? getSecondaryScheduleJson() =>
      _prefs.getString('secondary_schedule_json');

  Future<void> setSecondaryScheduleJson(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove('secondary_schedule_json');
    } else {
      await _prefs.setString('secondary_schedule_json', value);
    }
  }

  String getSecondaryScheduleTitle() {
    final title = _prefs.getString('secondary_schedule_title');
    if (title == null || title.isEmpty || title == '正在预览备用课表') {
      return '正在预览备用课程';
    }
    return title;
  }

  Future<void> setSecondaryScheduleTitle(String value) async {
    final title = value.trim();
    if (title.isEmpty || title == '正在预览备用课程' || title == '正在预览备用课表') {
      await _prefs.remove('secondary_schedule_title');
    } else {
      await _prefs.setString('secondary_schedule_title', title);
    }
  }

  // ── Student info ──

  String? getStudentId() => _prefs.getString('student_id');
  Future<void> setStudentId(String id) => _prefs.setString('student_id', id);

  String? getStudentName() => _prefs.getString('student_name');
  Future<void> setStudentName(String name) =>
      _prefs.setString('student_name', name);

  String? getCollegeName() => _prefs.getString('college_name');
  Future<void> setCollegeName(String name) =>
      _prefs.setString('college_name', name);

  String? getClassName() => _prefs.getString('class_name');
  Future<void> setClassName(String name) =>
      _prefs.setString('class_name', name);

  Future<void> clearStudentInfo() async {
    await _prefs.remove('student_id');
    await _prefs.remove('student_name');
    await _prefs.remove('college_name');
    await _prefs.remove('major_name');
    await _prefs.remove('class_name');
  }

  // ── Settings ──

  String? getThemePreference() => _prefs.getString('theme_preference');
  Future<void> setThemePreference(String value) =>
      _prefs.setString('theme_preference', value);

  String? getThemeColor() => _prefs.getString('theme_color');
  Future<void> setThemeColor(String value) =>
      _prefs.setString('theme_color', value);

  int? getCustomThemeColor() => _prefs.getInt('custom_theme_color');
  Future<void> setCustomThemeColor(int? value) async {
    if (value == null) {
      await _prefs.remove('custom_theme_color');
    } else {
      await _prefs.setInt('custom_theme_color', value);
    }
  }

  int? getLastCustomThemeColor() => _prefs.getInt('last_custom_theme_color');
  Future<void> setLastCustomThemeColor(int? value) async {
    if (value == null) {
      await _prefs.remove('last_custom_theme_color');
    } else {
      await _prefs.setInt('last_custom_theme_color', value);
    }
  }

  String? getClassAutomationMode() => _prefs.getString('class_automation_mode');
  Future<void> setClassAutomationMode(String value) =>
      _prefs.setString('class_automation_mode', value);

  bool getCourseReminderEnabled() =>
      _prefs.getBool('course_reminder_enabled') ?? false;

  Future<void> setCourseReminderEnabled(bool value) =>
      _prefs.setBool('course_reminder_enabled', value);

  int getCourseReminderMinutes() =>
      (_prefs.getInt('course_reminder_minutes') ?? 15).clamp(1, 60);

  Future<void> setCourseReminderMinutes(int value) =>
      _prefs.setInt('course_reminder_minutes', value.clamp(1, 60));

  bool getWearableNotificationCompatibility() =>
      _prefs.getBool('wearable_notification_compatibility') ?? false;

  Future<void> setWearableNotificationCompatibility(bool value) =>
      _prefs.setBool('wearable_notification_compatibility', value);

  String? getWidgetThemePreference() =>
      _prefs.getString('widget_theme_preference');

  Future<void> setWidgetThemePreference(String value) =>
      _prefs.setString('widget_theme_preference', value);

  double getWidgetFontScale() =>
      (_prefs.getDouble('widget_font_scale') ?? 1.0).clamp(0.5, 2.0).toDouble();

  Future<void> setWidgetFontScale(double value) =>
      _prefs.setDouble('widget_font_scale', value.clamp(0.5, 2.0).toDouble());

  double getWidgetBackgroundAlpha() =>
      (_prefs.getDouble('widget_background_alpha') ?? 1.0)
          .clamp(0.0, 1.0)
          .toDouble();

  Future<void> setWidgetBackgroundAlpha(double value) => _prefs.setDouble(
    'widget_background_alpha',
    value.clamp(0.0, 1.0).toDouble(),
  );

  double getWidgetTextOpacity() =>
      (_prefs.getDouble('widget_text_opacity') ?? 1.0)
          .clamp(0.0, 1.0)
          .toDouble();

  Future<void> setWidgetTextOpacity(double value) =>
      _prefs.setDouble('widget_text_opacity', value.clamp(0.0, 1.0).toDouble());

  int? getWidgetBackgroundColor() => _prefs.getInt('widget_background_color');
  int? getLastCustomWidgetBackgroundColor() =>
      _prefs.getInt('last_custom_widget_background_color');
  int? getWidgetTextColor() => _prefs.getInt('widget_text_color');
  int? getLastCustomWidgetTextColor() =>
      _prefs.getInt('last_custom_widget_text_color');

  Future<void> setWidgetBackgroundColor(int? value) async {
    if (value == null) {
      await _prefs.remove('widget_background_color');
    } else {
      await _prefs.setInt('widget_background_color', value);
    }
  }

  Future<void> setLastCustomWidgetBackgroundColor(int? value) async {
    if (value == null) {
      await _prefs.remove('last_custom_widget_background_color');
    } else {
      await _prefs.setInt('last_custom_widget_background_color', value);
    }
  }

  String? getWidgetBackgroundPath() =>
      _prefs.getString('widget_background_path');

  Future<void> setWidgetBackgroundPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs.remove('widget_background_path');
    } else {
      await _prefs.setString('widget_background_path', path);
    }
  }

  String? getWidgetDarkBackgroundPath() =>
      _prefs.getString('widget_dark_background_path');

  Future<void> setWidgetDarkBackgroundPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs.remove('widget_dark_background_path');
    } else {
      await _prefs.setString('widget_dark_background_path', path);
    }
  }

  bool getWidgetUseLightBackgroundInDarkMode() =>
      _prefs.getBool('widget_use_light_background_in_dark_mode') ?? true;

  Future<void> setWidgetUseLightBackgroundInDarkMode(bool value) =>
      _prefs.setBool('widget_use_light_background_in_dark_mode', value);

  Future<void> setWidgetTextColor(int? value) async {
    if (value == null) {
      await _prefs.remove('widget_text_color');
    } else {
      await _prefs.setInt('widget_text_color', value);
    }
  }

  Future<void> setLastCustomWidgetTextColor(int? value) async {
    if (value == null) {
      await _prefs.remove('last_custom_widget_text_color');
    } else {
      await _prefs.setInt('last_custom_widget_text_color', value);
    }
  }

  bool getWidgetHideTeacher() => _prefs.getBool('widget_hide_teacher') ?? false;

  Future<void> setWidgetHideTeacher(bool value) =>
      _prefs.setBool('widget_hide_teacher', value);

  bool getWidgetHideLocation() =>
      _prefs.getBool('widget_hide_location') ?? false;

  Future<void> setWidgetHideLocation(bool value) =>
      _prefs.setBool('widget_hide_location', value);

  bool getWidgetHideDate() => _prefs.getBool('widget_hide_date') ?? false;

  Future<void> setWidgetHideDate(bool value) =>
      _prefs.setBool('widget_hide_date', value);

  double getTimetableSectionHeight() =>
      (_prefs.getDouble('timetable_section_height') ?? 60.0)
          .clamp(40.0, 140.0)
          .toDouble();

  Future<void> setTimetableSectionHeight(double value) => _prefs.setDouble(
    'timetable_section_height',
    value.clamp(40.0, 140.0).toDouble(),
  );

  double getTimetableTimeColumnWidth() =>
      (_prefs.getDouble('timetable_time_column_width') ?? 40.0)
          .clamp(20.0, 80.0)
          .toDouble();

  Future<void> setTimetableTimeColumnWidth(double value) => _prefs.setDouble(
    'timetable_time_column_width',
    value.clamp(20.0, 80.0).toDouble(),
  );

  double getTimetableDayHeaderHeight() =>
      (_prefs.getDouble('timetable_day_header_height') ?? 40.0)
          .clamp(30.0, 80.0)
          .toDouble();

  Future<void> setTimetableDayHeaderHeight(double value) => _prefs.setDouble(
    'timetable_day_header_height',
    value.clamp(30.0, 80.0).toDouble(),
  );

  double getTimetableCourseCornerRadius() =>
      (_prefs.getDouble('timetable_course_corner_radius') ?? 6.0)
          .clamp(0.0, 24.0)
          .toDouble();

  Future<void> setTimetableCourseCornerRadius(double value) => _prefs.setDouble(
    'timetable_course_corner_radius',
    value.clamp(0.0, 24.0).toDouble(),
  );

  double getTimetableCourseInnerPadding() =>
      (_prefs.getDouble('timetable_course_inner_padding') ?? 2.0)
          .clamp(0.0, 12.0)
          .toDouble();

  Future<void> setTimetableCourseInnerPadding(double value) => _prefs.setDouble(
    'timetable_course_inner_padding',
    value.clamp(0.0, 12.0).toDouble(),
  );

  double getTimetableCourseOuterPadding() =>
      (_prefs.getDouble('timetable_course_outer_padding') ?? 1.5)
          .clamp(0.0, 8.0)
          .toDouble();

  Future<void> setTimetableCourseOuterPadding(double value) => _prefs.setDouble(
    'timetable_course_outer_padding',
    value.clamp(0.0, 8.0).toDouble(),
  );

  double getTimetableCourseAlpha() =>
      (_prefs.getDouble('timetable_course_alpha') ?? 1.0)
          .clamp(0.1, 1.0)
          .toDouble();

  Future<void> setTimetableCourseAlpha(double value) => _prefs.setDouble(
    'timetable_course_alpha',
    value.clamp(0.1, 1.0).toDouble(),
  );

  double getTimetableCourseFontScale() =>
      (_prefs.getDouble('timetable_course_font_scale') ?? 0.95)
          .clamp(0.5, 2.0)
          .toDouble();

  Future<void> setTimetableCourseFontScale(double value) => _prefs.setDouble(
    'timetable_course_font_scale',
    value.clamp(0.5, 2.0).toDouble(),
  );

  bool getTimetableAddBlankLineAfterTitle() =>
      _prefs.getBool('timetable_add_blank_line_after_title') ?? false;

  Future<void> setTimetableAddBlankLineAfterTitle(bool value) =>
      _prefs.setBool('timetable_add_blank_line_after_title', value);

  double getTimetableDashedBorderDensity() =>
      (_prefs.getDouble('timetable_dashed_border_density') ?? 1.0)
          .clamp(0.5, 2.0)
          .toDouble();

  Future<void> setTimetableDashedBorderDensity(double value) =>
      _prefs.setDouble(
        'timetable_dashed_border_density',
        value.clamp(0.5, 2.0).toDouble(),
      );

  bool getTimetableHideSectionTime() =>
      _prefs.getBool('timetable_hide_section_time') ?? false;
  Future<void> setTimetableHideSectionTime(bool value) =>
      _prefs.setBool('timetable_hide_section_time', value);
  bool getTimetableHideDateUnderDay() =>
      _prefs.getBool('timetable_hide_date_under_day') ?? false;
  Future<void> setTimetableHideDateUnderDay(bool value) =>
      _prefs.setBool('timetable_hide_date_under_day', value);
  bool getTimetableShowStartTime() =>
      _prefs.getBool('timetable_show_start_time') ?? false;
  Future<void> setTimetableShowStartTime(bool value) =>
      _prefs.setBool('timetable_show_start_time', value);
  bool getTimetableHideLocation() =>
      _prefs.getBool('timetable_hide_location') ?? false;
  Future<void> setTimetableHideLocation(bool value) =>
      _prefs.setBool('timetable_hide_location', value);
  bool getTimetableHideTeacher() =>
      _prefs.getBool('timetable_hide_teacher') ?? true;
  Future<void> setTimetableHideTeacher(bool value) =>
      _prefs.setBool('timetable_hide_teacher', value);
  bool getTimetableHideTeacherBrackets() =>
      _prefs.getBool('timetable_hide_teacher_brackets') ?? true;
  Future<void> setTimetableHideTeacherBrackets(bool value) =>
      _prefs.setBool('timetable_hide_teacher_brackets', value);
  bool getTimetableRemoveLocationAt() =>
      _prefs.getBool('timetable_remove_location_at') ?? false;
  Future<void> setTimetableRemoveLocationAt(bool value) =>
      _prefs.setBool('timetable_remove_location_at', value);
  bool getTimetableTextAlignCenterHorizontal() =>
      _prefs.getBool('timetable_text_align_center_horizontal') ?? false;
  Future<void> setTimetableTextAlignCenterHorizontal(bool value) =>
      _prefs.setBool('timetable_text_align_center_horizontal', value);
  bool getTimetableTextAlignCenterVertical() =>
      _prefs.getBool('timetable_text_align_center_vertical') ?? false;
  Future<void> setTimetableTextAlignCenterVertical(bool value) =>
      _prefs.setBool('timetable_text_align_center_vertical', value);
  String? getTimetableBorderType() => _prefs.getString('timetable_border_type');
  Future<void> setTimetableBorderType(String value) =>
      _prefs.setString('timetable_border_type', value);

  int? getTimetablePageTextColor() =>
      _prefs.getInt('timetable_page_text_color');

  int? getTimetableLastCustomPageTextColor() =>
      _prefs.getInt('timetable_last_custom_page_text_color');

  Future<void> setTimetablePageTextColor(int? value) async {
    if (value == null) {
      await _prefs.remove('timetable_page_text_color');
    } else {
      await _prefs.setInt('timetable_page_text_color', value);
    }
  }

  Future<void> setTimetableLastCustomPageTextColor(int? value) async {
    if (value == null) {
      await _prefs.remove('timetable_last_custom_page_text_color');
    } else {
      await _prefs.setInt('timetable_last_custom_page_text_color', value);
    }
  }

  int? getTimetableCourseTextColor() =>
      _prefs.getInt('timetable_course_text_color');

  int? getTimetableLastCustomCourseTextColor() =>
      _prefs.getInt('timetable_last_custom_course_text_color');

  Future<void> setTimetableCourseTextColor(int? value) async {
    if (value == null) {
      await _prefs.remove('timetable_course_text_color');
    } else {
      await _prefs.setInt('timetable_course_text_color', value);
    }
  }

  Future<void> setTimetableLastCustomCourseTextColor(int? value) async {
    if (value == null) {
      await _prefs.remove('timetable_last_custom_course_text_color');
    } else {
      await _prefs.setInt('timetable_last_custom_course_text_color', value);
    }
  }

  int? getTimetableCourseBorderColor() =>
      _prefs.getInt('timetable_course_border_color');
  int? getTimetableLastCustomCourseBorderColor() =>
      _prefs.getInt('timetable_last_custom_course_border_color');

  Future<void> setTimetableCourseBorderColor(int? value) async {
    if (value == null) {
      await _prefs.remove('timetable_course_border_color');
    } else {
      await _prefs.setInt('timetable_course_border_color', value);
    }
  }

  Future<void> setTimetableLastCustomCourseBorderColor(int? value) async {
    if (value == null) {
      await _prefs.remove('timetable_last_custom_course_border_color');
    } else {
      await _prefs.setInt('timetable_last_custom_course_border_color', value);
    }
  }

  int? getCustomPageBackgroundColor() =>
      _prefs.getInt('custom_page_background_color');
  int? getLastCustomPageBackgroundColor() =>
      _prefs.getInt('last_custom_page_background_color');

  Future<void> setCustomPageBackgroundColor(int? value) async {
    if (value == null) {
      await _prefs.remove('custom_page_background_color');
    } else {
      await _prefs.setInt('custom_page_background_color', value);
    }
  }

  Future<void> setLastCustomPageBackgroundColor(int? value) async {
    if (value == null) {
      await _prefs.remove('last_custom_page_background_color');
    } else {
      await _prefs.setInt('last_custom_page_background_color', value);
    }
  }

  double getToastOpacity() =>
      (_prefs.getDouble('toast_opacity') ?? 1.0).clamp(0.0, 1.0).toDouble();

  Future<void> setToastOpacity(double value) =>
      _prefs.setDouble('toast_opacity', value.clamp(0.0, 1.0).toDouble());

  int? getTimetableGridLineColor() =>
      _prefs.getInt('timetable_grid_line_color');
  int? getTimetableLastCustomGridLineColor() =>
      _prefs.getInt('timetable_last_custom_grid_line_color');

  Future<void> setTimetableGridLineColor(int? value) async {
    if (value == null) {
      await _prefs.remove('timetable_grid_line_color');
    } else {
      await _prefs.setInt('timetable_grid_line_color', value);
    }
  }

  Future<void> setTimetableLastCustomGridLineColor(int? value) async {
    if (value == null) {
      await _prefs.remove('timetable_last_custom_grid_line_color');
    } else {
      await _prefs.setInt('timetable_last_custom_grid_line_color', value);
    }
  }

  int? getTimetableTodayLineColor() =>
      _prefs.getInt('timetable_today_line_color');
  int? getTimetableLastCustomTodayLineColor() =>
      _prefs.getInt('timetable_last_custom_today_line_color');

  Future<void> setTimetableTodayLineColor(int? value) async {
    if (value == null) {
      await _prefs.remove('timetable_today_line_color');
    } else {
      await _prefs.setInt('timetable_today_line_color', value);
    }
  }

  Future<void> setTimetableLastCustomTodayLineColor(int? value) async {
    if (value == null) {
      await _prefs.remove('timetable_last_custom_today_line_color');
    } else {
      await _prefs.setInt('timetable_last_custom_today_line_color', value);
    }
  }

  String? getTimetableBackgroundPath() =>
      _prefs.getString('timetable_background_path');

  Future<void> setTimetableBackgroundPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs.remove('timetable_background_path');
    } else {
      await _prefs.setString('timetable_background_path', path);
    }
  }

  String? getTimetableDarkBackgroundPath() =>
      _prefs.getString('timetable_dark_background_path');

  Future<void> setTimetableDarkBackgroundPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs.remove('timetable_dark_background_path');
    } else {
      await _prefs.setString('timetable_dark_background_path', path);
    }
  }

  bool getTimetableUseLightBackgroundInDarkMode() =>
      _prefs.getBool('timetable_use_light_background_in_dark_mode') ?? true;

  Future<void> setTimetableUseLightBackgroundInDarkMode(bool value) =>
      _prefs.setBool('timetable_use_light_background_in_dark_mode', value);

  String? getPageBackgroundColor() =>
      _prefs.getString('page_background_color') ??
      _prefs.getString('timetable_solid_background');
  Future<void> setPageBackgroundColor(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove('page_background_color');
    } else {
      await _prefs.setString('page_background_color', value);
    }
    await _prefs.remove('timetable_solid_background');
  }

  Future<void> clearLegacyTimetableBackgroundSettings() async {
    await Future.wait([
      _prefs.remove('timetable_background_original_path'),
      _prefs.remove('timetable_background_fullscreen'),
      _prefs.remove('timetable_background_opacity'),
    ]);
  }

  double getTimetableComponentOpacity() =>
      (_prefs.getDouble('timetable_component_opacity') ?? 0.7)
          .clamp(0.0, 1.0)
          .toDouble();

  Future<void> setTimetableComponentOpacity(double value) => _prefs.setDouble(
    'timetable_component_opacity',
    value.clamp(0.0, 1.0).toDouble(),
  );

  double getTimetableGridOpacity() =>
      (_prefs.getDouble('timetable_grid_opacity') ?? 0.5)
          .clamp(0.0, 1.0)
          .toDouble();

  Future<void> setTimetableGridOpacity(double value) => _prefs.setDouble(
    'timetable_grid_opacity',
    value.clamp(0.0, 1.0).toDouble(),
  );

  double getTimetablePageTextOpacity() =>
      (_prefs.getDouble('timetable_page_text_opacity') ?? 1.0)
          .clamp(0.0, 1.0)
          .toDouble();

  Future<void> setTimetablePageTextOpacity(double value) => _prefs.setDouble(
    'timetable_page_text_opacity',
    value.clamp(0.0, 1.0).toDouble(),
  );

  double getTimetableGridLineWidth() => _clampTimetableDimension(
    _prefs.getDouble('timetable_grid_line_width') ?? 0.5,
    min: 0.5,
    max: 3.0,
  );

  Future<void> setTimetableGridLineWidth(double value) => _prefs.setDouble(
    'timetable_grid_line_width',
    _clampTimetableDimension(value, min: 0.5, max: 3.0),
  );

  double getTimetableTodayLineWidth() => _clampTimetableDimension(
    _prefs.getDouble('timetable_today_line_width') ?? 1.0,
    min: 0.5,
    max: 4.0,
  );

  Future<void> setTimetableTodayLineWidth(double value) => _prefs.setDouble(
    'timetable_today_line_width',
    _clampTimetableDimension(value, min: 0.5, max: 4.0),
  );

  double getTimetableTodayLineOpacity() =>
      (_prefs.getDouble('timetable_today_line_opacity') ?? 0.5)
          .clamp(0.0, 1.0)
          .toDouble();

  Future<void> setTimetableTodayLineOpacity(double value) => _prefs.setDouble(
    'timetable_today_line_opacity',
    value.clamp(0.0, 1.0).toDouble(),
  );

  double getTimetableCourseTextSize() => _clampTimetableDimension(
    _prefs.getDouble('timetable_course_text_size') ?? 12.0,
    min: 8.0,
    max: 18.0,
  );

  Future<void> setTimetableCourseTextSize(double value) => _prefs.setDouble(
    'timetable_course_text_size',
    _clampTimetableDimension(value, min: 8.0, max: 18.0),
  );

  double getTimetableCourseTextOpacity() =>
      (_prefs.getDouble('timetable_course_text_opacity') ?? 1.0)
          .clamp(0.0, 1.0)
          .toDouble();

  Future<void> setTimetableCourseTextOpacity(double value) => _prefs.setDouble(
    'timetable_course_text_opacity',
    value.clamp(0.0, 1.0).toDouble(),
  );

  double getTimetableTimeTextSize() => _clampTimetableDimension(
    _prefs.getDouble('timetable_time_text_size') ?? 11.0,
    min: 8.0,
    max: 18.0,
  );

  Future<void> setTimetableTimeTextSize(double value) => _prefs.setDouble(
    'timetable_time_text_size',
    _clampTimetableDimension(value, min: 8.0, max: 18.0),
  );

  double getTimetableDateTextSize() => _clampTimetableDimension(
    _prefs.getDouble('timetable_date_text_size') ?? 12.0,
    min: 8.0,
    max: 18.0,
  );

  Future<void> setTimetableDateTextSize(double value) => _prefs.setDouble(
    'timetable_date_text_size',
    _clampTimetableDimension(value, min: 8.0, max: 18.0),
  );

  double getTimetableCourseBorderWidth() => _clampTimetableDimension(
    _prefs.getDouble('timetable_course_border_width') ?? 0.5,
    min: 0.0,
    max: 3.0,
  );

  Future<void> setTimetableCourseBorderWidth(double value) => _prefs.setDouble(
    'timetable_course_border_width',
    _clampTimetableDimension(value, min: 0.0, max: 3.0),
  );

  double getTimetableCourseBorderOpacity() =>
      (_prefs.getDouble('timetable_course_border_opacity') ??
              getTimetableComponentOpacity())
          .clamp(0.0, 1.0)
          .toDouble();

  Future<void> setTimetableCourseBorderOpacity(double value) =>
      _prefs.setDouble(
        'timetable_course_border_opacity',
        value.clamp(0.0, 1.0).toDouble(),
      );

  Future<void> resetTimetableAppearance() async {
    bool isActiveCustomColor(int? color, int? lastCustomColor) =>
        color != null && color == lastCustomColor;

    final keepWidgetBackgroundColor = isActiveCustomColor(
      getWidgetBackgroundColor(),
      getLastCustomWidgetBackgroundColor(),
    );
    final keepWidgetTextColor = isActiveCustomColor(
      getWidgetTextColor(),
      getLastCustomWidgetTextColor(),
    );
    final keepGridLineColor = isActiveCustomColor(
      getTimetableGridLineColor(),
      getTimetableLastCustomGridLineColor(),
    );
    final keepTodayLineColor = isActiveCustomColor(
      getTimetableTodayLineColor(),
      getTimetableLastCustomTodayLineColor(),
    );
    final keepPageTextColor = isActiveCustomColor(
      getTimetablePageTextColor(),
      getTimetableLastCustomPageTextColor(),
    );
    final keepCourseTextColor = isActiveCustomColor(
      getTimetableCourseTextColor(),
      getTimetableLastCustomCourseTextColor(),
    );
    final keepCourseBorderColor = isActiveCustomColor(
      getTimetableCourseBorderColor(),
      getTimetableLastCustomCourseBorderColor(),
    );

    await Future.wait([
      _prefs.remove('theme_preference'),
      _prefs.remove('theme_color'),
      _prefs.remove('custom_theme_color'),
      _prefs.remove('timetable_background_path'),
      _prefs.remove('timetable_dark_background_path'),
      _prefs.remove('timetable_use_light_background_in_dark_mode'),
      _prefs.remove('page_background_color'),
      _prefs.remove('timetable_solid_background'),
      _prefs.remove('toast_opacity'),
      // Remove settings from versions that supported separate source images,
      // non-fullscreen backgrounds, and background opacity.
      _prefs.remove('timetable_background_original_path'),
      _prefs.remove('timetable_background_fullscreen'),
      _prefs.remove('timetable_background_opacity'),
      _prefs.remove('timetable_component_opacity'),
      _prefs.remove('timetable_grid_opacity'),
      _prefs.remove('timetable_page_text_opacity'),
      if (!keepGridLineColor) _prefs.remove('timetable_grid_line_color'),
      _prefs.remove('timetable_grid_line_width'),
      if (!keepTodayLineColor) _prefs.remove('timetable_today_line_color'),
      _prefs.remove('timetable_today_line_width'),
      _prefs.remove('timetable_today_line_opacity'),
      _prefs.remove('timetable_course_text_size'),
      _prefs.remove('timetable_course_text_opacity'),
      _prefs.remove('timetable_time_text_size'),
      _prefs.remove('timetable_date_text_size'),
      _prefs.remove('timetable_course_border_width'),
      _prefs.remove('timetable_course_border_opacity'),
      _prefs.remove('show_timetable_grid_lines'),
      _prefs.remove('show_today_grid_lines'),
      _prefs.remove('widget_theme_preference'),
      _prefs.remove('widget_font_scale'),
      _prefs.remove('widget_background_alpha'),
      _prefs.remove('widget_text_opacity'),
      if (!keepWidgetBackgroundColor) _prefs.remove('widget_background_color'),
      _prefs.remove('widget_background_path'),
      _prefs.remove('widget_dark_background_path'),
      _prefs.remove('widget_use_light_background_in_dark_mode'),
      if (!keepWidgetTextColor) _prefs.remove('widget_text_color'),
      _prefs.remove('widget_hide_teacher'),
      _prefs.remove('widget_hide_location'),
      _prefs.remove('widget_hide_date'),
      _prefs.remove('timetable_section_height'),
      _prefs.remove('timetable_time_column_width'),
      _prefs.remove('timetable_day_header_height'),
      _prefs.remove('timetable_course_corner_radius'),
      _prefs.remove('timetable_course_inner_padding'),
      _prefs.remove('timetable_course_outer_padding'),
      _prefs.remove('timetable_course_alpha'),
      _prefs.remove('timetable_course_font_scale'),
      _prefs.remove('timetable_add_blank_line_after_title'),
      _prefs.remove('timetable_dashed_border_density'),
      _prefs.remove('timetable_hide_section_time'),
      _prefs.remove('timetable_hide_date_under_day'),
      _prefs.remove('timetable_show_start_time'),
      _prefs.remove('timetable_hide_location'),
      _prefs.remove('timetable_hide_teacher'),
      _prefs.remove('timetable_hide_teacher_brackets'),
      _prefs.remove('timetable_remove_location_at'),
      _prefs.remove('timetable_text_align_center_horizontal'),
      _prefs.remove('timetable_text_align_center_vertical'),
      _prefs.remove('timetable_border_type'),
      if (!keepPageTextColor) _prefs.remove('timetable_page_text_color'),
      if (!keepCourseTextColor) _prefs.remove('timetable_course_text_color'),
      if (!keepCourseBorderColor)
        _prefs.remove('timetable_course_border_color'),
    ]);
  }

  bool getShowTimetableGridLines() =>
      _prefs.getBool('show_timetable_grid_lines') ?? true;

  Future<void> setShowTimetableGridLines(bool value) =>
      _prefs.setBool('show_timetable_grid_lines', value);

  bool getShowTodayGridLines() =>
      _prefs.getBool('show_today_grid_lines') ?? false;

  Future<void> setShowTodayGridLines(bool value) =>
      _prefs.setBool('show_today_grid_lines', value);

  bool getUseCloudTimetableAdjustments() =>
      _prefs.getBool('use_cloud_timetable_adjustments') ?? true;

  Future<void> setUseCloudTimetableAdjustments(bool value) =>
      _prefs.setBool('use_cloud_timetable_adjustments', value);

  // ── School calendar cache ──

  String? getSchoolCalendarCache() => _prefs.getString('school_calendar_cache');

  String? getSchoolCalendarVersion() =>
      _prefs.getString('school_calendar_version');

  int? getSchoolCalendarCacheTime() =>
      _prefs.getInt('school_calendar_cache_time');

  Future<void> setSchoolCalendarCache(String json) =>
      _setCache('school_calendar_cache', 'school_calendar_cache_time', json);

  Future<void> setSchoolCalendarVersion(String value) =>
      _prefs.setString('school_calendar_version', value);

  Future<void> clearSchoolCalendarCache() =>
      _clearCache('school_calendar_cache', 'school_calendar_cache_time');

  Set<String> getHiddenServiceFeatures() =>
      (_prefs.getStringList('hidden_service_features') ?? const <String>[])
          .toSet();

  Future<void> setHiddenServiceFeatures(Iterable<String> values) =>
      _prefs.setStringList('hidden_service_features', values.toSet().toList());

  // ── Power room ──

  String? getSavedPowerRoomId() => _prefs.getString('saved_power_room_id');

  Future<void> setSavedPowerRoomId(String roomId) async {
    final value = roomId.trim();
    if (value.isEmpty) {
      await _prefs.remove('saved_power_room_id');
      return;
    }
    await _prefs.setString('saved_power_room_id', value);
  }

  Future<void> clearSavedPowerRoomId() => _prefs.remove('saved_power_room_id');

  // ── Power cache ──

  String? getPowerCache() => _prefs.getString('saved_power_cache');
  String? getPowerCacheRoomId() =>
      _prefs.getString('saved_power_cache_room_id');
  int? getPowerCacheTime() => _prefs.getInt('saved_power_cache_time');

  Future<void> setPowerCache(String json, {required String roomId}) async {
    final writes = <Future<bool>>[
      if (_prefs.getString('saved_power_cache') != json)
        _prefs.setString('saved_power_cache', json),
      if (_prefs.getString('saved_power_cache_room_id') != roomId)
        _prefs.setString('saved_power_cache_room_id', roomId),
    ];
    await Future.wait(writes);
    await _touchCacheTime('saved_power_cache_time');
  }

  Future<void> clearPowerCache() async {
    await _prefs.remove('saved_power_cache');
    await _prefs.remove('saved_power_cache_room_id');
    await _prefs.remove('saved_power_cache_time');
    await _prefs.remove('saved_power_cache_date');
  }

  // ── Generic cache helpers ──

  Future<void> _setCache(String dataKey, String timeKey, String json) async {
    if (_prefs.getString(dataKey) != json) {
      await _prefs.setString(dataKey, json);
    }
    await _touchCacheTime(timeKey);
  }

  Future<void> _touchCacheTime(String timeKey) =>
      _prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);

  Future<void> _clearCache(String dataKey, String timeKey) async {
    await _prefs.remove(dataKey);
    await _prefs.remove(timeKey);
  }

  // ── JP cache ──

  String? getJpCache() => _prefs.getString('jp_cache');
  int? getJpCacheTime() => _prefs.getInt('jp_cache_time');
  Future<void> setJpCache(String json) =>
      _setCache('jp_cache', 'jp_cache_time', json);
  Future<void> clearJpCache() => _clearCache('jp_cache', 'jp_cache_time');

  // ── Repair cache ──

  String? getRepairCache() => _prefs.getString('repair_cache');
  int? getRepairCacheTime() => _prefs.getInt('repair_cache_time');
  Future<void> setRepairCache(String json) =>
      _setCache('repair_cache', 'repair_cache_time', json);
  Future<void> clearRepairCache() =>
      _clearCache('repair_cache', 'repair_cache_time');

  // ── Exam cache ──

  String? getExamCache() => _prefs.getString('exam_cache');
  int? getExamCacheTime() => _prefs.getInt('exam_cache_time');
  Future<void> setExamCache(String json) =>
      _setCache('exam_cache', 'exam_cache_time', json);

  // ── Book list cache ──

  String? getBookCache() => _prefs.getString('book_cache');
  int? getBookCacheTime() => _prefs.getInt('book_cache_time');
  Future<void> setBookCache(String json) =>
      _setCache('book_cache', 'book_cache_time', json);

  String? getGradeCache() => _prefs.getString('grade_cache');
  int? getGradeCacheTime() => _prefs.getInt('grade_cache_time');
  Future<void> setGradeCache(String json) =>
      _setCache('grade_cache', 'grade_cache_time', json);

  String? getAcademicCache() => _prefs.getString('academic_cache');
  int? getAcademicCacheTime() => _prefs.getInt('academic_cache_time');
  Future<void> setAcademicCache(String json) =>
      _setCache('academic_cache', 'academic_cache_time', json);

  // ── YKT cache ──

  String? getYktCache() => _prefs.getString('ykt_cache');
  int? getYktCacheTime() => _prefs.getInt('ykt_cache_time');
  Future<void> setYktCache(String json) =>
      _setCache('ykt_cache', 'ykt_cache_time', json);

  // ── NetAuth cache ──

  String? getNetauthCache() => _prefs.getString('netauth_cache');
  int? getNetauthCacheTime() => _prefs.getInt('netauth_cache_time');
  Future<void> setNetauthCache(String json) =>
      _setCache('netauth_cache', 'netauth_cache_time', json);

  // ── Learning center cache ──

  String? getLearningQuestionBankCache() =>
      _prefs.getString('learning_question_bank_cache');
  int? getLearningQuestionBankCacheTime() =>
      _prefs.getInt('learning_question_bank_cache_time');

  Future<void> setLearningQuestionBankCache(String json) => _setCache(
    'learning_question_bank_cache',
    'learning_question_bank_cache_time',
    json,
  );

  String? getLearningStateCache() => _prefs.getString('learning_state_cache');

  Future<void> setLearningStateCache(String json) =>
      _prefs.setString('learning_state_cache', json);

  Future<void> clearLearningCache() async {
    await Future.wait([
      _clearCache(
        'learning_question_bank_cache',
        'learning_question_bank_cache_time',
      ),
      _prefs.remove('learning_state_cache'),
    ]);
  }

  Future<void> clearLearningQuestionBankCache() => _clearCache(
    'learning_question_bank_cache',
    'learning_question_bank_cache_time',
  );

  Future<void> clearUserToolCaches() async {
    await Future.wait([
      _clearCache('jp_cache', 'jp_cache_time'),
      _clearCache('repair_cache', 'repair_cache_time'),
      _clearCache('exam_cache', 'exam_cache_time'),
      _clearCache('book_cache', 'book_cache_time'),
      _clearCache('grade_cache', 'grade_cache_time'),
      _clearCache('academic_cache', 'academic_cache_time'),
      _clearCache('ykt_cache', 'ykt_cache_time'),
      _clearCache('netauth_cache', 'netauth_cache_time'),
      clearLearningCache(),
    ]);
  }

  static double _clampTimetableDimension(
    double value, {
    required double min,
    required double max,
  }) {
    final normalized = (value * 10).round() / 10.0;
    return normalized.clamp(min, max).toDouble();
  }

  // ── Cache validity ──

  static bool isCacheValid(int? cacheTimeMs, Duration ttl, {DateTime? now}) {
    if (cacheTimeMs == null) return false;
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(cacheTimeMs);
    final currentTime = now ?? DateTime.now();
    if (cacheTime.isAfter(currentTime)) return false;
    return currentTime.difference(cacheTime) < ttl;
  }
}
