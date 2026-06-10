import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKey = 'theme_preference';
const _classAutomationModeKey = 'class_automation_mode';
const _savedPowerRoomIdKey = 'saved_power_room_id';
const _savedPowerCacheKey = 'saved_power_cache';
const _savedPowerCacheDateKey = 'saved_power_cache_date';

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
  }

  Future<void> clearPowerCache() async {
    await _prefs.remove(_savedPowerCacheKey);
    await _prefs.remove(_savedPowerCacheDateKey);
  }
}
