import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'constants/semester_config.dart';
import 'models/book_list.dart';
import 'pages/home_page.dart';
import 'pages/timetable/timetable_page.dart';
import 'providers/app_settings_provider.dart';
import 'providers/config_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/secondary_schedule_provider.dart';
import 'services/course_storage.dart';
import 'services/preferences_storage.dart';
import 'services/control_service.dart';
import 'services/course_upload.dart';
import 'services/talker.dart';
import 'services/tools_data_manager.dart';
import 'services/widget_service.dart';
import 'ui/app_feedback.dart';
import 'ui/app_routes.dart';
import 'ui/app_theme.dart';
import 'ui/update_prompt.dart';
import 'utils/app_version.dart';
import 'utils/snackbar_helper.dart';

class App extends ConsumerStatefulWidget {
  final CourseStorage courseStorage;

  const App({super.key, required this.courseStorage});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  double? _toastOpacity;
  bool _updatePromptRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncCoursesToControl());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybePromptUpdate());
      unawaited(_finishStartup());
    });
  }

  Future<void> _finishStartup() async {
    final prefs = ref.read(preferencesStorageProvider);
    ToolsDataManager.instance.initialize(prefs);
    await ControlService.instance.initialize();
    await _logoutIfUpgraded(prefs);
    if (!mounted) return;
    final studentId = prefs.getStudentId();
    if (ControlService.instance.serviceAvailable &&
        studentId != null &&
        studentId.isNotEmpty) {
      unawaited(
        ControlService.instance.syncAfterOaLogin(
          studentId: studentId,
          displayName: prefs.getStudentName() ?? '',
          collegeName: prefs.getCollegeName() ?? '',
          className: prefs.getClassName() ?? '',
        ),
      );
    }
    await WidgetService.init();
    if (!mounted) return;
    // Apply through the notifier: the first frame may already have read the
    // stored timetable, so changing Hive alone would leave that state stale.
    await _refreshSchoolCalendarAndWidget();
  }

  /// A new build invalidates account-scoped state (caches, timetable and the
  /// control session). Sign out once after an upgrade so the next login starts
  /// from a clean slate; fresh installs and downgrades keep the session.
  Future<void> _logoutIfUpgraded(PreferencesStorage prefs) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final previous = prefs.getLastRunVersion();
      final loggedIn = (prefs.getStudentId() ?? '').isNotEmpty;
      await prefs.setLastRunVersion(info.version);
      if (!shouldLogoutAfterUpgrade(
        previous: previous,
        current: info.version,
        loggedIn: loggedIn,
      )) {
        return;
      }
      try {
        await ref.read(scheduleProvider.notifier).clearAll();
      } on WidgetSyncException catch (error) {
        talker.warning('升级退出登录时刷新小组件失败', error);
      }
      await ref.read(secondaryScheduleProvider.notifier).clear();
      await ref.read(configProvider.notifier).logout();
      ref.read(authProvider.notifier).reset();
      talker.info('检测到版本升级（$previous -> ${info.version}），已退出账号');
    } catch (error, stackTrace) {
      talker.warning('升级退出登录失败', error, stackTrace);
    }
  }

  /// Checks the test release channel once per app version and shows the update
  /// dialog at most once for that version. The profile page keeps showing the
  /// update card regardless.
  Future<void> _maybePromptUpdate() async {
    if (_updatePromptRunning || !mounted) return;
    _updatePromptRunning = true;
    try {
      final prefs = ref.read(preferencesStorageProvider);
      final info = await PackageInfo.fromPlatform();
      final cached = ControlService.instance.cachedRelease(prefs, info.version);
      final result = await ControlService.instance.checkForUpdateState(
        prefs: prefs,
      );
      final release = result.reachable ? result.release : cached;
      if (release == null || !mounted) return;
      if (prefs.getUpdatePromptedVersion() == release.latestVersion) return;
      final update = await showAppConfirmDialog(
        context: context,
        title: '发现新版本 ${release.latestVersion}',
        message: '当前版本 ${info.version}，是否前往更新？',
        confirmLabel: '去更新',
        cancelLabel: '稍后',
      );
      await prefs.setUpdatePromptedVersion(release.latestVersion);
      if (!update || !mounted) return;
      await Navigator.of(context).push(
        appRoute(
          name: AppRouteNames.appUpdate,
          builder: (_) =>
              AppUpdatePage(release: release, currentVersion: info.version),
        ),
      );
    } catch (error, stackTrace) {
      talker.warning('启动更新检查失败', error, stackTrace);
    } finally {
      _updatePromptRunning = false;
    }
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
      unawaited(_maybePromptUpdate());
      unawaited(_reconnectAndCheckAccount());
    }
  }

  /// 回到前台时先恢复与 control 的连接，再检查账号是否被封禁；被封禁就退出
  /// 登录，避免继续使用旧会话。
  Future<void> _reconnectAndCheckAccount() async {
    await ControlService.instance.reconnect();
    if (!mounted) return;
    final prefs = ref.read(preferencesStorageProvider);
    final studentId = prefs.getStudentId();
    if (studentId == null || studentId.isEmpty) return;
    final reason = await ControlService.instance.loginBlockReason(studentId);
    if (reason == null || !mounted) return;
    await ref.read(scheduleProvider.notifier).clearAll();
    await ref.read(secondaryScheduleProvider.notifier).clear();
    await ref.read(configProvider.notifier).logout();
    ref.read(authProvider.notifier).reset();
    if (!mounted) return;
    showAppSnackBar(context, reason, severity: ToastSeverity.error);
  }

  /// Pushes the timetable and the cached book list to control when the app
  /// returns to the foreground, so the console stays current without a fresh
  /// OA login. The server deduplicates by course code.
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
    await uploadCoursesAndBooks(courses: courses, books: books);
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
    ref.listen(configProvider.select((config) => config.studentId), (
      previous,
      next,
    ) {
      if ((next ?? '').isNotEmpty && previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_maybePromptUpdate());
        });
      }
    });
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
        // The app always ignores the system text scale so its own layout
        // metrics stay consistent across devices.
        final themed = MediaQuery.withNoTextScaling(child: transition);
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
