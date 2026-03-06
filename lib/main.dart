import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'app.dart';
import 'pages/home_page.dart';
import 'providers/config_provider.dart';
import 'services/storage_service.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();
  await WidgetService.init();

  // Update widget with current data on app launch
  final courses = storage.getCourses();
  WidgetService.updateWidget(
    courses: courses,
    semesterStart: semesterStartDate,
  );

  // Listen for widget clicks → switch to timetable tab
  HomeWidget.widgetClicked.listen((_) {
    HomePage.globalKey.currentState?.switchToTimetable();
  });

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: const App(),
    ),
  );
}
