import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../models/course.dart';
import '../../models/school_calendar.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/credential_storage.dart';
import '../../services/tools_data_manager.dart';
import 'timetable_providers.dart';
import '../../services/widget_service.dart';
import '../../utils/course_text_parser.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/week_header.dart';
import '../../ui/app_components.dart';
import 'course_form_page.dart';
import 'timetable_grid.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  static final globalKey = GlobalKey<TimetablePageState>();

  @override
  ConsumerState<TimetablePage> createState() => TimetablePageState();
}

class TimetablePageState extends ConsumerState<TimetablePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final PageController _pageController;
  late final AnimationController _conflictCountdownController;
  bool _isSyncing = false;
  int _conflictRotationTick = 0;
  double _lastConflictCountdownValue = 0;

  @override
  void initState() {
    super.initState();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (initialWeek > 0) {
        ref.read(selectedWeekProvider.notifier).set(initialWeek);
      }
    });
  }

  @override
  void dispose() {
    _conflictCountdownController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void jumpToCurrentWeek() {
    final maxWeek = _maxDisplayWeek();
    final week = semesterCalendar.weekOf(DateTime.now()).clamp(1, maxWeek);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(week - 1);
    }
    ref.read(selectedWeekProvider.notifier).set(week);
  }

  void refreshForResume() {
    if (mounted) {
      setState(() {});
    }
  }

  int _maxDisplayWeek([List<Course>? source]) {
    final courses = source ?? (ref.read(scheduleProvider).value ?? const []);
    int max = semesterCalendar.totalWeeks;
    for (final c in courses) {
      for (final w in c.weeks) {
        if (w > max) max = w;
      }
    }
    return max;
  }

  Future<void> _onSync() async {
    if (_isSyncing) return;
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

      final result = await ref.read(authProvider.notifier).login(sid, pwd);
      if (result != null) {
        final (loginResult, examResult) = result;
        try {
          await ref
              .read(scheduleProvider.notifier)
              .updateFromLoginResult(
                courses: loginResult.courses,
                studentId: loginResult.studentId ?? sid,
                studentName: loginResult.studentName ?? '',
              );
        } on WidgetSyncException catch (e) {
          if (mounted) {
            showAppSnackBar(
              context,
              '同步成功，但$e',
              severity: ToastSeverity.warning,
            );
          }
          return;
        }
        await ToolsDataManager.instance.setExams(
          examResult,
          ref.read(preferencesStorageProvider),
        );
        if (mounted) {
          showAppSnackBar(context, '同步成功', severity: ToastSeverity.success);
        }
      } else {
        final authState = ref.read(authProvider);
        if (mounted) {
          showAppSnackBar(
            context,
            authState.errorMessage ?? '同步失败',
            severity: ToastSeverity.error,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Widget _buildEmptyView() {
    final isLoggedIn = ref.watch(configProvider).studentId != null;
    final semesterNotStarted = !semesterCalendar.hasStarted;

    IconData icon;
    String title;
    String subtitle;
    if (!isLoggedIn) {
      icon = FLucideIcons.calendarDays;
      title = '暂无课程';
      subtitle = '请在"我的"页面登录后同步课表';
    } else if (semesterNotStarted) {
      icon = FLucideIcons.hourglass;
      title = '未开学';
      subtitle = '教务系统可能还未发布本学期课表\n开学后下拉刷新或点击右上角重新同步';
    } else {
      icon = FLucideIcons.calendarX;
      title = '暂无课程';
      subtitle = '本学期暂无课程，可点击右上角重新同步';
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
    final settings = ref.watch(appSettingsProvider);
    final showNonCurrentWeekCourses = ref.watch(
      showNonCurrentWeekCoursesProvider,
    );
    final showWeekendColumns = ref.watch(showWeekendColumnsProvider);
    final isDark = context.theme.colors.brightness == Brightness.dark;
    final courseBorderColor = context.theme.colors.foreground;
    final courseOpacity = isDark ? 0.95 : 0.85;
    final courseBorderOpacity = isDark ? 1.0 : 0.85;

    return AppPage(
      root: true,
      child: SafeArea(
        child: Column(
          children: [
            Consumer(
              builder: (context, ref, child) => WeekHeader(
                calendar: semesterCalendar,
                selectedWeek: ref.watch(selectedWeekProvider),
                onSync: _isSyncing ? null : _onSync,
              ),
            ),
            Expanded(
              child: coursesAsync.when(
                data: (courses) {
                  if (courses.isEmpty) {
                    return _buildEmptyView();
                  }
                  final maxDisplayWeek = _maxDisplayWeek(courses);
                  final hide56 = !courses.any(
                    (c) => c.sessions.contains(5) || c.sessions.contains(6),
                  );
                  return PageView.builder(
                    controller: _pageController,
                    physics: const _LessSensitivePagePhysics(),
                    itemCount: maxDisplayWeek,
                    // Pre-build the neighbouring weeks while the current page is
                    // idle so the left/right swipe only moves an already-built
                    // grid instead of doing the (heavy) layout synchronously in
                    // the middle of the gesture.
                    allowImplicitScrolling: true,
                    onPageChanged: (page) {
                      ref.read(selectedWeekProvider.notifier).set(page + 1);
                    },
                    itemBuilder: (context, index) {
                      final week = index + 1;
                      return RepaintBoundary(
                        child: TimetableGrid(
                          courses: courses,
                          week: week,
                          rotationTick: _conflictRotationTick,
                          showNonCurrentWeekCourses: showNonCurrentWeekCourses,
                          showWeekendColumns: showWeekendColumns,
                          calendar: semesterCalendar,
                          hiddenSlots: hide56 ? const {5, 6} : const {},
                          countdownAnimation: _conflictCountdownController,
                          borderColor: courseBorderColor,
                          borderWidth: 0.5,
                          courseOpacity: courseOpacity,
                          courseBorderOpacity: courseBorderOpacity,
                          backgroundImagePath: settings.timetableBackgroundPath,
                          backgroundOpacity:
                              settings.timetableBackgroundOpacity,
                          showGridLines: settings.showTimetableGridLines,
                          onCourseTap: (course, idx) {
                            final key = ref
                                .read(scheduleProvider.notifier)
                                .keyAt(idx);
                            _showCourseDetail(context, course, key);
                          },
                          onEmptyTap: (weekday, session) =>
                              _onEmptySlotTap(context, weekday, session),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: FCircularProgress()),
                error: (e, _) => Center(
                  child: AppStateView(
                    icon: FLucideIcons.triangleAlert,
                    title: '加载失败',
                    description: '$e',
                    destructive: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCourseDetail(BuildContext context, Course course, int key) {
    unawaited(
      showAppSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                  _detailRow(FLucideIcons.tag, '编号', course.courseId),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FButton(
                        variant: FButtonVariant.destructive,
                        size: FButtonSizeVariant.md,
                        mainAxisSize: MainAxisSize.min,
                        onPress: () {
                          Navigator.pop(ctx);
                          _confirmDelete(context, key);
                        },
                        child: const Text('删除'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FButton(
                        size: FButtonSizeVariant.md,
                        mainAxisSize: MainAxisSize.min,
                        onPress: () {
                          Navigator.pop(ctx);
                          _editCourse(context, course, key);
                        },
                        child: const Text('编辑'),
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

  void _confirmDelete(BuildContext context, int key) {
    unawaited(_deleteCourseAfterConfirmation(context, key));
  }

  Future<void> _deleteCourseAfterConfirmation(
    BuildContext context,
    int key,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除课程',
      message: '确定要删除这门课程吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(scheduleProvider.notifier).deleteCourse(key);
    } on WidgetSyncException catch (e) {
      if (mounted) {
        showAppSnackBar(
          this.context,
          '课程已删除，但$e',
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
    final defaultColor = Course.colors[nextIndex % Course.colors.length];

    Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.addCourse,
        builder: (_) => CourseFormPage(
          weekday: weekday,
          session: session,
          defaultColor: defaultColor,
          onSave: (course) async {
            try {
              await ref.read(scheduleProvider.notifier).addCourse(course);
            } on WidgetSyncException catch (e) {
              if (!mounted) return;
              showAppSnackBar(
                this.context,
                '课程已保存，但$e',
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
                '课程已保存，但$e',
                severity: ToastSeverity.warning,
              );
            }
          },
          onDelete: () async {
            try {
              await ref.read(scheduleProvider.notifier).deleteCourse(key);
            } on WidgetSyncException catch (e) {
              if (!mounted) return;
              showAppSnackBar(
                this.context,
                '课程已删除，但$e',
                severity: ToastSeverity.warning,
              );
            }
          },
        ),
      ),
    );
  }
}

class _LessSensitivePagePhysics extends PageScrollPhysics {
  const _LessSensitivePagePhysics({super.parent});

  @override
  _LessSensitivePagePhysics applyTo(ScrollPhysics? ancestor) {
    return _LessSensitivePagePhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 24.0;
}
