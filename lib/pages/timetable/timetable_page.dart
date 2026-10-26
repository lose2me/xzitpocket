import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../constants/time_slots.dart';
import '../../models/app_settings.dart';
import '../../models/course.dart';
import '../../models/school_calendar.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/control_service.dart';
import '../../services/credential_storage.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import 'timetable_providers.dart';
import '../../providers/secondary_schedule_provider.dart';
import '../../services/widget_service.dart';
import '../../utils/course_text_parser.dart';
import '../../utils/error_message.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import 'course_form_page.dart';
import 'timetable_grid.dart';
import 'timetable_layout.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  static final globalKey = GlobalKey<TimetablePageState>();

  @override
  ConsumerState<TimetablePage> createState() => TimetablePageState();
}

class _PendingDayAction {
  final int week;
  final int weekday;
  final String label;
  final DateTime deadline;
  final Future<void> Function() execute;
  final TimetableDayActionType type;
  final Map<int, Set<int>> affectedDaysByWeek;

  _PendingDayAction({
    required this.week,
    required this.weekday,
    required this.label,
    required this.execute,
    required this.type,
    required this.affectedDaysByWeek,
  }) : deadline = DateTime.now().add(const Duration(seconds: 3));

  Duration get remaining => deadline.difference(DateTime.now());
}

class TimetablePageState extends ConsumerState<TimetablePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final PageController _pageController;
  late final AnimationController _conflictCountdownController;
  late final AnimationController _dayActionPulseController;
  late final AnimationController _scheduleFlipController;
  late final AnimationController _noticeSlideController;
  late final AnimationController _noticeProgressController;
  Timer? _noticeTimer;
  bool _noticeVisible = false;
  static const _noticeDuration = Duration(seconds: 6);
  final _timetableViewportKey = GlobalKey();
  bool _isSyncing = false;
  bool _pageRefreshActive = false;
  bool _switchingSchedule = false;
  int _conflictRotationTick = 0;
  double _lastConflictCountdownValue = 0;
  Timer? _edgePageTimer;
  int? _edgePageTarget;
  int _dragGeneration = 0;
  bool _dayDragActive = false;
  int? _edgeTriggerSide;
  Timer? _dayActionTimer;
  _PendingDayAction? _pendingDayAction;

  static const _edgeTriggerHitWidth = 24.0;
  static const _edgeTriggerClosedWidth = 6.0;
  static const _edgeTriggerOpenWidth = 24.0;
  static const _edgeTriggerVisibleSlots = 9.0;

  @override
  void initState() {
    super.initState();
    semesterCalendar.addListener(_onCalendarChanged);
    final initialWeek = semesterCalendar
        .weekOf(DateTime.now())
        .clamp(1, _maxDisplayWeek());
    _pageController = PageController(initialPage: initialWeek - 1);
    _conflictCountdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _conflictCountdownController.addListener(() {
      final currentValue = _conflictCountdownController.value;
      if (currentValue < _lastConflictCountdownValue && mounted) {
        setState(() => _conflictRotationTick++);
      }
      _lastConflictCountdownValue = currentValue;
    });
    _conflictCountdownController.repeat();
    _dayActionPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scheduleFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _noticeSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _noticeProgressController = AnimationController(
      vsync: this,
      duration: _noticeDuration,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (initialWeek > 0) {
        ref.read(selectedWeekProvider.notifier).set(initialWeek);
      }
      _showNoticeIfNeeded();
    });
  }

  @override
  void dispose() {
    semesterCalendar.removeListener(_onCalendarChanged);
    _conflictCountdownController.dispose();
    _dayActionPulseController.dispose();
    _scheduleFlipController.dispose();
    _noticeTimer?.cancel();
    _noticeSlideController.dispose();
    _noticeProgressController.dispose();
    _edgePageTimer?.cancel();
    _dayActionTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onCalendarChanged() {
    if (!mounted) return;
    if (!semesterCalendar.calendarUpdateNotice) {
      unawaited(_hideNotice());
    }
    final maxWeek = _maxDisplayWeek();
    final selected = ref.read(selectedWeekProvider);
    final week = selected.clamp(1, maxWeek).toInt();
    if (week != selected) {
      ref.read(selectedWeekProvider.notifier).set(week);
    }
    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.round();
      if (currentPage != null && currentPage != week - 1) {
        _pageController.jumpToPage(week - 1);
      }
    }
    setState(() {});
  }

  /// 定位到当前周。[animate] 为 false 时直接跳页（小组件入口使用，无动画）。
  /// PageController 未 attach（冷启动）时仍会更新 selectedWeekProvider，
  /// initState 的 initialPage 也基于当前周，保证最终定位一致。
  void jumpToCurrentWeek({bool animate = true}) {
    final maxWeek = _maxDisplayWeek();
    final week = semesterCalendar.weekOf(DateTime.now()).clamp(1, maxWeek);
    if (_pageController.hasClients) {
      final current =
          _pageController.page?.round() ?? ref.read(selectedWeekProvider) - 1;
      if (current != week - 1) {
        if (animate) {
          unawaited(
            _pageController.animateToPage(
              week - 1,
              duration: Duration(
                milliseconds: (260 + (current - (week - 1)).abs() * 70).clamp(
                  260,
                  700,
                ),
              ),
              curve: Curves.easeInOutCubic,
            ),
          );
        } else {
          _pageController.jumpToPage(week - 1);
        }
      }
      ref.read(selectedWeekProvider.notifier).set(week);
    } else {
      ref.read(selectedWeekProvider.notifier).set(week);
    }
  }

  void _onDayDragUpdate(Offset position) {
    if (!_dayDragActive) return;
    _updateEdgeTrigger(position);
    _scheduleEdgePageIfNeeded();
  }

  void _onDayDragStart() {
    setState(() {
      _dayDragActive = true;
      _edgeTriggerSide = null;
    });
    _dragGeneration++;
  }

  void _updateEdgeTrigger(Offset position) {
    final renderObject = _timetableViewportKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderBox) {
      _setEdgeTriggerSide(null);
      return;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    final local = position - origin;
    final triggerHeight =
        renderObject.size.height / _edgeTriggerVisibleSlots * 2;
    final top = (renderObject.size.height - triggerHeight) / 2;
    final inVerticalBand = local.dy >= top && local.dy <= top + triggerHeight;
    final leftWidth = _edgeTriggerSide == -1
        ? _edgeTriggerOpenWidth
        : _edgeTriggerHitWidth;
    final rightWidth = _edgeTriggerSide == 1
        ? _edgeTriggerOpenWidth
        : _edgeTriggerHitWidth;
    final side = !inVerticalBand
        ? null
        : local.dx <= leftWidth
        ? -1
        : local.dx >= renderObject.size.width - rightWidth
        ? 1
        : null;
    _setEdgeTriggerSide(side);
  }

  void _setEdgeTriggerSide(int? side) {
    if (_edgeTriggerSide == side) return;
    if (_edgeTriggerSide != null) _stopEdgePaging();
    setState(() => _edgeTriggerSide = side);
  }

  void _stopEdgePaging() {
    _dragGeneration++;
    _edgePageTimer?.cancel();
    _edgePageTimer = null;
    _edgePageTarget = null;
    if (_pageController.hasClients) {
      _pageController.position.jumpTo(_pageController.position.pixels);
    }
  }

  void _scheduleEdgePageIfNeeded() {
    if (!_dayDragActive ||
        _edgeTriggerSide == null ||
        !_pageController.hasClients) {
      return;
    }
    final current = ref.read(selectedWeekProvider);
    final maxWeek = _maxDisplayWeek();
    final target = _edgeTriggerSide == -1 && current > 1
        ? current - 1
        : _edgeTriggerSide == 1 && current < maxWeek
        ? current + 1
        : null;
    if (target == null) {
      _stopEdgePaging();
      return;
    }
    if (target == _edgePageTarget) return;
    _edgePageTarget = target;
    _edgePageTimer?.cancel();
    final generation = _dragGeneration;
    const delay = Duration(milliseconds: 480);
    _edgePageTimer = Timer(delay, () async {
      if (!mounted ||
          !_dayDragActive ||
          generation != _dragGeneration ||
          _edgePageTarget != target) {
        return;
      }
      try {
        await _pageController.animateToPage(
          target - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      } catch (_) {
        return;
      }
      if (!mounted ||
          !_dayDragActive ||
          generation != _dragGeneration ||
          _edgePageTarget != target) {
        return;
      }
      ref.read(selectedWeekProvider.notifier).set(target);
      _edgePageTarget = null;
      _scheduleEdgePageIfNeeded();
    });
  }

  void _onDayDragEnd() {
    if (!_dayDragActive) return;
    _dayDragActive = false;
    _stopEdgePaging();
    setState(() => _edgeTriggerSide = null);
  }

  void _scheduleDayAction({
    required int week,
    required int weekday,
    required String label,
    required TimetableDayActionType type,
    required Map<int, Set<int>> affectedDaysByWeek,
    required Future<void> Function() execute,
  }) {
    _dayActionTimer?.cancel();
    _dayActionPulseController
      ..stop()
      ..reset()
      ..repeat(reverse: true);
    final action = _PendingDayAction(
      week: week,
      weekday: weekday,
      label: label,
      execute: execute,
      type: type,
      affectedDaysByWeek: affectedDaysByWeek,
    );
    setState(() => _pendingDayAction = action);
    _dayActionTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!identical(_pendingDayAction, action)) {
        timer.cancel();
        return;
      }
      if (action.remaining <= Duration.zero) {
        timer.cancel();
        _pendingDayAction = null;
        _dayActionPulseController
          ..stop()
          ..reset();
        if (mounted) setState(() {});
        unawaited(action.execute());
        return;
      }
      if (mounted) setState(() {});
    });
  }

  void _cancelDayAction(int weekday) {
    final action = _pendingDayAction;
    if (action == null ||
        !action.affectedDaysByWeek.values.any(
          (days) => days.contains(weekday),
        )) {
      return;
    }
    _dayActionTimer?.cancel();
    _dayActionTimer = null;
    _dayActionPulseController
      ..stop()
      ..reset();
    setState(() => _pendingDayAction = null);
  }

  TimetableDayActionIndicator? _dayActionIndicator(int week) {
    final action = _pendingDayAction;
    if (action == null) return null;
    final affectedWeekdays = action.affectedDaysByWeek[week];
    if (affectedWeekdays == null || affectedWeekdays.isEmpty) return null;
    final milliseconds = action.remaining.inMilliseconds.clamp(0, 3000);
    return TimetableDayActionIndicator(
      weekday: action.weekday,
      targetWeek: action.week,
      targetWeekday: action.weekday,
      label: action.label,
      seconds: ((milliseconds + 999) ~/ 1000).clamp(1, 3),
      type: action.type,
      affectedWeekdays: affectedWeekdays,
    );
  }

  Set<int> _adjustedWeekdays(List<Course> courses, int week) {
    final original = ref.read(scheduleProvider.notifier).originalCourses;
    if (original.isEmpty) return const {};
    final adjusted = <int>{};
    for (var weekday = 1; weekday <= 7; weekday++) {
      final current =
          courses
              .where(
                (course) => course.weekday == weekday && course.isInWeek(week),
              )
              .map(_dayCourseSignature)
              .toList()
            ..sort();
      final baseline =
          original
              .where(
                (course) => course.weekday == weekday && course.isInWeek(week),
              )
              .map(_dayCourseSignature)
              .toList()
            ..sort();
      if (current.length != baseline.length || !listEquals(current, baseline)) {
        adjusted.add(weekday);
      }
    }
    return adjusted;
  }

  String _dayCourseSignature(Course course) {
    final sessions = [...course.sessions]..sort();
    return [
      course.title,
      course.teacher,
      sessions.join(','),
      course.campus,
      course.place,
      course.colorIndex,
      course.courseId,
    ].join('\u001f');
  }

  Widget _buildEdgeTriggerOverlay(BuildContext context) {
    final color = context.theme.colors.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight / _edgeTriggerVisibleSlots * 2;
        final top = (constraints.maxHeight - height) / 2;
        final leftActive = _edgeTriggerSide == -1;
        final rightActive = _edgeTriggerSide == 1;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              left: 0,
              top: top,
              width: leftActive
                  ? _edgeTriggerOpenWidth
                  : _edgeTriggerClosedWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: leftActive ? 0.82 : 0.42),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              right: 0,
              top: top,
              width: rightActive
                  ? _edgeTriggerOpenWidth
                  : _edgeTriggerClosedWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: rightActive ? 0.82 : 0.42),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void refreshForResume() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleSchedule() async {
    final secondary = ref.read(secondaryScheduleProvider);
    if (!secondary.hasSchedule || _switchingSchedule || _dayDragActive) return;
    if (_pendingDayAction != null) _cancelDayAction(_pendingDayAction!.weekday);
    setState(() => _switchingSchedule = true);
    try {
      await _scheduleFlipController
          .animateTo(
            0.5,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInCubic,
          )
          .orCancel;
      if (!mounted) return;
      // Switch at the edge of the turn, retaining one PageView and controller.
      ref.read(secondaryScheduleProvider.notifier).toggle();
      final week = ref
          .read(selectedWeekProvider)
          .clamp(1, _maxDisplayWeek())
          .toInt();
      ref.read(selectedWeekProvider.notifier).set(week);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(week - 1);
        }
      });
      await _scheduleFlipController
          .animateTo(
            1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
    } on TickerCanceled {
      // The page may be closed during the animation.
    } finally {
      if (mounted) {
        _scheduleFlipController.reset();
        setState(() => _switchingSchedule = false);
      }
    }
  }

  Widget _buildScheduleTransition(Widget child) => AnimatedBuilder(
    animation: _scheduleFlipController,
    child: child,
    builder: (context, child) {
      final progress = _scheduleFlipController.value;
      final angle = progress <= 0.5
          ? -math.pi * progress
          : math.pi * (1 - progress);
      return IgnorePointer(
        ignoring: _switchingSchedule,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: child,
        ),
      );
    },
  );

  int _maxDisplayWeek([List<Course>? source]) {
    final secondary = ref.read(secondaryScheduleProvider);
    final courses =
        source ??
        (secondary.active
            ? secondary.courses
            : (ref.read(scheduleProvider).value ?? const []));
    int max = semesterCalendar.totalWeeks;
    for (final c in courses) {
      for (final w in c.weeks) {
        if (w > max) max = w;
      }
    }
    return max;
  }

  Future<void> _dismissCalendarUpdateNotice() async {
    semesterCalendar.setCalendarUpdateNotice(false);
    await ref
        .read(preferencesStorageProvider)
        .setSchoolCalendarUpdateNotice(false);
  }

  void _showNoticeIfNeeded() {
    if (!mounted) return;
    if (!semesterCalendar.calendarUpdateNotice) {
      unawaited(_hideNotice());
      return;
    }
    // TickerMode is disabled for pages that are not the active tab; showing
    // then would let the countdown expire while the user is elsewhere.
    if (!TickerMode.valuesOf(context).enabled) return;
    _noticeTimer?.cancel();
    _noticeProgressController.forward(from: 0);
    _noticeSlideController.forward(from: 0);
    if (!_noticeVisible) {
      setState(() => _noticeVisible = true);
    }
    _noticeTimer = Timer(_noticeDuration, () => unawaited(_hideNotice()));
  }

  Future<void> _hideNotice() async {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _noticeProgressController.stop();
    if (!_noticeVisible) return;
    await _noticeSlideController.reverse();
    if (mounted && _noticeVisible && _noticeSlideController.isDismissed) {
      setState(() => _noticeVisible = false);
    }
  }

  Future<void> _dismissNoticePermanently() async {
    await _hideNotice();
    await _dismissCalendarUpdateNotice();
  }

  Future<void> _onSync() async {
    if (_isSyncing) return;
    if (!mounted) return;
    setState(() => _isSyncing = true);

    try {
      final prefs = ref.read(preferencesStorageProvider);
      final sid = prefs.getStudentId();
      final pwd = await CredentialStorage.getSavedPassword();
      if (sid == null || pwd == null) {
        if (mounted) {
          showAppSnackBar(
            context,
            '请先在"我的"页面登录',
            severity: ToastSeverity.warning,
          );
        }
        return;
      }

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        if (mounted) {
          showAppSnackBar(
            context,
            '无网络连接，请检查网络后重试',
            severity: ToastSeverity.error,
          );
        }
        return;
      }

      // 先发起拉取，结果暂存在内存里；弹窗只决定是否把它应用到课表。
      final pending = ref.read(authProvider.notifier).login(sid, pwd);
      if (!mounted) {
        unawaited(
          pending.then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {},
          ),
        );
        return;
      }
      final cloudEnabled = prefs.getUseCloudTimetableAdjustments();
      final confirmed = await showAppConfirmDialog(
        context: context,
        title: '同步并重建课表？',
        message: cloudEnabled
            ? '拉取教务系统课表，并应用云端校历调整；当前手动调整会被覆盖。'
            : '拉取教务系统课表；当前手动调整会被覆盖。',
        confirmLabel: '同步并重建',
        cancelLabel: '取消',
      );
      if (!confirmed || !mounted) {
        // 取消：丢弃暂存的同步结果，不改动任何课表数据。
        unawaited(
          pending.then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              talker.warning('已取消，丢弃本次课表同步结果', error, stackTrace);
            },
          ),
        );
        return;
      }

      final result = await pending;
      if (result == null) {
        final authState = ref.read(authProvider);
        if (mounted) {
          showAppSnackBar(
            context,
            authState.errorMessage ?? '同步失败',
            severity: ToastSeverity.error,
          );
        }
        return;
      }

      final loginResult = result.$1;
      final examResult = result.$2;
      try {
        await ref
            .read(scheduleProvider.notifier)
            .updateFromLoginResult(
              courses: loginResult.courses,
              studentId: loginResult.studentId ?? sid,
              studentName: loginResult.studentName ?? '',
              collegeName: loginResult.collegeName ?? '',
              className: loginResult.className ?? '',
              majorName: loginResult.majorName ?? '',
            );
      } on WidgetSyncException catch (e) {
        if (mounted) {
          showAppSnackBar(
            context,
            '同步成功，但${describeError(e)}',
            severity: ToastSeverity.warning,
          );
        }
        return;
      }

      // 登录后 Control 门禁已打开，补一次校历刷新（未登录阶段被门禁跳过）。
      try {
        final calendarChanged = await ControlService.instance
            .refreshSchoolCalendarIfChanged(prefs)
            .timeout(const Duration(seconds: 3));
        if (calendarChanged && prefs.getUseCloudTimetableAdjustments()) {
          await ref.read(scheduleProvider.notifier).applyCloudAdjustments();
        }
      } catch (error, stackTrace) {
        talker.warning('同步后刷新校历失败', error, stackTrace);
      }
      if (examResult != null) {
        await ToolsDataManager.instance.setExams(examResult, prefs);
      }
      if (mounted) {
        showAppSnackBar(context, '同步成功', severity: ToastSeverity.success);
      }
      final hidden = ref.read(appSettingsProvider).hiddenServiceFeatures;
      bool visible(AppServiceFeature feature) => !hidden.contains(feature);
      unawaited(
        ToolsDataManager.instance.startBackgroundLoading(
          studentId: loginResult.studentId ?? sid,
          password: pwd,
          prefs: prefs,
          roomId: prefs.getSavedPowerRoomId(),
          displayName: loginResult.studentName ?? '',
          loadYktData: visible(AppServiceFeature.campusCard),
          loadPowerData: visible(AppServiceFeature.power),
          loadRepairData: visible(AppServiceFeature.repair),
          loadNetAuthData: visible(AppServiceFeature.network),
          loadJpData: visible(AppServiceFeature.teacherEvaluation),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Widget _buildEmptyView({bool secondary = false}) {
    final isLoggedIn = ref.watch(configProvider).studentId != null;
    final semesterNotStarted = !semesterCalendar.hasStarted;

    IconData icon;
    String title;
    String subtitle;
    if (secondary) {
      icon = FLucideIcons.calendarX;
      title = '备用课表暂无课程';
      subtitle = '可点击右上角切换回主课表';
    } else if (!isLoggedIn) {
      icon = FLucideIcons.calendarDays;
      title = '暂无课程';
      subtitle = '请在"我的"页面登录后同步课表';
    } else if (semesterNotStarted) {
      icon = FLucideIcons.hourglass;
      title = '未开学';
      subtitle = '教务系统可能还未发布本学期课表\n开学后下拉刷新同步';
    } else {
      icon = FLucideIcons.calendarX;
      title = '暂无课程';
      subtitle = '本学期暂无课程，可下拉刷新同步';
    }
    return Center(
      child: Padding(
        padding: AppLayout.pagePadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.theme.colors.mutedForeground),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: context.theme.typography.tileTitle.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: context.theme.typography.bodySmall.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final coursesAsync = ref.watch(scheduleProvider);
    final secondarySchedule = ref.watch(secondaryScheduleProvider);
    final settings = ref.watch(appSettingsProvider);
    // 渲染尺寸 = 参考设备设置值 × 当前设备比例（B1）。
    final gridSettings = settings.scaledForViewport(MediaQuery.sizeOf(context));
    final showNonCurrentWeekCourses = settings.showNonCurrentWeekCourses;
    final showWeekendColumns = ref.watch(showWeekendColumnsProvider);
    final courseBorderColor = context.theme.colors.foreground;
    final courseOpacity = settings.timetableCourseAlpha;
    final pageTextColor = settings.timetablePageTextFor(
      Theme.of(context).brightness,
    );
    final backgroundPath = settings.timetableBackgroundFor(
      Theme.of(context).brightness,
    );
    final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;

    return ListenableBuilder(
      listenable: semesterCalendar,
      builder: (context, _) => AppPage(
        root: true,
        transparentBackground: hasBackground,
        systemOverlayStyle: hasBackground
            ? context.theme.colors.systemOverlayStyle.copyWith(
                statusBarColor: const Color(0x00000000),
              )
            : null,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: (event) {
            _onDayDragUpdate(event.position);
          },
          onPointerUp: (_) => _onDayDragEnd(),
          onPointerCancel: (_) => _onDayDragEnd(),
          child: SafeArea(
            child: Column(
              children: [
                ClipRect(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      TimetableWeekHeader(
                        onJumpToCurrentWeek: jumpToCurrentWeek,
                        onToggleSchedule: _toggleSchedule,
                      ),
                      if (_noticeVisible)
                        Positioned.fill(
                          child: SlideTransition(
                            // 从左端滑入，收起时向左滑出，仍在原位置。
                            position:
                                Tween<Offset>(
                                  begin: const Offset(-1, 0),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: _noticeSlideController,
                                    curve: Curves.easeOutCubic,
                                    reverseCurve: Curves.easeInCubic,
                                  ),
                                ),
                            child: _CalendarUpdateNoticeToast(
                              progress: _noticeProgressController,
                              onDismiss: _dismissNoticePermanently,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      (secondarySchedule.active
                              ? AsyncValue.data(secondarySchedule.courses)
                              : coursesAsync)
                          .when(
                            data: (courses) {
                              final showingSecondary = secondarySchedule.active;
                              final displayedCourses = showingSecondary
                                  ? secondarySchedule.courses
                                  : courses;
                              if (displayedCourses.isEmpty) {
                                return _buildScheduleTransition(
                                  AppPageBody(
                                    maxWidth: AppLayout.contentMaxWidth,
                                    safeArea: false,
                                    onRefresh: _onSync,
                                    child: _buildEmptyView(
                                      secondary: showingSecondary,
                                    ),
                                  ),
                                );
                              }
                              final maxDisplayWeek = _maxDisplayWeek(
                                displayedCourses,
                              );
                              // 实验时段（带 T）无课时默认不显示。
                              final labSections = <int>{
                                for (final slot in kTimeSlots)
                                  if (slot.lab) slot.index,
                              };
                              final hideLab =
                                  labSections.isNotEmpty &&
                                  !displayedCourses.any(
                                    (c) => c.sessions.any(labSections.contains),
                                  );
                              final timetable = Stack(
                                fit: StackFit.expand,
                                children: [
                                  PageView.builder(
                                    key: _timetableViewportKey,
                                    controller: _pageController,
                                    physics: _pageRefreshActive
                                        ? const NeverScrollableScrollPhysics()
                                        : const _ResponsivePagePhysics(),
                                    itemCount: maxDisplayWeek,
                                    // Pre-build the neighbouring weeks while the current page is
                                    // idle so the left/right swipe only moves an already-built
                                    // grid instead of doing the (heavy) layout synchronously in
                                    // the middle of the gesture.
                                    allowImplicitScrolling: true,
                                    onPageChanged: (page) {
                                      ref
                                          .read(selectedWeekProvider.notifier)
                                          .set(page + 1);
                                    },
                                    itemBuilder: (context, index) {
                                      final week = index + 1;
                                      final pendingDayAction =
                                          _dayActionIndicator(week);
                                      return RepaintBoundary(
                                        child: AppRefreshIndicator(
                                          onRefresh: _onSync,
                                          // Includes dragging and cancelled
                                          // pulls, until fully retracted.
                                          onRefreshingChanged: (active) {
                                            if (!mounted ||
                                                _pageRefreshActive == active) {
                                              return;
                                            }
                                            setState(
                                              () => _pageRefreshActive = active,
                                            );
                                          },
                                          child: TimetableGrid(
                                            courses: displayedCourses,
                                            week: week,
                                            rotationTick: _conflictRotationTick,
                                            showNonCurrentWeekCourses:
                                                showNonCurrentWeekCourses,
                                            showWeekendColumns:
                                                showWeekendColumns,
                                            calendar: semesterCalendar,
                                            hiddenSlots: hideLab
                                                ? labSections
                                                : const {},
                                            countdownAnimation:
                                                _conflictCountdownController,
                                            dayActionAnimation:
                                                _dayActionPulseController,
                                            borderColor: courseBorderColor,
                                            courseBorderColor: settings
                                                .timetableCourseBorderColor,
                                            borderWidth: settings
                                                .timetableCourseBorderWidth,
                                            courseOpacity: courseOpacity,
                                            courseBorderOpacity: settings
                                                .timetableCourseBorderOpacity,
                                            courseTextSize: gridSettings
                                                .timetableCourseTextSize,
                                            timeTextSize: gridSettings
                                                .timetableTimeTextSize,
                                            dateTextSize: gridSettings
                                                .timetableDateTextSize,
                                            dayTextMarkerSize: gridSettings
                                                .timetableDayTextMarkerSize,
                                            gridOpacity:
                                                settings.timetableGridOpacity,
                                            gridLineColor:
                                                settings.timetableGridLineColor,
                                            gridLineWidth:
                                                settings.timetableGridLineWidth,
                                            showHeaderDivider: !hasBackground,
                                            showGridLines:
                                                settings.showTimetableGridLines,
                                            showTodayGridLines:
                                                settings.showTodayGridLines,
                                            todayLineColor: settings
                                                .timetableTodayLineColor,
                                            todayLineWidth: settings
                                                .timetableTodayLineWidth,
                                            todayLineOpacity: settings
                                                .timetableTodayLineOpacity,
                                            showTodayHorizontalGridLines: settings
                                                .showTodayHorizontalGridLines,
                                            sectionHeight:
                                                gridSettings
                                                    .timetableSectionHeightIsCustom
                                                ? gridSettings
                                                      .timetableSectionHeight
                                                : 0,
                                            visibleSlots:
                                                gridSettings
                                                    .timetableSectionHeightIsCustom
                                                ? 9
                                                : kAdaptiveSectionCount,
                                            timeColumnWidth: gridSettings
                                                .timetableTimeColumnWidth,
                                            dayHeaderHeight: gridSettings
                                                .timetableDayHeaderHeight,
                                            courseCornerRadius: settings
                                                .timetableCourseCornerRadius,
                                            courseInnerPadding: gridSettings
                                                .timetableCourseInnerPadding,
                                            courseOuterPadding: gridSettings
                                                .timetableCourseOuterPadding,
                                            courseTextTemplate: settings
                                                .timetableCourseTextTemplate,
                                            countdownBarLengthRatio: settings
                                                .timetableCountdownBarLengthRatio,
                                            countdownBarRounded: settings
                                                .timetableCountdownBarRounded,
                                            countdownBarThickness: settings
                                                .timetableCountdownBarThickness,
                                            countdownBarTopPadding: gridSettings
                                                .timetableCountdownBarTopPadding,
                                            countdownBarBottomPadding: gridSettings
                                                .timetableCountdownBarBottomPadding,
                                            showCurrentTimeLine:
                                                settings.showCurrentTimeLine,
                                            dashedBorderDensity: settings
                                                .timetableDashedBorderDensity,
                                            hideSectionTime: settings
                                                .timetableHideSectionTime,
                                            hideDateUnderDay: settings
                                                .timetableHideDateUnderDay,
                                            showDayColorMarkers: settings
                                                .timetableDayColorMarkers,
                                            showDayTextMarkers: settings
                                                .timetableDayTextMarkers,
                                            dayTextMarkerPosition: settings
                                                .timetableDayTextMarkerPosition,
                                            dayTextMarkerPadding: gridSettings
                                                .timetableDayTextMarkerPadding,
                                            textAlignCenterHorizontal: settings
                                                .timetableTextAlignCenterHorizontal,
                                            textAlignCenterVertical: settings
                                                .timetableTextAlignCenterVertical,
                                            borderType: settings
                                                .timetableBorderType
                                                .storageValue,
                                            pageTextColor: pageTextColor,
                                            pageTextOpacity: settings
                                                .timetablePageTextOpacity,
                                            courseTextOpacity: settings
                                                .timetableCourseTextOpacity,
                                            onCourseTap: showingSecondary
                                                ? null
                                                : (course, sourceIndex) {
                                                    final notifier = ref.read(
                                                      scheduleProvider.notifier,
                                                    );
                                                    final key = notifier
                                                        .keyForCourse(
                                                          course,
                                                          sourceIndex:
                                                              sourceIndex,
                                                        );
                                                    if (key == null) return;
                                                    _showCourseDetail(
                                                      context,
                                                      course,
                                                      key,
                                                      week,
                                                    );
                                                  },
                                            onEmptyTap: showingSecondary
                                                ? null
                                                : (weekday, session) =>
                                                      _onEmptySlotTap(
                                                        context,
                                                        weekday,
                                                        session,
                                                      ),
                                            onDayDoubleTap: showingSecondary
                                                ? null
                                                : (weekday) => _requestClearDay(
                                                    weekday,
                                                    week,
                                                  ),
                                            onDayTripleTap: showingSecondary
                                                ? null
                                                : (weekday) =>
                                                      _requestRestoreDay(
                                                        weekday,
                                                        week,
                                                      ),
                                            onDayDrop: showingSecondary
                                                ? null
                                                : (data, targetWeekday) =>
                                                      _requestMoveDay(
                                                        data,
                                                        targetWeekday,
                                                        week,
                                                      ),
                                            onDayDragUpdate: showingSecondary
                                                ? null
                                                : _onDayDragUpdate,
                                            onDayDragStart: showingSecondary
                                                ? null
                                                : _onDayDragStart,
                                            onDayDragEnd: showingSecondary
                                                ? null
                                                : _onDayDragEnd,
                                            pendingDayAction: showingSecondary
                                                ? null
                                                : pendingDayAction,
                                            onPendingDayActionCancel:
                                                _cancelDayAction,
                                            suppressDayDrop:
                                                showingSecondary ||
                                                _edgeTriggerSide != null,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (_dayDragActive)
                                    IgnorePointer(
                                      child: _buildEdgeTriggerOverlay(context),
                                    ),
                                ],
                              );
                              return _buildScheduleTransition(timetable);
                            },
                            loading: () => _buildTimetableSkeleton(),
                            error: (e, _) => AppPageBody(
                              maxWidth: AppLayout.contentMaxWidth,
                              safeArea: false,
                              onRefresh: _onSync,
                              child: Center(
                                child: AppStateView(
                                  icon: FLucideIcons.triangleAlert,
                                  title: '加载失败',
                                  description: describeError(e),
                                  destructive: true,
                                ),
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 课表首次加载的骨架：保留时间列与 5 列网格的形状，避免整屏 spinner。
  Widget _buildTimetableSkeleton() {
    final muted = context.theme.colors.muted;
    return AppPageBody(
      maxWidth: AppLayout.contentMaxWidth,
      safeArea: false,
      child: AppSkeleton(
        label: '正在加载课表',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 40),
                  for (var day = 0; day < 5; day++)
                    const Expanded(
                      child: Center(
                        child: AppSkeletonBox(width: 24, height: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (var slot = 0; slot < 6; slot++)
                            const AppSkeletonBox(width: 18, height: 10),
                        ],
                      ),
                    ),
                    for (var day = 0; day < 5; day++) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          children: [
                            for (var slot = 0; slot < 6; slot++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: (day + slot) % 3 == 0
                                      ? DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: muted,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.expand(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseDetail(
    BuildContext context,
    Course course,
    int key,
    int week,
  ) {
    unawaited(
      showAppSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: course.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          course.title,
                          style: context.theme.typography.pageTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _detailRow(FLucideIcons.userRound, '教师', course.teacher),
                  _detailRow(FLucideIcons.mapPin, '地点', course.place),
                  _detailRow(FLucideIcons.building2, '校区', course.campus),
                  _detailRow(
                    FLucideIcons.clock3,
                    '节次',
                    '第${course.startSession}-${course.endSession}节',
                  ),
                  _detailRow(
                    FLucideIcons.calendarRange,
                    '周次',
                    '${formatWeekRanges(course.weeks)}周',
                  ),
                  _detailRow(
                    FLucideIcons.tag,
                    '编号',
                    _courseIdForDisplay(course.courseId),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      if (course.courseId.isNotEmpty) ...[
                        Expanded(
                          child: FButton(
                            variant: FButtonVariant.destructive,
                            size: FButtonSizeVariant.md,
                            onPress: () {
                              Navigator.pop(ctx);
                              _confirmGlobalDelete(context, course);
                            },
                            child: const Text('全局删除'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      if (course.isInWeek(week))
                        Expanded(
                          child: FButton(
                            variant: FButtonVariant.destructive,
                            size: FButtonSizeVariant.md,
                            onPress: () {
                              Navigator.pop(ctx);
                              _confirmSingleDelete(context, key, week);
                            },
                            child: const Text('单次删除'),
                          ),
                        ),
                      if (course.isInWeek(week))
                        const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FButton(
                          size: FButtonSizeVariant.md,
                          onPress: () {
                            Navigator.pop(ctx);
                            _editCourse(context, course, key);
                          },
                          child: const Text('编辑课程'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.theme.colors.mutedForeground),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: context.theme.typography.bodySmall.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _courseIdForDisplay(String value) {
    if (value.length <= 16) return value;
    return '${value.substring(0, 16)}...';
  }

  void _confirmSingleDelete(BuildContext context, int key, int week) {
    unawaited(_deleteSingleCourseAfterConfirmation(context, key, week));
  }

  Future<void> _deleteSingleCourseAfterConfirmation(
    BuildContext context,
    int key,
    int week,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除这节课？',
      message: '仅删除第$week周的这次课程。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(scheduleProvider.notifier)
          .deleteCourseOccurrence(key, week);
    } on WidgetSyncException catch (e) {
      if (mounted) {
        showAppSnackBar(
          this.context,
          '课程已删除，但${describeError(e)}',
          severity: ToastSeverity.warning,
        );
      }
    }
  }

  void _confirmGlobalDelete(BuildContext context, Course course) {
    unawaited(_deleteGlobalCourseAfterConfirmation(context, course));
  }

  Future<void> _deleteGlobalCourseAfterConfirmation(
    BuildContext context,
    Course course,
  ) async {
    final courseId = course.courseId.trim();
    if (courseId.isEmpty) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除“${course.title}”？',
      message: '该课程的全部关联记录都会被删除。',
      confirmLabel: '全局删除',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(scheduleProvider.notifier)
          .deleteCoursesByCourseId(courseId);
    } on WidgetSyncException catch (e) {
      if (mounted) {
        showAppSnackBar(
          this.context,
          '课程已全局删除，但${describeError(e)}',
          severity: ToastSeverity.warning,
        );
      }
    }
  }

  String _weekdayLabel(int weekday) =>
      const ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'][weekday.clamp(1, 7)];

  void _requestClearDay(int weekday, int week) {
    final courses = ref.read(scheduleProvider).value ?? const <Course>[];
    final count = courses
        .where((course) => course.weekday == weekday && course.isInWeek(week))
        .length;
    if (count == 0) {
      if (mounted) {
        showAppSnackBar(context, '${_weekdayLabel(weekday)}当天没有课程');
      }
      return;
    }
    _scheduleDayAction(
      week: week,
      weekday: weekday,
      label: '清空',
      type: TimetableDayActionType.clear,
      affectedDaysByWeek: {
        week: {weekday},
      },
      execute: () => _clearDay(weekday, week),
    );
  }

  Future<void> _clearDay(int weekday, int week) async {
    try {
      await ref
          .read(scheduleProvider.notifier)
          .clearCourseDayOccurrence(weekday: weekday, week: week);
      if (mounted) {
        showAppSnackBar(context, '${_weekdayLabel(weekday)}已清空');
      }
    } on WidgetSyncException catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          '课程已清空，但${describeError(e)}',
          severity: ToastSeverity.warning,
        );
      }
    }
  }

  void _requestRestoreDay(int weekday, int week) {
    final courses = ref.read(scheduleProvider).value ?? const <Course>[];
    if (!_adjustedWeekdays(courses, week).contains(weekday)) return;
    _scheduleDayAction(
      week: week,
      weekday: weekday,
      label: '恢复',
      type: TimetableDayActionType.restore,
      affectedDaysByWeek: {
        week: {weekday},
      },
      execute: () => _restoreDay(weekday, week),
    );
  }

  Future<void> _restoreDay(int weekday, int week) async {
    try {
      final restored = await ref
          .read(scheduleProvider.notifier)
          .restoreCourseDayOccurrence(weekday: weekday, week: week);
      if (!mounted) return;
      showAppSnackBar(
        context,
        restored ? '${_weekdayLabel(weekday)}已恢复' : '暂无教务系统原始课表，请先同步课表',
        severity: restored ? ToastSeverity.success : ToastSeverity.warning,
      );
    } on WidgetSyncException catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          '恢复课表失败，但${describeError(e)}',
          severity: ToastSeverity.warning,
        );
      }
    }
  }

  void _requestMoveDay(
    TimetableDayDragData data,
    int targetWeekday,
    int targetWeek,
  ) {
    final affectedDaysByWeek = <int, Set<int>>{
      data.week: {data.weekday},
    };
    affectedDaysByWeek.update(
      targetWeek,
      (days) => {...days, targetWeekday},
      ifAbsent: () => {targetWeekday},
    );
    _scheduleDayAction(
      week: targetWeek,
      weekday: targetWeekday,
      label: '移动',
      type: TimetableDayActionType.move,
      affectedDaysByWeek: affectedDaysByWeek,
      execute: () => _moveDay(data, targetWeekday, targetWeek),
    );
  }

  Future<void> _moveDay(
    TimetableDayDragData data,
    int targetWeekday,
    int targetWeek,
  ) async {
    try {
      await ref
          .read(scheduleProvider.notifier)
          .moveCourseDayOccurrence(
            sourceWeekday: data.weekday,
            sourceWeek: data.week,
            targetWeekday: targetWeekday,
            targetWeek: targetWeek,
          );
      if (mounted) {
        showAppSnackBar(
          context,
          '${_weekdayLabel(targetWeekday)}已完成移动',
          severity: ToastSeverity.success,
        );
      }
    } on WidgetSyncException catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          '课程已移动，但${describeError(e)}',
          severity: ToastSeverity.warning,
        );
      }
    }
  }

  void _onEmptySlotTap(BuildContext context, int weekday, int session) {
    final courses = ref.read(scheduleProvider).value ?? [];
    final usedIndices = <int>{};
    for (final c in courses) {
      if (c.colorIndex >= 0 && c.colorIndex < Course.colors.length) {
        usedIndices.add(c.colorIndex);
      }
    }
    int nextIndex = 0;
    while (nextIndex < Course.colors.length &&
        usedIndices.contains(nextIndex)) {
      nextIndex++;
    }
    final defaultColorIndex = nextIndex % Course.colors.length;
    final defaultColor = Course.colors[defaultColorIndex];

    Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.addCourse,
        builder: (_) => CourseFormPage(
          weekday: weekday,
          session: session,
          defaultColor: defaultColor,
          defaultColorIndex: defaultColorIndex,
          onSave: (course) async {
            try {
              await ref.read(scheduleProvider.notifier).addCourse(course);
            } on WidgetSyncException catch (e) {
              if (!mounted) return;
              showAppSnackBar(
                this.context,
                '课程已保存，但${describeError(e)}',
                severity: ToastSeverity.warning,
              );
            }
          },
        ),
      ),
    );
  }

  void _editCourse(BuildContext context, Course course, int key) {
    Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.editCourse,
        builder: (_) => CourseFormPage(
          weekday: course.weekday,
          session: course.startSession,
          existingCourse: course,
          onSave: (updated) async {
            try {
              await ref
                  .read(scheduleProvider.notifier)
                  .updateCourse(key, updated);
              if (updated.courseId.isNotEmpty) {
                await ref
                    .read(scheduleProvider.notifier)
                    .syncCourseFields(
                      updated.courseId,
                      excludeKey: key,
                      title: updated.title,
                      teacher: updated.teacher,
                    );
              }
            } on WidgetSyncException catch (e) {
              if (!mounted) return;
              showAppSnackBar(
                this.context,
                '课程已保存，但${describeError(e)}',
                severity: ToastSeverity.warning,
              );
            }
          },
        ),
      ),
    );
  }
}

/// 「云端课程有所调整」黄色警告条：覆盖日期/周数栏，底部带倒计时进度条。
class _CalendarUpdateNoticeToast extends StatelessWidget {
  final Animation<double> progress;
  final VoidCallback onDismiss;

  const _CalendarUpdateNoticeToast({
    required this.progress,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors.semantic;
    return ColoredBox(
      color: colors.warningContainer,
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final gutter = AppLayout.pageGutter(context);
              final width = (constraints.maxWidth - gutter * 2)
                  .clamp(0.0, AppLayout.contentMaxWidth)
                  .toDouble();
              return Center(
                child: SizedBox(
                  width: width,
                  child: Row(
                    children: [
                      Icon(
                        FLucideIcons.triangleAlert,
                        size: 18,
                        color: colors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '云端课程有所调整，建议重建课表',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.theme.typography.bodySmall.copyWith(
                            color: colors.onWarningContainer,
                          ),
                        ),
                      ),
                      AppIconButton(
                        icon: FLucideIcons.x,
                        onPress: onDismiss,
                        tooltip: '关闭提醒',
                        iconColor: colors.onWarningContainer,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 3,
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (1 - progress.value).clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: ColoredBox(color: colors.warning),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsivePagePhysics extends PageScrollPhysics {
  const _ResponsivePagePhysics({super.parent});

  @override
  _ResponsivePagePhysics applyTo(ScrollPhysics? ancestor) {
    return _ResponsivePagePhysics(parent: buildParent(ancestor));
  }

  @override
  // Keep a small threshold so a light finger movement starts paging
  // immediately, while still filtering accidental taps.
  double get dragStartDistanceMotionThreshold => 8.0;
}
