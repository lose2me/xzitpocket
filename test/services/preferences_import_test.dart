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

  test('import replaces implicit defaults and preserves local data', () async {
    await initStorage({});
    await storage.setTimetableCourseInnerPadding(3.5);
    final snapshot = storage.getPersonalizationSnapshot();

    await initStorage({
      'theme_color': 'rose',
      'timetable_section_height': 99.0,
      'timetable_hide_date_under_day': true,
      'student_id': '20260001',
      'disclaimer_accepted': true,
      'timetable_background_path': '/local/image.jpg',
    });
    await storage.restorePersonalizationSnapshot(snapshot);

    expect(storage.getThemeColor(), isNull);
    expect(storage.hasTimetableSectionHeight(), isFalse);
    expect(storage.getTimetableHideDateUnderDay(), isFalse);
    expect(storage.getTimetableCourseInnerPadding(), 3.5);
    expect(storage.getStudentId(), '20260001');
    expect(storage.getDisclaimerAccepted(), isTrue);
    expect(storage.getTimetableBackgroundPath(), '/local/image.jpg');
  });

  test('validates all fields before applying a share code', () async {
    await initStorage({'theme_color': 'teal'});
    await expectLater(
      storage.restorePersonalizationSnapshot({
        'theme_color': 'rose',
        'timetable_section_height': 'invalid',
      }),
      throwsFormatException,
    );
    expect(storage.getThemeColor(), 'teal');
    await expectLater(
      storage.restorePersonalizationSnapshot({
        'timetable_course_text_template': '[b]{课程}',
      }),
      throwsFormatException,
    );
    expect(storage.getThemeColor(), 'teal');
  });

  test(
    'JSON integers are stored as doubles for dimension preferences',
    () async {
      await initStorage({});
      await storage.restorePersonalizationSnapshot({
        'timetable_section_height': 72,
      });
      expect(storage.getTimetableSectionHeight(), 72.0);
    },
  );

  test('course cache keys preserve distinct course codes', () async {
    await initStorage({});
    await storage.setResourceCourseCache('A/B', 'slash');
    await storage.setResourceCourseCache('A_B', 'underscore');
    expect(storage.getResourceCourseCache('A/B'), 'slash');
    expect(storage.getResourceCourseCache('A_B'), 'underscore');
  });
}
