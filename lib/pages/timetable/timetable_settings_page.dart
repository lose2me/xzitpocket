import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/app_settings.dart';
import '../../models/course.dart';
import '../../models/school_calendar.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/native_automation_service.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';
import '../profile/profile_components.dart';
import 'timetable_providers.dart';

int _tenthsDivisions(double min, double max) => ((max - min) * 10).round();

double _backgroundAspectRatio(
  Size size, {
  required bool fullscreen,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final width = size.width.clamp(1.0, double.infinity).toDouble();
  if (fullscreen) {
    final height = size.height.clamp(1.0, double.infinity).toDouble();
    return width / height;
  }

  // The non-fullscreen image sits behind the timetable grid only. Keep the
  // crop frame aligned with the space left after the week header and nav bar.
  final contentHeight = (size.height - padding.vertical - 64 - 80)
      .clamp(1.0, double.infinity)
      .toDouble();
  return width / contentHeight;
}

class TimetableSettingsPage extends ConsumerStatefulWidget {
  const TimetableSettingsPage({super.key});

  @override
  ConsumerState<TimetableSettingsPage> createState() =>
      _TimetableSettingsPageState();
}

class _TimetableSettingsPageState extends ConsumerState<TimetableSettingsPage>
    with WidgetsBindingObserver {
  final _imagePicker = ImagePicker();
  bool _adjustmentDetailsExpanded = false;
  bool _cloudRulesExpanded = false;
  bool _automationPermissionFlowActive = false;
  final _promptedAutomationPermissions = <String>{};

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _automationPermissionFlowActive) {
      unawaited(_continueAutomationPermissionFlow());
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final showNonCurrentWeekCourses = ref.watch(
      showNonCurrentWeekCoursesProvider,
    );
    final showWeekendColumns = ref.watch(showWeekendColumnsProvider);
    final coursesAsync = ref.watch(scheduleProvider);
    final hasOriginalBaseline = ref
        .read(scheduleProvider.notifier)
        .originalCourses
        .isNotEmpty;
    final adjustments = _buildAdjustmentRules(coursesAsync.value);
    final hasLocalRules = hasOriginalBaseline && adjustments.isNotEmpty;
    final hasCloudRules = _cloudAdjustments.isNotEmpty;

    return AppPage(
      title: '课表设置',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          const ProfileSectionLabel(title: '课程规则'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsExpandableTile(
                icon: FLucideIcons.history,
                title: '本地课程规则',
                value: !hasOriginalBaseline
                    ? '暂无基线'
                    : adjustments.isEmpty
                    ? '无变动'
                    : '${adjustments.length} 条规则',
                expanded: hasLocalRules && _adjustmentDetailsExpanded,
                expandable: hasLocalRules,
                onTap: () => setState(
                  () =>
                      _adjustmentDetailsExpanded = !_adjustmentDetailsExpanded,
                ),
                child: _buildAdjustmentDetails(
                  adjustments,
                  hasOriginalBaseline: hasOriginalBaseline,
                ),
              ),
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.cloud,
                title: '启用云端课程规则',
                value: settings.useCloudTimetableAdjustments,
                onChange: _setCloudAdjustmentsEnabled,
              ),
              ProfileSettingsExpandableTile(
                icon: FLucideIcons.cloud,
                title: '云端课程规则',
                value: '${_cloudAdjustments.length} 条规则',
                expanded: hasCloudRules && _cloudRulesExpanded,
                expandable: hasCloudRules,
                onTap: () =>
                    setState(() => _cloudRulesExpanded = !_cloudRulesExpanded),
                child: _buildCloudRuleDetails(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '显示'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.eye,
                title: '显示非本周课程',
                value: showNonCurrentWeekCourses,
                onChange: (value) => ref
                    .read(showNonCurrentWeekCoursesProvider.notifier)
                    .set(value),
              ),
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.calendarDays,
                title: '显示周末列',
                value: showWeekendColumns,
                onChange: (value) =>
                    ref.read(showWeekendColumnsProvider.notifier).set(value),
              ),
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.grid2x2,
                title: '显示网格辅助线',
                value: settings.showTimetableGridLines,
                onChange: (value) => ref
                    .read(appSettingsProvider.notifier)
                    .setShowTimetableGridLines(value),
              ),
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.calendarCheck,
                title: '显示当天边界线',
                value: settings.showTodayGridLines,
                onChange: (value) => ref
                    .read(appSettingsProvider.notifier)
                    .setShowTodayGridLines(value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '透明度'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.layers,
                title: '课表组件透明度',
                value:
                    '${((1 - settings.timetableComponentOpacity) * 100).round()}%',
                onTap: () => _openOpacitySheet(
                  title: '课表组件透明度',
                  currentValue: 1 - settings.timetableComponentOpacity,
                  onSave: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .setTimetableComponentOpacity(1 - value),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.grid2x2,
                title: '课表组件边框透明度',
                value:
                    '${((1 - settings.timetableCourseBorderOpacity) * 100).round()}%',
                onTap: () => _openOpacitySheet(
                  title: '课表组件边框透明度',
                  currentValue: 1 - settings.timetableCourseBorderOpacity,
                  onSave: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .setTimetableCourseBorderOpacity(1 - value),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.image,
                title: '背景图透明度',
                value:
                    '${((1 - settings.timetableBackgroundOpacity) * 100).round()}%',
                onTap: () => _openOpacitySheet(
                  title: '背景图透明度',
                  currentValue: 1 - settings.timetableBackgroundOpacity,
                  onSave: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .setTimetableBackgroundOpacity(1 - value),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.grid2x2,
                title: '网格透明度',
                value:
                    '${((1 - settings.timetableGridOpacity) * 100).round()}%',
                onTap: () => _openOpacitySheet(
                  title: '网格透明度',
                  currentValue: 1 - settings.timetableGridOpacity,
                  onSave: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .setTimetableGridOpacity(1 - value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '文字与边框'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.fileText,
                title: '课表组件文字大小',
                value:
                    '${settings.timetableCourseTextSize.toStringAsFixed(1)} px',
                onTap: () => _openNumberSheet(
                  title: '课表组件文字大小',
                  currentValue: settings.timetableCourseTextSize,
                  min: 8,
                  max: 18,
                  divisions: _tenthsDivisions(8, 18),
                  suffix: ' px',
                  onSave: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .setTimetableCourseTextSize(value),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.clock3,
                title: '左侧时间列文字大小',
                value:
                    '${settings.timetableTimeTextSize.toStringAsFixed(1)} px',
                onTap: () => _openNumberSheet(
                  title: '左侧时间列文字大小',
                  currentValue: settings.timetableTimeTextSize,
                  min: 8,
                  max: 18,
                  divisions: _tenthsDivisions(8, 18),
                  suffix: ' px',
                  onSave: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .setTimetableTimeTextSize(value),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.calendarDays,
                title: '上方日期列文字大小',
                value:
                    '${settings.timetableDateTextSize.toStringAsFixed(1)} px',
                onTap: () => _openNumberSheet(
                  title: '上方日期列文字大小',
                  currentValue: settings.timetableDateTextSize,
                  min: 8,
                  max: 18,
                  divisions: _tenthsDivisions(8, 18),
                  suffix: ' px',
                  onSave: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .setTimetableDateTextSize(value),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.grid2x2,
                title: '课表组件边框粗细',
                value:
                    '${settings.timetableCourseBorderWidth.toStringAsFixed(1)} px',
                onTap: () => _openNumberSheet(
                  title: '课表组件边框粗细',
                  currentValue: settings.timetableCourseBorderWidth,
                  min: 0,
                  max: 3,
                  divisions: _tenthsDivisions(0, 3),
                  suffix: ' px',
                  onSave: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .setTimetableCourseBorderWidth(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '背景图'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.image,
                title: '课表背景图',
                value: settings.timetableBackgroundPath == null ? '未设置' : '已设置',
                onTap: _pickBackground,
              ),
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.maximize,
                title: '背景覆盖全屏',
                value: settings.timetableBackgroundFullscreen,
                onChange: (value) => ref
                    .read(appSettingsProvider.notifier)
                    .setTimetableBackgroundFullscreen(value),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.trash2,
                title: '清除背景图',
                onTap: settings.timetableBackgroundPath == null
                    ? null
                    : _clearBackground,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '课堂勿扰'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.bellOff,
                title: '课堂勿扰',
                value: _automationLabel(settings.classAutomationMode),
                onTap: () => _openAutomationSheet(settings.classAutomationMode),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: _resetAppearance,
              prefix: const Icon(FLucideIcons.refreshCw),
              child: const Text('重置个性化设置'),
            ),
          ),
        ],
      ),
    );
  }

  List<_TimetableAdjustment> _buildAdjustmentRules(List<Course>? courses) {
    final current = courses ?? const <Course>[];
    final original = ref.read(scheduleProvider.notifier).originalCourses;
    if (original.isEmpty && current.isEmpty) return const [];

    final maxWeek = <int>[
      semesterCalendar.totalWeeks,
      ...current.expand((course) => course.weeks),
      ...original.expand((course) => course.weeks),
    ].fold<int>(1, (maximum, value) => value > maximum ? value : maximum);
    final snapshots = <String, _TimetableDaySnapshot>{};
    for (var week = 1; week <= maxWeek; week++) {
      final dates = semesterCalendar.weekDates(week);
      for (var weekday = 1; weekday <= 7; weekday++) {
        final originalCourses = _coursesForDay(original, weekday, week);
        final currentCourses = _coursesForDay(current, weekday, week);
        final date = dates[weekday - 1];
        snapshots[_dateKey(date)] = _TimetableDaySnapshot(
          date: date,
          originalCourses: originalCourses,
          currentCourses: currentCourses,
        );
      }
    }

    final rules = <_TimetableAdjustment>[];
    final movedSources = <String>{};
    for (final target in snapshots.values) {
      final currentSignature = _courseSignatures(target.currentCourses)
          .join('\u001e');
      if (currentSignature.isEmpty ||
          currentSignature ==
              _courseSignatures(target.originalCourses).join('\u001e')) {
        continue;
      }
      final candidates = snapshots.values.where((source) {
        if (source.date == target.date ||
            source.originalCourses.isEmpty ||
            source.currentCourses.isNotEmpty) {
          return false;
        }
        return _courseSignatures(source.originalCourses).join('\u001e') ==
            currentSignature;
      }).toList();
      if (candidates.length == 1) {
        final source = candidates.single;
        rules.add(
          _TimetableAdjustment(
            sourceDate: source.date,
            operation: '移动',
            targetDate: target.date,
          ),
        );
        movedSources.add(_dateKey(source.date));
      }
    }

    for (final day in snapshots.values) {
      if (day.originalCourses.isEmpty ||
          day.currentCourses.isNotEmpty ||
          movedSources.contains(_dateKey(day.date))) {
        continue;
      }
      rules.add(_TimetableAdjustment(sourceDate: day.date, operation: '清空'));
    }
    rules.sort((left, right) => left.sourceDate.compareTo(right.sourceDate));
    return rules;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  DateTime? _parseDateKey(String value) {
    if (!RegExp(r'^\d{8}$').hasMatch(value)) return null;
    final date = DateTime(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(4, 6)),
      int.parse(value.substring(6, 8)),
    );
    if (_dateKey(date) != value) return null;
    return date;
  }

  List<SchoolDay> get _cloudAdjustments => semesterCalendar.days
      .where((day) => day.adjustment != null && day.adjustment!.isNotEmpty)
      .toList();

  Future<void> _setCloudAdjustmentsEnabled(bool enabled) async {
    await ref
        .read(appSettingsProvider.notifier)
        .setUseCloudTimetableAdjustments(enabled);
    if (enabled && mounted) {
      await ref.read(scheduleProvider.notifier).applyCloudAdjustments();
    }
  }

  Widget _buildCloudRuleDetails() {
    if (_cloudAdjustments.isEmpty) return const SizedBox.shrink();
    final rows = <_TimetableAdjustment>[];
    for (final day in _cloudAdjustments) {
      final value = day.adjustment!;
      if (value == '/') {
        rows.add(_TimetableAdjustment(sourceDate: day.date, operation: '清空'));
        continue;
      }
      final source = _parseDateKey(value);
      if (source != null) {
        rows.add(
          _TimetableAdjustment(
            sourceDate: source,
            operation: '移动',
            targetDate: day.date,
          ),
        );
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    rows.sort((left, right) => left.sourceDate.compareTo(right.sourceDate));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0)
            Divider(height: AppSpacing.lg, color: context.theme.colors.border),
          _buildAdjustmentRow(rows[index]),
        ],
      ],
    );
  }

  List<Course> _coursesForDay(List<Course> courses, int weekday, int week) =>
      [
        for (final course in courses)
          if (course.weekday == weekday && course.weeks.contains(week)) course,
      ]..sort((left, right) {
        final session = left.startSession.compareTo(right.startSession);
        if (session != 0) return session;
        return left.title.compareTo(right.title);
      });

  List<String> _courseSignatures(List<Course> courses) => [
    for (final course in courses)
      [
        course.title,
        course.teacher,
        ([...course.sessions]..sort()).join(','),
        course.campus,
        course.place,
        course.colorIndex,
        course.courseId,
      ].join('\u001f'),
  ]..sort();

  Widget _buildAdjustmentDetails(
    List<_TimetableAdjustment> adjustments, {
    required bool hasOriginalBaseline,
  }) {
    if (!hasOriginalBaseline || adjustments.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < adjustments.length; index++) ...[
          if (index > 0)
            Divider(height: AppSpacing.lg, color: context.theme.colors.border),
          _buildAdjustmentRow(adjustments[index]),
        ],
      ],
    );
  }

  Widget _buildAdjustmentRow(_TimetableAdjustment adjustment) {
    return Row(
      children: [
        Expanded(child: _dateOperationLabel(adjustment.sourceDate)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: _operationLabel(adjustment.operation),
        ),
        Expanded(
          child: adjustment.targetDate == null
              ? const SizedBox()
              : Align(
                  alignment: Alignment.centerRight,
                  child: _dateOperationLabel(adjustment.targetDate!),
                ),
        ),
      ],
    );
  }

  Widget _operationLabel(String operation) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        operation,
        style: context.theme.typography.caption.copyWith(
          color: operation == '清空'
              ? context.theme.colors.destructive
              : context.theme.colors.primary,
        ),
      ),
    ],
  );

  Widget _dateOperationLabel(DateTime date, [String? subtitle]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _visualDateLabel(date),
        style: context.theme.typography.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      if (subtitle != null)
        Text(
          subtitle,
          style: context.theme.typography.caption.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
    ],
  );

  String _visualDateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _automationLabel(ClassAutomationMode mode) => switch (mode) {
    ClassAutomationMode.off => '关闭',
    ClassAutomationMode.dnd => '上课时开启',
    ClassAutomationMode.dndKeep => '下课不恢复',
  };

  Future<void> _openAutomationSheet(ClassAutomationMode currentMode) async {
    final selected = await showAppSheet<ClassAutomationMode>(
      context: context,
      builder: (context) => AppOptionSheet<ClassAutomationMode>(
        title: '课堂勿扰',
        value: currentMode,
        options: [
          const AppOption(
            value: ClassAutomationMode.off,
            title: '关闭',
            subtitle: '不自动调节手机模式',
            icon: FLucideIcons.bellOff,
          ),
          const AppOption(
            value: ClassAutomationMode.dnd,
            title: '上课开启，下课恢复',
            subtitle: '上课静音，下课后自动恢复',
            icon: FLucideIcons.bellRing,
          ),
          const AppOption(
            value: ClassAutomationMode.dndKeep,
            title: '上课开启，下课不恢复',
            subtitle: '上课静音，下课后保持勿扰',
            icon: FLucideIcons.vibrateOff,
          ),
        ],
      ),
    );
    if (selected == null) return;
    if (selected != currentMode) {
      await ref
          .read(appSettingsProvider.notifier)
          .setClassAutomationMode(selected);
    }
    if (!mounted || selected == ClassAutomationMode.off) return;
    final status = await NativeAutomationService.getPermissionStatus();
    if (!mounted || status.isFullyGranted) return;
    _automationPermissionFlowActive = true;
    _promptedAutomationPermissions.clear();
    final missing = [
      if (!status.hasDndPermission) '勿扰',
      if (!status.hasExactAlarmPermission) '精确闹钟',
    ];
    showAppSnackBar(
      context,
      '需要开启${missing.join('和')}权限',
      severity: ToastSeverity.warning,
    );
    await _continueAutomationPermissionFlow(status);
  }

  Future<void> _continueAutomationPermissionFlow([
    AutomationPermissionStatus? knownStatus,
  ]) async {
    if (!mounted || !_automationPermissionFlowActive) return;
    final status =
        knownStatus ?? await NativeAutomationService.getPermissionStatus();
    if (!mounted) return;
    if (status.isFullyGranted) {
      _automationPermissionFlowActive = false;
      _promptedAutomationPermissions.clear();
      return;
    }

    String? nextPermission;
    if (!status.hasDndPermission) {
      if (!_promptedAutomationPermissions.contains('dnd')) {
        nextPermission = 'dnd';
      }
    } else if (!status.hasExactAlarmPermission &&
        !_promptedAutomationPermissions.contains('exactAlarm')) {
      nextPermission = 'exactAlarm';
    }
    if (nextPermission == null) {
      _automationPermissionFlowActive = false;
      return;
    }

    _promptedAutomationPermissions.add(nextPermission);
    try {
      if (nextPermission == 'dnd') {
        await NativeAutomationService.openDndSettings();
      } else {
        await NativeAutomationService.openExactAlarmSettings();
      }
    } catch (error, stackTrace) {
      talker.warning('打开课堂勿扰权限设置失败', error, stackTrace);
      _automationPermissionFlowActive = false;
      if (mounted) {
        showAppSnackBar(
          context,
          '无法打开权限设置，请到系统设置中手动开启',
          severity: ToastSeverity.warning,
        );
      }
    }
  }

  Future<void> _openOpacitySheet({
    required String title,
    required double currentValue,
    required Future<void> Function(double value) onSave,
  }) async {
    var value = currentValue;
    final selected = await showAppSheet<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.theme.typography.pageTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${(value * 100).round()}%',
                textAlign: TextAlign.center,
                style: context.theme.typography.bodySmall.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: Slider(
                  value: value,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  activeColor: context.theme.colors.primary,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FButton(
                onPress: () => Navigator.pop(context, value),
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != currentValue) await onSave(selected);
  }

  Future<void> _openNumberSheet({
    required String title,
    required double currentValue,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required Future<void> Function(double value) onSave,
  }) async {
    var value = currentValue;
    final selected = await showAppSheet<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.theme.typography.pageTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${value.toStringAsFixed(1)}$suffix',
                textAlign: TextAlign.center,
                style: context.theme.typography.bodySmall.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  activeColor: context.theme.colors.primary,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FButton(
                onPress: () => Navigator.pop(context, value),
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != currentValue) await onSave(selected);
  }

  Future<void> _pickBackground() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null || !mounted) return;
    try {
      final screenSize = MediaQuery.sizeOf(context);
      final settings = ref.read(appSettingsProvider);
      final aspectRatio = _backgroundAspectRatio(
        screenSize,
        fullscreen: settings.timetableBackgroundFullscreen,
        padding: MediaQuery.paddingOf(context),
      );
      final decoded = img.decodeImage(await picked.readAsBytes());
      if (decoded == null) {
        throw const FormatException('无法读取图片');
      }
      final oriented = img.bakeOrientation(decoded);
      if (!mounted) return;
      final crop = await showDialog<img.Image>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _BackgroundCropDialog(source: oriented, aspectRatio: aspectRatio),
      );
      if (crop == null || !mounted) return;
      final directory = await getApplicationDocumentsDirectory();
      final targetPath = p.join(
        directory.path,
        'timetable_background_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(targetPath).writeAsBytes(img.encodeJpg(crop, quality: 90));
      final oldPath = ref.read(appSettingsProvider).timetableBackgroundPath;
      await ref
          .read(appSettingsProvider.notifier)
          .setTimetableBackgroundPath(targetPath);
      if (oldPath != null && oldPath != targetPath) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      }
      if (mounted) {
        showAppSnackBar(context, '背景图已更新', severity: ToastSeverity.success);
      }
    } catch (error, stackTrace) {
      talker.error('保存课表背景图失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '背景图保存失败', severity: ToastSeverity.error);
      }
    }
  }

  Future<void> _clearBackground() async {
    final path = ref.read(appSettingsProvider).timetableBackgroundPath;
    await ref
        .read(appSettingsProvider.notifier)
        .setTimetableBackgroundPath(null);
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (error, stackTrace) {
          talker.warning('删除课表背景图文件失败', error, stackTrace);
        }
      }
    }
    if (mounted) {
      showAppSnackBar(context, '背景图已清除', severity: ToastSeverity.success);
    }
  }

  Future<void> _resetAppearance() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '重置个性化设置',
      message: '将恢复课表文字、边框、透明度、网格和背景图的默认设置。',
      confirmLabel: '重置',
    );
    if (!confirmed || !mounted) return;

    final backgroundPath = ref
        .read(appSettingsProvider)
        .timetableBackgroundPath;
    await ref.read(appSettingsProvider.notifier).resetTimetableAppearance();
    if (backgroundPath != null && backgroundPath.isNotEmpty) {
      final file = File(backgroundPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (error, stackTrace) {
          talker.warning('删除课表背景图文件失败', error, stackTrace);
        }
      }
    }
    if (mounted) {
      showAppSnackBar(context, '个性化设置已重置', severity: ToastSeverity.success);
    }
  }
}

class _TimetableAdjustment {
  final DateTime sourceDate;
  final String operation;
  final DateTime? targetDate;

  const _TimetableAdjustment({
    required this.sourceDate,
    required this.operation,
    this.targetDate,
  });
}

class _TimetableDaySnapshot {
  final DateTime date;
  final List<Course> originalCourses;
  final List<Course> currentCourses;

  const _TimetableDaySnapshot({
    required this.date,
    required this.originalCourses,
    required this.currentCourses,
  });
}

class _BackgroundCropDialog extends StatefulWidget {
  final img.Image source;
  final double aspectRatio;

  const _BackgroundCropDialog({
    required this.source,
    required this.aspectRatio,
  });

  @override
  State<_BackgroundCropDialog> createState() => _BackgroundCropDialogState();
}

class _BackgroundCropDialogState extends State<_BackgroundCropDialog> {
  late final Uint8List _previewBytes = Uint8List.fromList(
    img.encodeJpg(widget.source, quality: 95),
  );
  Offset _offset = Offset.zero;
  _BackgroundCropMetrics? _lastMetrics;

  _BackgroundCropMetrics _metrics(Size canvasSize) {
    final aspectRatio = widget.aspectRatio.isFinite && widget.aspectRatio > 0
        ? widget.aspectRatio
        : 1.0;
    final frameWidth = math.min(
      canvasSize.width - 24,
      (canvasSize.height - 24) * aspectRatio,
    );
    final frameHeight = frameWidth / aspectRatio;
    final cropRect = Rect.fromCenter(
      center: canvasSize.center(Offset.zero),
      width: frameWidth,
      height: frameHeight,
    );
    final scale = math.max(
      frameWidth / widget.source.width,
      frameHeight / widget.source.height,
    );
    final imageWidth = widget.source.width * scale;
    final imageHeight = widget.source.height * scale;
    final baseLeft = (canvasSize.width - imageWidth) / 2;
    final baseTop = (canvasSize.height - imageHeight) / 2;
    return _BackgroundCropMetrics(
      cropRect: cropRect,
      scale: scale,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      baseLeft: baseLeft,
      baseTop: baseTop,
    );
  }

  Offset _clampOffset(Offset offset, _BackgroundCropMetrics metrics) {
    final minX =
        metrics.cropRect.right - (metrics.baseLeft + metrics.imageWidth);
    final maxX = metrics.cropRect.left - metrics.baseLeft;
    final minY =
        metrics.cropRect.bottom - (metrics.baseTop + metrics.imageHeight);
    final maxY = metrics.cropRect.top - metrics.baseTop;
    return Offset(
      offset.dx.clamp(minX, maxX).toDouble(),
      offset.dy.clamp(minY, maxY).toDouble(),
    );
  }

  img.Image _crop(_BackgroundCropMetrics metrics) {
    final imageLeft = metrics.baseLeft + _offset.dx;
    final imageTop = metrics.baseTop + _offset.dy;
    final x = ((metrics.cropRect.left - imageLeft) / metrics.scale)
        .round()
        .clamp(0, widget.source.width - 1)
        .toInt();
    final y = ((metrics.cropRect.top - imageTop) / metrics.scale)
        .round()
        .clamp(0, widget.source.height - 1)
        .toInt();
    final width = (metrics.cropRect.width / metrics.scale)
        .round()
        .clamp(1, widget.source.width - x)
        .toInt();
    final height = (metrics.cropRect.height / metrics.scale)
        .round()
        .clamp(1, widget.source.height - y)
        .toInt();
    return img.copyCrop(
      widget.source,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '调整背景图',
              textAlign: TextAlign.center,
              style: theme.typography.pageTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '拖动图片选择显示位置',
              textAlign: TextAlign.center,
              style: theme.typography.caption.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final canvasHeight = math.min(
                  400.0,
                  math.max(220.0, MediaQuery.sizeOf(context).height * 0.48),
                );
                final canvasSize = Size(constraints.maxWidth, canvasHeight);
                final metrics = _metrics(canvasSize);
                _lastMetrics = metrics;
                final imageLeft = metrics.baseLeft + _offset.dx;
                final imageTop = metrics.baseTop + _offset.dy;
                return SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        _offset = _clampOffset(
                          _offset + details.delta,
                          metrics,
                        );
                      });
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: theme.colors.muted),
                          Positioned(
                            left: imageLeft,
                            top: imageTop,
                            width: metrics.imageWidth,
                            height: metrics.imageHeight,
                            child: Image.memory(
                              _previewBytes,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _CropOverlayPainter(metrics.cropRect),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FButton(
                  variant: FButtonVariant.ghost,
                  onPress: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FButton(
                  onPress: () {
                    final metrics = _lastMetrics;
                    if (metrics != null) {
                      Navigator.pop(context, _crop(metrics));
                    }
                  },
                  child: const Text('使用此位置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundCropMetrics {
  final Rect cropRect;
  final double scale;
  final double imageWidth;
  final double imageHeight;
  final double baseLeft;
  final double baseTop;

  const _BackgroundCropMetrics({
    required this.cropRect,
    required this.scale,
    required this.imageWidth,
    required this.imageHeight,
    required this.baseLeft,
    required this.baseTop,
  });
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  const _CropOverlayPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = const Color(0x99000000);
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), shade)
      ..drawRect(
        Rect.fromLTWH(
          0,
          cropRect.bottom,
          size.width,
          size.height - cropRect.bottom,
        ),
        shade,
      )
      ..drawRect(
        Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height),
        shade,
      )
      ..drawRect(
        Rect.fromLTWH(
          cropRect.right,
          cropRect.top,
          size.width - cropRect.right,
          cropRect.height,
        ),
        shade,
      );

    final border = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, border);

    final guide = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 0.7;
    for (var i = 1; i < 3; i++) {
      final dx = cropRect.left + cropRect.width * i / 3;
      final dy = cropRect.top + cropRect.height * i / 3;
      canvas
        ..drawLine(Offset(dx, cropRect.top), Offset(dx, cropRect.bottom), guide)
        ..drawLine(
          Offset(cropRect.left, dy),
          Offset(cropRect.right, dy),
          guide,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}
