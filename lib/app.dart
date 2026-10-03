import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'constants/semester_config.dart';
import 'models/school_calendar.dart';
import 'pages/home_page.dart';
import 'pages/timetable/timetable_page.dart';
import 'providers/app_settings_provider.dart';
import 'providers/config_provider.dart';
import 'providers/schedule_provider.dart';
import 'services/course_storage.dart';
import 'services/control_service.dart';
import 'services/talker.dart';
import 'services/widget_service.dart';
import 'ui/app_theme.dart';
import 'utils/snackbar_helper.dart';

class App extends ConsumerStatefulWidget {
  final CourseStorage courseStorage;

  const App({super.key, required this.courseStorage});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  Timer? _heartbeatTimer;
  double? _toastOpacity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      unawaited(ControlService.instance.track('heartbeat'));
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
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
      unawaited(_refreshSchoolCalendarAndWidget());
      unawaited(ControlService.instance.track('foreground'));
    }
  }

  Future<void> _refreshSchoolCalendarAndWidget() async {
    try {
      if (await ControlService.instance.checkHealth()) {
        final prefs = ref.read(preferencesStorageProvider);
        final versions = await ControlService.instance.fetchConfigVersions();
        if (prefs.getSchoolCalendarCache() == null ||
            prefs.getSchoolCalendarVersion() != versions.schoolCalendar) {
          final days = await ControlService.instance.fetchSchoolCalendar();
          if (!mounted) return;
          semesterCalendar.replaceDays(days);
          await prefs.setSchoolCalendarCache(schoolCalendarDaysToJson(days));
          await prefs.setSchoolCalendarVersion(versions.schoolCalendar);
          await ref.read(scheduleProvider.notifier).applyCloudAdjustments();
        }
      }
    } catch (error, stackTrace) {
      talker.debug('回到前台时刷新校历失败，继续使用当前校历', error, stackTrace);
    }
    if (!mounted) return;
    await _syncWidgetsFromCache();
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
    final settings = ref.watch(appSettingsProvider);
    if (_toastOpacity != settings.toastOpacity) {
      _toastOpacity = settings.toastOpacity;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setAppToastOpacity(settings.toastOpacity);
      });
    }
    final lightTheme = AppTheme.lightFor(
      settings.themeColor,
      customColor: settings.customThemeColor,
      pageBackgroundColor: settings.pageBackgroundColor,
      customPageBackgroundColor: settings.customPageBackgroundColor,
    );
    final darkTheme = AppTheme.darkFor(
      settings.themeColor,
      customColor: settings.customThemeColor,
      pageBackgroundColor: settings.pageBackgroundColor,
      customPageBackgroundColor: settings.customPageBackgroundColor,
    );

    return MaterialApp(
      title: '掌上徐工',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      theme: lightTheme.toApproximateMaterialTheme(),
      darkTheme: darkTheme.toApproximateMaterialTheme(),
      themeMode: settings.themePreference.themeMode,
      themeAnimationDuration: Duration.zero,
      navigatorObservers: [TalkerRouteObserver(talker)],
      builder: (context, child) {
        final theme = Theme.of(context).brightness == Brightness.dark
            ? darkTheme
            : lightTheme;
        return _DiagonalThemeTransition(
          transitionKey:
              '${Theme.of(context).brightness.name}:${theme.colors.background.toARGB32()}',
          previousColor: theme.colors.background,
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

class _DiagonalThemeTransition extends StatefulWidget {
  final Object transitionKey;
  final Color previousColor;
  final Widget child;

  const _DiagonalThemeTransition({
    required this.transitionKey,
    required this.previousColor,
    required this.child,
  });

  @override
  State<_DiagonalThemeTransition> createState() =>
      _DiagonalThemeTransitionState();
}

class _DiagonalThemeTransitionState extends State<_DiagonalThemeTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Object _transitionKey;
  late Color _currentColor;
  Color? _oldColor;

  @override
  void initState() {
    super.initState();
    _transitionKey = widget.transitionKey;
    _currentColor = widget.previousColor;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _DiagonalThemeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_transitionKey == widget.transitionKey) return;
    _oldColor = _currentColor;
    _currentColor = widget.previousColor;
    _transitionKey = widget.transitionKey;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_oldColor != null)
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.isCompleted) return const SizedBox.shrink();
              return ClipPath(
                clipper: _DiagonalThemeClipper(_controller.value),
                child: ColoredBox(color: _oldColor!.withValues(alpha: 0.82)),
              );
            },
          ),
        ),
    ],
  );
}

class _DiagonalThemeClipper extends CustomClipper<Path> {
  final double progress;

  const _DiagonalThemeClipper(this.progress);

  @override
  Path getClip(Size size) {
    if (size.isEmpty || progress >= 1) return Path();
    final cutoff = progress * 2 - 1;
    final points = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ];
    double score(Offset point) =>
        point.dx / size.width - point.dy / size.height - cutoff;
    final clipped = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final currentScore = score(current);
      final nextScore = score(next);
      if (currentScore >= 0) clipped.add(current);
      if ((currentScore >= 0) != (nextScore >= 0)) {
        final fraction = currentScore / (currentScore - nextScore);
        clipped.add(Offset.lerp(current, next, fraction)!);
      }
    }
    if (clipped.isEmpty) return Path();
    return Path()..addPolygon(clipped, true);
  }

  @override
  bool shouldReclip(covariant _DiagonalThemeClipper oldClipper) =>
      oldClipper.progress != progress;
}
