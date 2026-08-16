import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'constants/semester_config.dart';
import 'pages/home_page.dart';
import 'pages/timetable/timetable_page.dart';
import 'providers/app_settings_provider.dart';
import 'services/course_storage.dart';
import 'services/talker.dart';
import 'services/widget_service.dart';
import 'ui/app_theme.dart';

class App extends ConsumerStatefulWidget {
  final CourseStorage courseStorage;

  const App({super.key, required this.courseStorage});

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
    unawaited(
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          try {
            await WidgetService.refreshWidget();
          } on WidgetSyncException catch (e) {
            talker.warning('Widget refresh skipped after theme change', e);
          }
        }
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    talker.info(
      '[LIFECYCLE] ${state == AppLifecycleState.resumed ? '回到前台' : '进入后台'}\n${state.name}',
    );
    if (state == AppLifecycleState.resumed) {
      TimetablePage.globalKey.currentState?.refreshForResume();
      unawaited(_syncWidgetsFromCache());
    }
  }

  Future<void> _syncWidgetsFromCache() async {
    try {
      await WidgetService.updateWidget(
        courses: widget.courseStorage.getCourses(),
        semesterStart: semesterStartDate,
      );
    } on WidgetSyncException catch (e) {
      talker.warning('Widget sync on resume failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePreference = ref.watch(
      appSettingsProvider.select((state) => state.themePreference),
    );

    return MaterialApp(
      title: '掌上徐工',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      theme: AppTheme.light.toApproximateMaterialTheme(),
      darkTheme: AppTheme.dark.toApproximateMaterialTheme(),
      themeMode: themePreference.themeMode,
      navigatorObservers: [TalkerRouteObserver(talker)],
      builder: (context, child) {
        final theme = Theme.of(context).brightness == Brightness.dark
            ? AppTheme.dark
            : AppTheme.light;
        return MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: FTheme(
            data: theme,
            child: IconTheme(
              data: IconThemeData(size: 20, color: theme.colors.foreground),
              child: FToaster(child: FTooltipGroup(child: child!)),
            ),
          ),
        );
      },
      home: HomePage(key: HomePage.globalKey),
    );
  }
}
