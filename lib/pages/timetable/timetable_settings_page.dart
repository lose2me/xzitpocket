import 'dart:async';
import 'dart:io';
import 'dart:isolate';
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
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';
import '../profile/profile_components.dart';
import 'timetable_providers.dart';

int _tenthsDivisions(double min, double max) => ((max - min) * 10).round();

double _backgroundAspectRatio(Size size) {
  final width = size.width.clamp(1.0, double.infinity).toDouble();
  final height = size.height.clamp(1.0, double.infinity).toDouble();
  return width / height;
}

class TimetableSettingsPage extends ConsumerStatefulWidget {
  const TimetableSettingsPage({super.key});

  @override
  ConsumerState<TimetableSettingsPage> createState() =>
      _TimetableSettingsPageState();
}

class _TimetableSettingsPageState extends ConsumerState<TimetableSettingsPage> {
  final _imagePicker = ImagePicker();
  bool _adjustmentDetailsExpanded = false;
  bool _cloudRulesExpanded = false;
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
      title: '个性化设置',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          _TimetableStylePreview(settings: settings),
          const SizedBox(height: AppSpacing.md),
          _WidgetStylePreview(settings: settings),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '小组件样式'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.sunMoon,
                title: '小组件主题',
                value: _widgetThemeLabel(settings.widgetThemePreference),
                onTap: () => _openWidgetThemeSheet(
                  settings.widgetThemePreference,
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.type,
                title: '小组件字体缩放',
                value: '${settings.widgetFontScale.toStringAsFixed(1)}x',
                onTap: () => _openNumberSheet(
                  title: '小组件字体缩放',
                  currentValue: settings.widgetFontScale,
                  min: 0.5,
                  max: 2.0,
                  divisions: _tenthsDivisions(0.5, 2.0),
                  suffix: 'x',
                  onSave: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .setWidgetFontScale(value),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.layers,
                title: '小组件背景透明度',
                value: '${(settings.widgetBackgroundAlpha * 100).round()}%',
                onTap: () => _openOpacitySheet(
                  title: '小组件背景透明度',
                  currentValue: settings.widgetBackgroundAlpha,
                  onSave: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .setWidgetBackgroundAlpha(value),
                ),
              ),
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.calendarDays,
                title: '隐藏小组件日期',
                value: settings.widgetHideDate,
                onChange: (value) => ref
                    .read(appSettingsProvider.notifier)
                    .setWidgetHideDate(value),
              ),
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.mapPinOff,
                title: '隐藏小组件地点',
                value: settings.widgetHideLocation,
                onChange: (value) => ref
                    .read(appSettingsProvider.notifier)
                    .setWidgetHideLocation(value),
              ),
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.userRoundX,
                title: '隐藏小组件教师',
                value: settings.widgetHideTeacher,
                onChange: (value) => ref
                    .read(appSettingsProvider.notifier)
                    .setWidgetHideTeacher(value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
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
                onLongPress: settings.timetableBackgroundPath == null
                    ? null
                    : _clearBackground,
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

  String _widgetThemeLabel(WidgetThemePreference preference) => switch (
    preference
  ) {
    WidgetThemePreference.system => '跟随系统',
    WidgetThemePreference.light => '浅色',
    WidgetThemePreference.dark => '深色',
  };

  Future<void> _openWidgetThemeSheet(
    WidgetThemePreference current,
  ) async {
    final selected = await showAppSheet<WidgetThemePreference>(
      context: context,
      builder: (context) => AppOptionSheet<WidgetThemePreference>(
        title: '小组件主题',
        value: current,
        options: [
          for (final item in WidgetThemePreference.values)
            AppOption(
              value: item,
              title: _widgetThemeLabel(item),
              icon: item == current
                  ? FLucideIcons.circleCheck
                  : FLucideIcons.circle,
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    await ref
        .read(appSettingsProvider.notifier)
        .setWidgetThemePreference(selected);
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
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    try {
      final aspectRatio = _backgroundAspectRatio(MediaQuery.sizeOf(context));
      final sourceBytes = await picked.readAsBytes();
      if (!mounted) return;
      final crop = await _selectBackgroundCrop(sourceBytes, aspectRatio);
      if (crop == null || !mounted) return;
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = p.join(
        directory.path,
        'timetable_background_$timestamp.jpg',
      );
      final cropBytes = await _encodeJpgInIsolate(crop, quality: 90);
      await File(targetPath).writeAsBytes(cropBytes);
      final oldPath = ref.read(appSettingsProvider).timetableBackgroundPath;
      await ref
          .read(appSettingsProvider.notifier)
          .setTimetableBackgroundPath(targetPath);
      if (oldPath != null && oldPath != targetPath) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      }
      await _deleteLegacyBackgroundCopies();
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

  Future<img.Image?> _selectBackgroundCrop(
    Uint8List sourceBytes,
    double aspectRatio,
  ) => Navigator.of(context).push<img.Image>(
    MaterialPageRoute(
      builder: (_) => _BackgroundCropPage(
        sourceBytes: sourceBytes,
        aspectRatio: aspectRatio,
      ),
    ),
  );

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
    await _deleteLegacyBackgroundCopies();
    if (mounted) {
      showAppSnackBar(context, '背景图已清除', severity: ToastSeverity.success);
    }
  }

  Future<void> _resetAppearance() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '重置个性化设置',
      message: '将恢复课表、小组件的文字、透明度、网格和背景图默认设置。',
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
    await _deleteLegacyBackgroundCopies();
    if (mounted) {
      showAppSnackBar(context, '个性化设置已重置', severity: ToastSeverity.success);
    }
  }

  Future<void> _deleteLegacyBackgroundCopies() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      await for (final entity in directory.list()) {
        if (entity is! File ||
            !p
                .basename(entity.path)
                .startsWith('timetable_background_original_')) {
          continue;
        }
        try {
          await entity.delete();
        } catch (error, stackTrace) {
          talker.warning('删除旧课表背景图原图失败', error, stackTrace);
        }
      }
    } catch (error, stackTrace) {
      talker.warning('清理旧课表背景图原图失败', error, stackTrace);
    }
  }
}

class _TimetableStylePreview extends StatelessWidget {
  final AppSettings settings;

  const _TimetableStylePreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final cardColor = theme.colors.primary.withValues(
      alpha: settings.timetableComponentOpacity,
    );
    final borderColor = theme.colors.foreground.withValues(
      alpha: settings.timetableCourseBorderOpacity,
    );
    final backgroundPath = settings.timetableBackgroundPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 168,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backgroundPath != null && backgroundPath.isNotEmpty)
              Image.file(
                File(backgroundPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: theme.colors.background),
              )
            else
              ColoredBox(color: theme.colors.background),
            ColoredBox(color: theme.colors.background.withValues(alpha: 0.18)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '课表预览',
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.mutedForeground,
                      fontSize: settings.timetableDateTextSize,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              for (final text in const ['1', '2', '3'])
                                Text(
                                  text,
                                  style: theme.typography.caption.copyWith(
                                    fontSize: settings.timetableTimeTextSize,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _PreviewCourseBlock(
                                  title: '高等数学',
                                  subtitle: '08:00  教学楼',
                                  color: cardColor,
                                  borderColor: borderColor,
                                  borderWidth:
                                      settings.timetableCourseBorderWidth,
                                  textSize: settings.timetableCourseTextSize,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: _PreviewCourseBlock(
                                  title: '英语',
                                  subtitle: '10:05  A201',
                                  color: theme.colors.secondary.withValues(
                                    alpha: settings.timetableComponentOpacity,
                                  ),
                                  borderColor: borderColor,
                                  borderWidth:
                                      settings.timetableCourseBorderWidth,
                                  textSize: settings.timetableCourseTextSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetStylePreview extends StatelessWidget {
  final AppSettings settings;

  const _WidgetStylePreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final details = [
      if (!settings.widgetHideLocation) '教学楼 A201',
      if (!settings.widgetHideTeacher) '张老师',
    ].join(' · ');
    final textScale = settings.widgetFontScale;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colors.background,
          border: Border.all(color: theme.colors.border),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.primary.withValues(
              alpha: settings.widgetBackgroundAlpha,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!settings.widgetHideDate)
                  Text(
                    '今天  第 3 周',
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.mutedForeground,
                      fontSize: 11 * textScale,
                    ),
                  ),
                Text(
                  '高等数学',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14 * textScale,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(
                      fontSize: 11 * textScale,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewCourseBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double textSize;

  const _PreviewCourseBlock({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    required this.textSize,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: borderColor, width: borderWidth),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.theme.typography.bodySmall.copyWith(
              fontSize: textSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.theme.typography.caption,
          ),
        ],
      ),
    ),
  );
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

Future<Uint8List> _prepareCropSource(Uint8List bytes) async {
  return Isolate.run(() {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return Uint8List(0);
    var oriented = img.bakeOrientation(decoded);
    const maxDimension = 2400;
    if (oriented.width > maxDimension || oriented.height > maxDimension) {
      oriented = img.copyResize(
        oriented,
        width: oriented.width >= oriented.height ? maxDimension : null,
        height: oriented.height > oriented.width ? maxDimension : null,
        interpolation: img.Interpolation.average,
      );
    }
    return Uint8List.fromList(img.encodeJpg(oriented, quality: 92));
  });
}

Future<Uint8List> _encodeJpgInIsolate(img.Image image, {required int quality}) {
  return Isolate.run(
    () => Uint8List.fromList(img.encodeJpg(image, quality: quality)),
  );
}

class _BackgroundCropPage extends StatefulWidget {
  final Uint8List sourceBytes;
  final double aspectRatio;

  const _BackgroundCropPage({
    required this.sourceBytes,
    required this.aspectRatio,
  });

  @override
  State<_BackgroundCropPage> createState() => _BackgroundCropPageState();
}

class _BackgroundCropPageState extends State<_BackgroundCropPage> {
  img.Image? _source;
  Uint8List? _previewBytes;
  Object? _loadError;
  Rect? _selectionRect;
  Rect? _gestureStartSelection;
  _BackgroundCropMetrics? _lastMetrics;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSource());
  }

  Future<void> _loadSource() async {
    try {
      final bytes = await _prepareCropSource(widget.sourceBytes);
      if (bytes.isEmpty) throw const FormatException('无法读取图片');
      final source = img.decodeImage(bytes);
      if (source == null) throw const FormatException('无法读取图片');
      if (!mounted) return;
      setState(() {
        _source = source;
        _previewBytes = bytes;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  _BackgroundCropMetrics _metrics(Size canvasSize) {
    final source = _source!;
    final aspectRatio = widget.aspectRatio.isFinite && widget.aspectRatio > 0
        ? widget.aspectRatio
        : 1.0;
    final imageScale = math.max(
      canvasSize.width / source.width,
      canvasSize.height / source.height,
    );
    final imageRect = Rect.fromCenter(
      center: canvasSize.center(Offset.zero),
      width: source.width * imageScale,
      height: source.height * imageScale,
    );
    final selectionBounds = imageRect.intersect(Offset.zero & canvasSize);
    final maxWidth = math.min(
      selectionBounds.width,
      selectionBounds.height * aspectRatio,
    );
    final defaultWidth = maxWidth * 0.86;
    final defaultHeight = defaultWidth / aspectRatio;
    final defaultRect = Rect.fromCenter(
      center: selectionBounds.center,
      width: defaultWidth,
      height: defaultHeight,
    );
    return _BackgroundCropMetrics(
      imageRect: imageRect,
      selectionBounds: selectionBounds,
      sourceScale: imageScale,
      defaultCropRect: defaultRect,
    );
  }

  Rect _clampSelection(Rect rect, _BackgroundCropMetrics metrics) {
    final aspectRatio = widget.aspectRatio.isFinite && widget.aspectRatio > 0
        ? widget.aspectRatio
        : 1.0;
    final maxWidth = math.min(
      metrics.selectionBounds.width,
      metrics.selectionBounds.height * aspectRatio,
    );
    final minWidth = math.min(72.0, maxWidth);
    final width = rect.width.clamp(minWidth, maxWidth).toDouble();
    final height = width / aspectRatio;
    final center = Offset(
      rect.center.dx.clamp(
        metrics.selectionBounds.left + width / 2,
        metrics.selectionBounds.right - width / 2,
      ),
      rect.center.dy.clamp(
        metrics.selectionBounds.top + height / 2,
        metrics.selectionBounds.bottom - height / 2,
      ),
    );
    return Rect.fromCenter(center: center, width: width, height: height);
  }

  img.Image _crop(_BackgroundCropMetrics metrics) {
    final source = _source!;
    final cropRect = _selectionRect ?? metrics.defaultCropRect;
    final x = ((cropRect.left - metrics.imageRect.left) / metrics.sourceScale)
        .round()
        .clamp(0, source.width - 1)
        .toInt();
    final y = ((cropRect.top - metrics.imageRect.top) / metrics.sourceScale)
        .round()
        .clamp(0, source.height - 1)
        .toInt();
    final width = (cropRect.width / metrics.sourceScale)
        .round()
        .clamp(1, source.width - x)
        .toInt();
    final height = (cropRect.height / metrics.sourceScale)
        .round()
        .clamp(1, source.height - y)
        .toInt();
    return img.copyCrop(source, x: x, y: y, width: width, height: height);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AppPage(
      title: '调整背景图',
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppSpacing.sm,
            0,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final source = _source;
                    final previewBytes = _previewBytes;
                    if (source == null || previewBytes == null) {
                      return Center(
                        child: _loadError == null
                            ? const CircularProgressIndicator()
                            : Text('图片读取失败', style: theme.typography.bodySmall),
                      );
                    }
                    final canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final metrics = _metrics(canvasSize);
                    final selection = _clampSelection(
                      _selectionRect ?? metrics.defaultCropRect,
                      metrics,
                    );
                    _selectionRect = selection;
                    _lastMetrics = metrics;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) {
                        _gestureStartSelection = selection;
                      },
                      onScaleUpdate: (details) {
                        final start = _gestureStartSelection ?? selection;
                        final current = _selectionRect ?? start;
                        final isPinching = details.pointerCount > 1;
                        final aspectRatio =
                            widget.aspectRatio.isFinite &&
                                widget.aspectRatio > 0
                            ? widget.aspectRatio
                            : 1.0;
                        final width = isPinching
                            ? start.width * details.scale
                            : start.width;
                        final moved = Rect.fromCenter(
                          center: current.center + details.focalPointDelta,
                          width: width,
                          height: width / aspectRatio,
                        );
                        setState(() {
                          _selectionRect = _clampSelection(moved, metrics);
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: theme.colors.muted),
                          Positioned.fromRect(
                            rect: metrics.imageRect,
                            child: Image.memory(
                              previewBytes,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _CropOverlayPainter(selection),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
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
                      if (metrics != null && _source != null) {
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
      ),
    );
  }
}

class _BackgroundCropMetrics {
  final Rect imageRect;
  final Rect selectionBounds;
  final double sourceScale;
  final Rect defaultCropRect;

  const _BackgroundCropMetrics({
    required this.imageRect,
    required this.selectionBounds,
    required this.sourceScale,
    required this.defaultCropRect,
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
