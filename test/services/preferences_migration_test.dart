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
      expect(storage.getShowTodayGridLines(), isTrue);
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

    test('composes a course text template from legacy booleans', () async {
      await initStorage({
        'installed_version_code': '2000',
        'settings_schema_version': PreferencesStorage.settingsSchemaVersion,
        'timetable_show_start_time': true,
        'timetable_hide_teacher': false,
        'timetable_hide_teacher_brackets': false,
        'timetable_remove_location_at': true,
      });

      final cleaned = await storage.migrateForVersionCode('2100');

      expect(cleaned, isTrue);
      expect(
        storage.getTimetableCourseTextTemplate(),
        r'[b]{课程}[/b]\n{时间}\n{地点}\n【{教师}】',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('timetable_show_start_time'), isFalse);
      expect(prefs.containsKey('timetable_hide_teacher'), isFalse);
    });

    test('keeps an existing template untouched during migration', () async {
      await initStorage({
        'installed_version_code': '2000',
        'settings_schema_version': PreferencesStorage.settingsSchemaVersion,
        'timetable_course_text_template': '{课程}',
        'timetable_hide_teacher': false,
      });

      await storage.migrateForVersionCode('2100');

      expect(storage.getTimetableCourseTextTemplate(), '{课程}');
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

  group('legacy personalization snapshots', () {
    test('are rejected with the unsupported toast message', () async {
      await initStorage({'timetable_course_text_size': 12.0});

      expect(
        storage.isLegacyPersonalizationSnapshot({
          'timetable_hide_teacher': false,
        }),
        isTrue,
      );
      expect(
        () => storage.restorePersonalizationSnapshot({
          'timetable_hide_teacher': false,
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '旧版分享码不支持',
          ),
        ),
      );
      // 拒绝后不写入任何值。
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('timetable_hide_teacher'), isFalse);
    });

    test('current snapshots are still accepted', () async {
      await initStorage({});

      expect(
        storage.isLegacyPersonalizationSnapshot({
          'timetable_course_text_template': '{课程}',
        }),
        isFalse,
      );
      await storage.restorePersonalizationSnapshot({
        'timetable_course_text_template': '{课程}',
      });
      expect(storage.getTimetableCourseTextTemplate(), '{课程}');
    });
  });
}
