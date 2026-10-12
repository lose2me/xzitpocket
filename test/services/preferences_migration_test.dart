import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/services/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferencesStorage storage;

  Future<void> initStorage(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    storage = PreferencesStorage();
    await storage.init();
  }

  group('migrateForVersionCode', () {
    test('records version code and schema on a fresh install', () async {
      await initStorage({});

      final cleaned = await storage.migrateForVersionCode('2100');

      expect(cleaned, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('installed_version_code'), '2100');
      expect(
        prefs.getInt('settings_schema_version'),
        PreferencesStorage.settingsSchemaVersion,
      );
    });

    test('is a no-op when the version code is unchanged', () async {
      await initStorage({
        'installed_version_code': '2100',
        'settings_schema_version': PreferencesStorage.settingsSchemaVersion,
        // Stale keys must survive when no version change is detected; they
        // are only pruned as part of an upgrade migration.
        'major_name': '计算机科学与技术',
      });

      final cleaned = await storage.migrateForVersionCode('2100');

      expect(cleaned, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('major_name'), isTrue);
    });

    test('removes deprecated keys after a version change', () async {
      await initStorage({
        'installed_version_code': '2000',
        'settings_schema_version': PreferencesStorage.settingsSchemaVersion,
        'major_name': '计算机科学与技术',
        'timetable_component_opacity': 0.7,
        'timetable_solid_background': 'blue',
        'student_id': '20260001',
      });

      final cleaned = await storage.migrateForVersionCode('2100');

      expect(cleaned, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('major_name'), isFalse);
      expect(prefs.containsKey('timetable_component_opacity'), isFalse);
      expect(prefs.containsKey('timetable_solid_background'), isFalse);
      expect(prefs.getString('student_id'), '20260001');
    });

    test('removes incompatible value types and restores defaults', () async {
      await initStorage({
        'installed_version_code': '2000',
        'settings_schema_version': PreferencesStorage.settingsSchemaVersion,
        'timetable_section_height': 'not-a-double',
        'show_today_grid_lines': 'yes',
        'course_reminder_minutes': 15,
      });

      final cleaned = await storage.migrateForVersionCode('2100');

      expect(cleaned, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('timetable_section_height'), isFalse);
      expect(prefs.containsKey('show_today_grid_lines'), isFalse);
      // Getter falls back to the default after the incompatible value is gone.
      expect(storage.getTimetableSectionHeight(), 60.0);
      expect(storage.getShowTodayGridLines(), isFalse);
      // Compatible values are untouched.
      expect(prefs.getInt('course_reminder_minutes'), 15);
    });

    test('accepts numeric values for double-typed keys', () async {
      await initStorage({
        'installed_version_code': '2000',
        'settings_schema_version': PreferencesStorage.settingsSchemaVersion,
        // Whole doubles can round-trip as ints on some platforms.
        'timetable_section_height': 72,
      });

      final cleaned = await storage.migrateForVersionCode('2100');

      expect(cleaned, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('timetable_section_height'), isTrue);
    });

    test('prunes invalid hidden service features', () async {
      await initStorage({
        'installed_version_code': '2000',
        'settings_schema_version': PreferencesStorage.settingsSchemaVersion,
        'hidden_service_features': ['power', 'removed_feature', 'exams'],
      });

      final cleaned = await storage.migrateForVersionCode('2100');

      expect(cleaned, isTrue);
      expect(storage.getHiddenServiceFeatures(), {'power', 'exams'});
    });

    test('keeps the disclaimer flag across migrations', () async {
      await initStorage({
        'installed_version_code': '2000',
        'settings_schema_version': PreferencesStorage.settingsSchemaVersion,
        'disclaimer_accepted': true,
        'major_name': 'stale',
      });

      await storage.migrateForVersionCode('2100');

      expect(storage.getDisclaimerAccepted(), isTrue);
    });

    test('validates dynamic repair detail cache keys', () async {
      await initStorage({
        'installed_version_code': '2000',
        'settings_schema_version': PreferencesStorage.settingsSchemaVersion,
        'repair_detail_cache_form1': '{"a":1}',
        'repair_detail_cache_time_form1': 123,
        'repair_detail_cache_broken': 456,
      });

      final cleaned = await storage.migrateForVersionCode('2100');

      expect(cleaned, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('repair_detail_cache_form1'), isTrue);
      expect(prefs.containsKey('repair_detail_cache_time_form1'), isTrue);
      expect(prefs.containsKey('repair_detail_cache_broken'), isFalse);
    });
  });

  group('disclaimer acceptance', () {
    test('defaults to false and persists once accepted', () async {
      await initStorage({});
      expect(storage.getDisclaimerAccepted(), isFalse);

      await storage.setDisclaimerAccepted(true);
      expect(storage.getDisclaimerAccepted(), isTrue);
    });

    test('is not cleared by resetTimetableAppearance', () async {
      await initStorage({'disclaimer_accepted': true});

      await storage.resetTimetableAppearance();

      expect(storage.getDisclaimerAccepted(), isTrue);
    });
  });
}
