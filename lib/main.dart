import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'app.dart';
import 'constants/semester_config.dart';
import 'pages/home_page.dart';
import 'providers/config_provider.dart';
import 'services/course_storage.dart';
import 'services/control_service.dart';
import 'services/preferences_storage.dart';
import 'services/talker.dart';
import 'services/tools_data_manager.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupErrorHooks(talker);

  final courseStorage = CourseStorage();
  final preferencesStorage = PreferencesStorage();
  // These are the only startup operations required to build the first page.
  // Run them concurrently; platform widget sync and network probes happen
  // after the first frame so a cold launch can paint immediately.
  await Future.wait([courseStorage.init(), preferencesStorage.init()]);

  // Listen for widget clicks → switch to timetable tab
  HomeWidget.widgetClicked.listen((_) {
    HomePage.globalKey.currentState?.switchToTimetable();
  });

  runApp(
    ProviderScope(
      overrides: [
        courseStorageProvider.overrideWithValue(courseStorage),
        preferencesStorageProvider.overrideWithValue(preferencesStorage),
      ],
      child: App(courseStorage: courseStorage),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_finishStartup(courseStorage, preferencesStorage));
  });
}

Future<void> _finishStartup(
  CourseStorage courseStorage,
  PreferencesStorage preferencesStorage,
) async {
  ToolsDataManager.instance.initialize(preferencesStorage);
  await ControlService.instance.initialize();
  final studentId = preferencesStorage.getStudentId();
  if (studentId != null && studentId.isNotEmpty) {
    unawaited(
      ControlService.instance.syncAfterOaLogin(
        studentId: studentId,
        displayName: preferencesStorage.getStudentName() ?? '',
      ),
    );
  }
  await WidgetService.init();
  try {
    await WidgetService.updateWidget(
      courses: courseStorage.getCourses(),
      semesterStart: semesterStartDate,
    );
  } on WidgetSyncException catch (e) {
    talker.error('Initial widget sync failed', e);
  }
}
