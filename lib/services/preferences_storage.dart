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

  Future<void> clearStudentInfo() async {
    await _prefs.remove('student_id');
    await _prefs.remove('student_name');
  }

  // ── Settings ──

  String? getThemePreference() => _prefs.getString('theme_preference');
  Future<void> setThemePreference(String value) =>
      _prefs.setString('theme_preference', value);

  String? getClassAutomationMode() => _prefs.getString('class_automation_mode');
  Future<void> setClassAutomationMode(String value) =>
      _prefs.setString('class_automation_mode', value);

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

  // ── Power cache ──

  String? getPowerCache() => _prefs.getString('saved_power_cache');
  String? getPowerCacheRoomId() =>
      _prefs.getString('saved_power_cache_room_id');
  int? getPowerCacheTime() => _prefs.getInt('saved_power_cache_time');

  Future<void> setPowerCache(String json, {required String roomId}) async {
    await _prefs.setString('saved_power_cache', json);
    await _prefs.setString('saved_power_cache_room_id', roomId);
    await _prefs.setInt(
      'saved_power_cache_time',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> clearPowerCache() async {
    await _prefs.remove('saved_power_cache');
    await _prefs.remove('saved_power_cache_room_id');
    await _prefs.remove('saved_power_cache_time');
    await _prefs.remove('saved_power_cache_date');
  }

  // ── Generic cache helpers ──

  Future<void> _setCache(String dataKey, String timeKey, String json) async {
    await _prefs.setString(dataKey, json);
    await _prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);
  }

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

  Future<void> clearUserToolCaches() async {
    await Future.wait([
      _clearCache('jp_cache', 'jp_cache_time'),
      _clearCache('repair_cache', 'repair_cache_time'),
      _clearCache('exam_cache', 'exam_cache_time'),
      _clearCache('ykt_cache', 'ykt_cache_time'),
      _clearCache('netauth_cache', 'netauth_cache_time'),
    ]);
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
