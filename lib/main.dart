import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'app.dart';
import 'constants/semester_config.dart';
import 'pages/home_page.dart';
import 'providers/config_provider.dart';
import 'services/course_storage.dart';
import 'services/preferences_storage.dart';
import 'services/talker.dart';
import 'services/tools_data_manager.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupErrorHooks(talker);

  final courseStorage = CourseStorage();
  final preferencesStorage = PreferencesStorage();
  await courseStorage.init();
  await preferencesStorage.init();
  ToolsDataManager.instance.initialize(preferencesStorage);
  await WidgetService.init();

  final courses = courseStorage.getCourses();
  try {
    await WidgetService.updateWidget(
      courses: courses,
      semesterStart: semesterStartDate,
    );
  } on WidgetSyncException catch (e) {
    talker.error('Initial widget sync failed', e);
  }

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
}
