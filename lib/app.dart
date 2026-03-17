import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'constants/semester_config.dart';
import 'pages/home_page.dart';
import 'pages/timetable/timetable_page.dart';
import 'services/storage_service.dart';
import 'services/widget_service.dart';

class App extends StatefulWidget {
  final StorageService storage;

  const App({super.key, required this.storage});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  static final _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomePage(key: HomePage.globalKey),
      ),
    ],
  );

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
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        unawaited(WidgetService.refreshWidget());
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
    await WidgetService.updateWidget(
      courses: widget.storage.getCourses(),
      semesterStart: semesterStartDate,
      semesterTotalWeeks: semesterTotalWeeks,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.0,
      child: MaterialApp.router(
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
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
