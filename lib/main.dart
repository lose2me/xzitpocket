import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'app.dart';
import 'constants/semester_config.dart';
import 'pages/home_page.dart';
import 'providers/config_provider.dart';
import 'services/storage_service.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();
  await WidgetService.init();

  final courses = storage.getCourses();
  await WidgetService.updateWidget(
    courses: courses,
    semesterStart: semesterStartDate,
    semesterTotalWeeks: semesterTotalWeeks,
  );

  // Listen for widget clicks → switch to timetable tab
  HomeWidget.widgetClicked.listen((_) {
    HomePage.globalKey.currentState?.switchToTimetable();
  });

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: App(storage: storage),
    ),
  );
}
