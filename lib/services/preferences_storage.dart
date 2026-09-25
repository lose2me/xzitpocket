import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStorage {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

  String? getClassAutomationMode() => _prefs.getString('class_automation_mode');
  Future<void> setClassAutomationMode(String value) =>
      _prefs.setString('class_automation_mode', value);

  String? getTimetableBackgroundPath() =>
      _prefs.getString('timetable_background_path');

  Future<void> setTimetableBackgroundPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs.remove('timetable_background_path');
    } else {
      await _prefs.setString('timetable_background_path', path);
    }
  }

  double getTimetableBackgroundOpacity() =>
      (_prefs.getDouble('timetable_background_opacity') ?? 0.5)
          .clamp(0.0, 1.0)
          .toDouble();

  Future<void> setTimetableBackgroundOpacity(double value) => _prefs.setDouble(
    'timetable_background_opacity',
    value.clamp(0.0, 1.0).toDouble(),
  );

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

  double getTimetableCourseTextSize() => _clampTimetableDimension(
    _prefs.getDouble('timetable_course_text_size') ?? 12.0,
    min: 8.0,
    max: 18.0,
  );

  Future<void> setTimetableCourseTextSize(double value) => _prefs.setDouble(
    'timetable_course_text_size',
    _clampTimetableDimension(value, min: 8.0, max: 18.0),
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
    await Future.wait([
      _prefs.remove('timetable_background_path'),
      _prefs.remove('timetable_background_opacity'),
      _prefs.remove('timetable_component_opacity'),
      _prefs.remove('timetable_grid_opacity'),
      _prefs.remove('timetable_course_text_size'),
      _prefs.remove('timetable_time_text_size'),
      _prefs.remove('timetable_date_text_size'),
      _prefs.remove('timetable_course_border_width'),
      _prefs.remove('timetable_course_border_opacity'),
      _prefs.remove('show_timetable_grid_lines'),
      _prefs.remove('show_today_grid_lines'),
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
