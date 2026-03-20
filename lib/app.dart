import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants/semester_config.dart';
import 'pages/home_page.dart';
import 'pages/timetable/timetable_page.dart';
import 'providers/app_settings_provider.dart';
import 'services/storage_service.dart';
import 'services/widget_service.dart';

class App extends ConsumerStatefulWidget {
  final StorageService storage;

  const App({super.key, required this.storage});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Delay to let the system apply the configuration change before
    // the native widget re-reads uiMode.
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (mounted) {
        try {
          await WidgetService.refreshWidget();
        } on WidgetSyncException catch (e) {
          debugPrint('Widget refresh skipped after theme change: $e');
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TimetablePage.globalKey.currentState?.refreshForResume();
      unawaited(_syncWidgetsFromCache());
    }
  }

  Future<void> _syncWidgetsFromCache() async {
    try {
      await WidgetService.updateWidget(
        courses: widget.storage.getCourses(),
        semesterStart: semesterStartDate,
        semesterTotalWeeks: semesterTotalWeeks,
      );
    } on WidgetSyncException catch (e) {
      debugPrint('Widget sync on resume failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePreference = ref.watch(
      appSettingsProvider.select((state) => state.themePreference),
    );

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.0,
      child: MaterialApp(
        title: '掌上徐工',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF7EC8E8),
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF7EC8E8),
          useMaterial3: true,
          brightness: Brightness.dark,
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF303040),
            contentTextStyle: TextStyle(color: Color(0xFFE0E0E0)),
          ),
        ),
        themeMode: themePreference.themeMode,
        home: HomePage(key: HomePage.globalKey),
      ),
    );
  }
}
