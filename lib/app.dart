import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'constants/semester_config.dart';
import 'models/book_list.dart';
import 'pages/home_page.dart';
import 'pages/timetable/timetable_page.dart';
import 'providers/app_settings_provider.dart';
import 'providers/config_provider.dart';
import 'providers/schedule_provider.dart';
import 'services/course_storage.dart';
import 'services/control_service.dart';
import 'services/course_upload.dart';
import 'services/talker.dart';
import 'services/tools_data_manager.dart';
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
  double? _toastOpacity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncCoursesToControl());
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
      unawaited(ToolsDataManager.instance.checkCampusNetwork(force: true));
      unawaited(_refreshSchoolCalendarAndWidget());
      unawaited(_syncCoursesToControl());
      unawaited(ControlService.instance.track('foreground'));
    }
  }

  /// Pushes the timetable and the cached book list to control when the app
  /// returns to the foreground, so the console stays current without a fresh
  /// OA login. Content-hash dedup makes it a no-op when nothing changed.
  Future<void> _syncCoursesToControl() async {
    final courses = ref.read(scheduleProvider).value ?? const [];
    if (courses.isEmpty) return;
    final prefs = ref.read(preferencesStorageProvider);
    BookListResult? books;
    final cached = prefs.getBookCache();
    if (cached != null && cached.isNotEmpty) {
      try {
        books = BookListPageResult.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        ).books;
      } catch (error, stackTrace) {
        talker.debug('书单缓存解析失败', error, stackTrace);
      }
    }
    await uploadCoursesAndBooks(storage: prefs, courses: courses, books: books);
  }

  Future<void> _refreshSchoolCalendarAndWidget() async {
    try {
      final prefs = ref.read(preferencesStorageProvider);
      final changed = await ControlService.instance
          .refreshSchoolCalendarIfChanged(prefs);
      if (changed) {
        if (!mounted) return;
        await ref.read(scheduleProvider.notifier).applyCloudAdjustments();
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
        final transition = _SmoothThemeTransition(
          transitionKey:
              '${Theme.of(context).brightness.name}:'
              '${theme.colors.background.toARGB32()}:'
              '${theme.colors.primary.toARGB32()}',
          theme: theme,
          child: child!,
        );
        // 「不受系统文字缩放影响」开关（默认开启）：作用于没有独立字号设置的
        // 全部文字；课表内部已有自己的 withNoTextScaling 与字号设置，不受影响。
        final themed = settings.ignoreSystemTextScale
            ? MediaQuery.withNoTextScaling(child: transition)
            : transition;
        // Vendored talker_flutter (and other legacy packages) still use
        // package:flutter/material.dart. Bridge their theme and localizations
        // until those dependencies move to package:material_ui.
        // ignore: deprecated_member_use
        return MaterialUiCompatibilityBridge(child: themed);
      },
      home: HomePage(key: HomePage.globalKey),
    );
  }
}

class _SmoothThemeTransition extends StatefulWidget {
  final Object transitionKey;
  final FThemeData theme;
  final Widget child;

  const _SmoothThemeTransition({
    required this.transitionKey,
    required this.theme,
    required this.child,
  });

  @override
  State<_SmoothThemeTransition> createState() => _SmoothThemeTransitionState();
}

class _SmoothThemeTransitionState extends State<_SmoothThemeTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late Object _transitionKey;
  late FThemeData _beginTheme;
  late FThemeData _endTheme;

  @override
  void initState() {
    super.initState();
    _transitionKey = widget.transitionKey;
    _beginTheme = widget.theme;
    _endTheme = widget.theme;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubicEmphasized,
    );
    // Snap the lerp state when a transition finishes so repeated theme
    // changes cannot accumulate stale begin/end pairs (defensive fix for
    // the blank-screen regression reported after leaving settings).
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          mounted &&
          !identical(_beginTheme, _endTheme)) {
        setState(() => _beginTheme = _endTheme);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _SmoothThemeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_transitionKey == widget.transitionKey) return;
    _beginTheme = FThemeData.lerp(_beginTheme, _endTheme, _animation.value);
    _endTheme = widget.theme;
    _transitionKey = widget.transitionKey;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: FToaster(child: FTooltipGroup(child: widget.child)),
    builder: (context, child) {
      final progress = _animation.value;
      final theme = FThemeData.lerp(_beginTheme, _endTheme, progress);
      return FBasicTheme(
        data: theme,
        child: Theme(
          data: theme.toApproximateMaterialTheme(),
          child: IconTheme(
            data: IconThemeData(size: 20, color: theme.colors.foreground),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: theme.colors.background, child: child),
                if (!_controller.isCompleted)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _ThemeSweepPainter(
                        progress: progress,
                        color: Color.lerp(
                          _endTheme.colors.background,
                          _endTheme.colors.primary,
                          0.14,
                        )!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ThemeSweepPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ThemeSweepPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0 || progress >= 1) return;
    const samples = 16;
    final center = -0.25 + progress * 1.5;
    final motionFade = 4 * progress * (1 - progress);
    final colors = <Color>[];
    final stops = <double>[];
    for (var index = 0; index <= samples; index++) {
      final position = index / samples;
      final distance = (position - center).abs();
      final strength = (1 - distance / 0.28).clamp(0.0, 1.0);
      colors.add(
        color.withValues(alpha: 0.07 * strength * strength * motionFade),
      );
      stops.add(position);
    }
    final bounds = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: colors,
        stops: stops,
      ).createShader(bounds);
    canvas.drawRect(bounds, paint);
  }

  @override
  bool shouldRepaint(covariant _ThemeSweepPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
