import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/app_settings.dart';
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
    final container = await _pumpPage(tester);
    addTearDown(container.dispose);

    await tester.tap(find.text('开启课程提醒'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(appSettingsProvider).courseReminderEnabled, isFalse);

    await tester.dragUntilVisible(
      find.text('上课恢复'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.text('上课恢复'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      container.read(appSettingsProvider).classAutomationMode,
      ClassAutomationMode.off,
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
