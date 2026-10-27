import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/app_settings.dart';
import 'package:xzitpocket/pages/timetable/course_picker_sheet.dart';
import 'package:xzitpocket/pages/profile/course_reminder_settings_page.dart';
import 'package:xzitpocket/providers/app_settings_provider.dart';
import 'package:xzitpocket/providers/config_provider.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_theme.dart';

const _appBridge = MethodChannel('live.xuda.xzitpocket/app_bridge');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_appBridge, null);
  });

  testWidgets('revoked permissions disable previously enabled automation', (
    tester,
  ) async {
    final container = await _pumpPage(
      tester,
      initialValues: {
        'course_reminder_enabled': true,
        'class_automation_mode': 'dnd',
      },
    );
    addTearDown(container.dispose);

    await tester.pump(const Duration(milliseconds: 100));

    final settings = container.read(appSettingsProvider);
    expect(settings.courseReminderEnabled, isFalse);
    expect(settings.classAutomationMode, ClassAutomationMode.off);
  });

  testWidgets('missing permissions cannot select reminders or class dnd', (
    tester,
  ) async {
    // The 课堂勿扰 row opens the same wheel picker as 选择星期; its selection is
    // committed when 确定 is pressed.
    final container = await _pumpPage(tester);
    addTearDown(container.dispose);

    await tester.tap(find.text('开启课程提醒'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(appSettingsProvider).courseReminderEnabled, isFalse);

    // The section label carries the same text, so target the settings row.
    final row = find.widgetWithText(FTile, '课堂勿扰');
    await tester.dragUntilVisible(
      row,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(CourseWheelPickerSheet), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      container.read(appSettingsProvider).classAutomationMode,
      ClassAutomationMode.off,
    );
  });

  testWidgets('wearable compatibility requires course reminders', (
    tester,
  ) async {
    final container = await _pumpPage(tester);
    addTearDown(container.dispose);

    await tester.tap(find.text('兼容穿戴设备通知'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      container.read(appSettingsProvider).wearableNotificationCompatibility,
      isFalse,
    );
  });
}

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final storage = PreferencesStorage();
  await storage.init();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_appBridge, (call) async {
        if (call.method == 'getCourseReminderPermissions') {
          return <String, Object>{
            'notificationsGranted': false,
            'exactAlarmGranted': false,
            'dndGranted': false,
            'batteryOptimizationIgnored': true,
          };
        }
        return null;
      });
  final container = ProviderContainer(
    overrides: [preferencesStorageProvider.overrideWithValue(storage)],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: FLocalizations.localizationsDelegates,
        supportedLocales: FLocalizations.supportedLocales,
        builder: (context, child) => FTheme(
          data: AppTheme.light,
          child: FToaster(child: child!),
        ),
        home: const CourseReminderSettingsPage(),
      ),
    ),
  );
  await tester.pump();
  return container;
}
