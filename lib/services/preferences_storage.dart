import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKey = 'theme_preference';
const _classAutomationModeKey = 'class_automation_mode';
const _savedPowerRoomIdKey = 'saved_power_room_id';
const _savedPowerCacheKey = 'saved_power_cache';
const _savedPowerCacheDateKey = 'saved_power_cache_date';
const _savedPowerCacheTimeKey = 'saved_power_cache_time';
const _jpCacheKey = 'jp_cache';
const _jpCacheTimeKey = 'jp_cache_time';
const _repairCacheKey = 'repair_cache';
const _repairCacheTimeKey = 'repair_cache_time';
const _examCacheKey = 'exam_cache';
const _examCacheTimeKey = 'exam_cache_time';
const _yktCacheKey = 'ykt_cache';
const _yktCacheTimeKey = 'ykt_cache_time';
const _netauthCacheKey = 'netauth_cache';
const _netauthCacheTimeKey = 'netauth_cache_time';

class PreferencesStorage {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? getStudentId() => _prefs.getString('student_id');
  Future<void> setStudentId(String id) => _prefs.setString('student_id', id);

  String? getStudentName() => _prefs.getString('student_name');
  Future<void> setStudentName(String name) =>
      _prefs.setString('student_name', name);

  Future<void> clearStudentInfo() async {
    await _prefs.remove('student_id');
    await _prefs.remove('student_name');
  }

  String? getThemePreference() => _prefs.getString(_themePreferenceKey);

  Future<void> setThemePreference(String value) =>
      _prefs.setString(_themePreferenceKey, value);

  String? getClassAutomationMode() =>
      _prefs.getString(_classAutomationModeKey);

  Future<void> setClassAutomationMode(String value) =>
      _prefs.setString(_classAutomationModeKey, value);

  String? getSavedPowerRoomId() => _prefs.getString(_savedPowerRoomIdKey);

  Future<void> setSavedPowerRoomId(String roomId) async {
    final value = roomId.trim();
    if (value.isEmpty) {
      await _prefs.remove(_savedPowerRoomIdKey);
      return;
    }
    await _prefs.setString(_savedPowerRoomIdKey, value);
  }

  String? getPowerCache() => _prefs.getString(_savedPowerCacheKey);
  String? getPowerCacheDate() => _prefs.getString(_savedPowerCacheDateKey);

  Future<void> setPowerCache(String json, String date) async {
    await _prefs.setString(_savedPowerCacheKey, json);
    await _prefs.setString(_savedPowerCacheDateKey, date);
    await _prefs.setInt(
      _savedPowerCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> clearPowerCache() async {
    await _prefs.remove(_savedPowerCacheKey);
    await _prefs.remove(_savedPowerCacheDateKey);
    await _prefs.remove(_savedPowerCacheTimeKey);
  }

  int? getPowerCacheTime() => _prefs.getInt(_savedPowerCacheTimeKey);

  // ── JP cache ──

  String? getJpCache() => _prefs.getString(_jpCacheKey);
  int? getJpCacheTime() => _prefs.getInt(_jpCacheTimeKey);

  Future<void> setJpCache(String json) async {
    await _prefs.setString(_jpCacheKey, json);
    await _prefs.setInt(_jpCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clearJpCache() async {
    await _prefs.remove(_jpCacheKey);
    await _prefs.remove(_jpCacheTimeKey);
  }

  // ── Repair cache ──

  String? getRepairCache() => _prefs.getString(_repairCacheKey);
  int? getRepairCacheTime() => _prefs.getInt(_repairCacheTimeKey);

  Future<void> setRepairCache(String json) async {
    await _prefs.setString(_repairCacheKey, json);
    await _prefs.setInt(
      _repairCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> clearRepairCache() async {
    await _prefs.remove(_repairCacheKey);
    await _prefs.remove(_repairCacheTimeKey);
  }

  // ── Exam cache ──

  String? getExamCache() => _prefs.getString(_examCacheKey);
  int? getExamCacheTime() => _prefs.getInt(_examCacheTimeKey);

  Future<void> setExamCache(String json) async {
    await _prefs.setString(_examCacheKey, json);
    await _prefs.setInt(_examCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ── YKT cache ──

  String? getYktCache() => _prefs.getString(_yktCacheKey);
  int? getYktCacheTime() => _prefs.getInt(_yktCacheTimeKey);

  Future<void> setYktCache(String json) async {
    await _prefs.setString(_yktCacheKey, json);
    await _prefs.setInt(_yktCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ── NetAuth cache ──

  String? getNetauthCache() => _prefs.getString(_netauthCacheKey);
  int? getNetauthCacheTime() => _prefs.getInt(_netauthCacheTimeKey);

  Future<void> setNetauthCache(String json) async {
    await _prefs.setString(_netauthCacheKey, json);
    await _prefs.setInt(
      _netauthCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Cache validity ──

  static bool isCacheValid(int? cacheTimeMs, Duration ttl) {
    if (cacheTimeMs == null) return false;
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(cacheTimeMs);
    final now = DateTime.now();
    if (now.difference(cacheTime) > ttl) return false;
    final today3am = DateTime(now.year, now.month, now.day, 3);
    if (cacheTime.isBefore(today3am) && now.isAfter(today3am)) return false;
    return true;
  }
}
