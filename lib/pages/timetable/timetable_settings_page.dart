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
import 'timetable_grid.dart';
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
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final showWeekendColumns = ref.watch(showWeekendColumnsProvider);
    return AppPage(
      title: '个性化设置',
      child: Column(
        children: [
          SizedBox(
            height: 340,
            child: _TimetableGridPreview(
              settings: settings,
              showWeekendColumns: showWeekendColumns,
            ),
          ),
          Expanded(
            child: AppPageListView(
              maxWidth: AppLayout.resultMaxWidth,
              topPadding: AppSpacing.md,
              bottomPadding: AppSpacing.xxl,
              children: [
                const ProfileSectionLabel(title: '软件主题'),
                ProfileSettingsGroup(
                  children: [
                    ProfileSettingsTile(
                      icon: FLucideIcons.sunMoon,
                      title: '主题模式',
                      value: _themeTitle(settings.themePreference),
                      onTap: () => _openThemeSheet(settings.themePreference),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.palette,
                      title: '软件主题色',
                      value: settings.themeColor.label,
                      onTap: () => _openThemeColorSheet(settings.themeColor),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const ProfileSectionLabel(title: '课表网格'),
                ProfileSettingsGroup(
                  children: [
                    ProfileSettingsTile(
                      icon: FLucideIcons.rows3,
                      title: '课节高度',
                      value:
                          '${settings.timetableSectionHeight.toStringAsFixed(0)} px',
                      onTap: () => _openNumberSheet(
                        title: '课节高度',
                        currentValue: settings.timetableSectionHeight,
                        min: 40,
                        max: 140,
                        divisions: 100,
                        suffix: ' px',
                        onSave: (value) => ref
                            .read(appSettingsProvider.notifier)
                            .setTimetableSectionHeight(value),
                      ),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.columns3,
                      title: '时间列宽度',
                      value:
                          '${settings.timetableTimeColumnWidth.toStringAsFixed(0)} px',
                      onTap: () => _openNumberSheet(
                        title: '时间列宽度',
                        currentValue: settings.timetableTimeColumnWidth,
                        min: 20,
                        max: 80,
                        divisions: 60,
                        suffix: ' px',
                        onSave: (value) => ref
                            .read(appSettingsProvider.notifier)
                            .setTimetableTimeColumnWidth(value),
                      ),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.panelTop,
                      title: '日期栏高度',
                      value:
                          '${settings.timetableDayHeaderHeight.toStringAsFixed(0)} px',
                      onTap: () => _openNumberSheet(
                        title: '日期栏高度',
                        currentValue: settings.timetableDayHeaderHeight,
                        min: 30,
                        max: 80,
                        divisions: 50,
                        suffix: ' px',
                        onSave: (value) => ref
                            .read(appSettingsProvider.notifier)
                            .setTimetableDayHeaderHeight(value),
                      ),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.type,
                      title: '课程字体缩放',
                      value:
                          '${settings.timetableCourseFontScale.toStringAsFixed(1)}x',
                      onTap: () => _openNumberSheet(
                        title: '课程字体缩放',
                        currentValue: settings.timetableCourseFontScale,
                        min: 0.5,
                        max: 2,
                        divisions: 15,
                        suffix: 'x',
                        onSave: (value) => ref
                            .read(appSettingsProvider.notifier)
                            .setTimetableCourseFontScale(value),
                      ),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.cornerDownRight,
                      title: '课程块圆角',
                      value:
                          '${settings.timetableCourseCornerRadius.toStringAsFixed(0)} px',
                      onTap: () => _openNumberSheet(
                        title: '课程块圆角',
                        currentValue: settings.timetableCourseCornerRadius,
                        min: 0,
                        max: 24,
                        divisions: 24,
                        suffix: ' px',
                        onSave: (value) => ref
                            .read(appSettingsProvider.notifier)
                            .setTimetableCourseCornerRadius(value),
                      ),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.arrowDownUp,
                      title: '课程块内边距',
                      value:
                          '${settings.timetableCourseInnerPadding.toStringAsFixed(0)} px',
                      onTap: () => _openNumberSheet(
                        title: '课程块内边距',
                        currentValue: settings.timetableCourseInnerPadding,
                        min: 0,
                        max: 12,
                        divisions: 12,
                        suffix: ' px',
                        onSave: (value) => ref
                            .read(appSettingsProvider.notifier)
                            .setTimetableCourseInnerPadding(value),
                      ),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.move,
                      title: '课程块外边距',
                      value:
                          '${settings.timetableCourseOuterPadding.toStringAsFixed(0)} px',
                      onTap: () => _openNumberSheet(
                        title: '课程块外边距',
                        currentValue: settings.timetableCourseOuterPadding,
                        min: 0,
                        max: 8,
                        divisions: 8,
                        suffix: ' px',
                        onSave: (value) => ref
                            .read(appSettingsProvider.notifier)
                            .setTimetableCourseOuterPadding(value),
                      ),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.layers,
                      title: '课程块透明度',
                      value:
                          '${(settings.timetableCourseAlpha * 100).round()}%',
                      onTap: () => _openOpacitySheet(
                        title: '课程块透明度',
                        currentValue: settings.timetableCourseAlpha,
                        onSave: (value) => ref
                            .read(appSettingsProvider.notifier)
                            .setTimetableCourseAlpha(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const ProfileSectionLabel(title: '课程显示'),
                ProfileSettingsGroup(
                  children: [
                    ProfileSettingsCheckboxTile(
                      icon: FLucideIcons.clock3,
                      title: '隐藏时间细节',
                      value: settings.timetableHideSectionTime,
                      onChange: (value) => ref
                          .read(appSettingsProvider.notifier)
                          .setTimetableHideSectionTime(value),
                    ),
                    ProfileSettingsCheckboxTile(
                      icon: FLucideIcons.calendarDays,
                      title: '隐藏日期',
                      value: settings.timetableHideDateUnderDay,
                      onChange: (value) => ref
                          .read(appSettingsProvider.notifier)
                          .setTimetableHideDateUnderDay(value),
                    ),
                    ProfileSettingsCheckboxTile(
                      icon: FLucideIcons.clock,
                      title: '显示上课时间',
                      value: settings.timetableShowStartTime,
                      onChange: (value) => ref
                          .read(appSettingsProvider.notifier)
                          .setTimetableShowStartTime(value),
                    ),
                    ProfileSettingsCheckboxTile(
                      icon: FLucideIcons.mapPinOff,
                      title: '隐藏地点',
                      value: settings.timetableHideLocation,
                      onChange: (value) => ref
                          .read(appSettingsProvider.notifier)
                          .setTimetableHideLocation(value),
                    ),
                    ProfileSettingsCheckboxTile(
                      icon: FLucideIcons.userRoundX,
                      title: '隐藏教师',
                      value: settings.timetableHideTeacher,
                      onChange: (value) => ref
                          .read(appSettingsProvider.notifier)
                          .setTimetableHideTeacher(value),
                    ),
                    ProfileSettingsCheckboxTile(
                      icon: FLucideIcons.atSign,
                      title: '移除地点前的 @',
                      value: settings.timetableRemoveLocationAt,
                      onChange: (value) => ref
                          .read(appSettingsProvider.notifier)
                          .setTimetableRemoveLocationAt(value),
                    ),
                    ProfileSettingsCheckboxTile(
                      icon: FLucideIcons.alignCenterHorizontal,
                      title: '课程文字水平居中',
                      value: settings.timetableTextAlignCenterHorizontal,
                      onChange: (value) => ref
                          .read(appSettingsProvider.notifier)
                          .setTimetableTextAlignCenterHorizontal(value),
                    ),
                    ProfileSettingsCheckboxTile(
                      icon: FLucideIcons.alignCenterVertical,
                      title: '课程文字垂直居中',
                      value: settings.timetableTextAlignCenterVertical,
                      onChange: (value) => ref
                          .read(appSettingsProvider.notifier)
                          .setTimetableTextAlignCenterVertical(value),
                    ),
                    ProfileSettingsCheckboxTile(
                      icon: FLucideIcons.grid2x2,
                      title: '隐藏网格线',
                      value: !settings.showTimetableGridLines,
                      onChange: (value) => ref
                          .read(appSettingsProvider.notifier)
                          .setShowTimetableGridLines(!value),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.type,
                      title: '页面文字颜色',
                      value: _colorLabel(settings.timetablePageTextColor),
                      onTap: () => _openStyleColorSheet(
                        title: '页面文字颜色',
                        current: settings.timetablePageTextColor,
                        onSave: ref
                            .read(appSettingsProvider.notifier)
                            .setTimetablePageTextColor,
                      ),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.type,
                      title: '课程块文字颜色',
                      value: _colorLabel(settings.timetableCourseTextColor),
                      onTap: () => _openStyleColorSheet(
                        title: '课程块文字颜色',
                        current: settings.timetableCourseTextColor,
                        onSave: ref
                            .read(appSettingsProvider.notifier)
                            .setTimetableCourseTextColor,
                      ),
                    ),
                    ProfileSettingsTile(
                      icon: FLucideIcons.squareDashed,
                      title: '课程块边框',
                      value: _borderTypeLabel(settings.timetableBorderType),
                      onTap: () =>
                          _openBorderTypeSheet(settings.timetableBorderType),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const ProfileSectionLabel(title: '小组件样式'),
                ProfileSettingsGroup(
                  children: [
                    ProfileSettingsTile(
                      icon: FLucideIcons.sunMoon,
                      title: '小组件主题',
                      value: _widgetThemeLabel(settings.widgetThemePreference),
                      onTap: () =>
                          _openWidgetThemeSheet(settings.widgetThemePreference),
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
                      value:
                          '${(settings.widgetBackgroundAlpha * 100).round()}%',
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
                const ProfileSectionLabel(title: '背景图'),
                ProfileSettingsGroup(
                  children: [
                    ProfileSettingsTile(
                      icon: FLucideIcons.image,
                      title: '课表背景图',
                      value: settings.timetableBackgroundPath == null
                          ? '未设置'
                          : '已设置',
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
          ),
        ],
      ),
    );
  }

  // Kept for compatibility with older callers while rules live on their own page.
  // ignore: unused_element
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

  // ignore: unused_element
  Future<void> _setCloudAdjustmentsEnabled(bool enabled) async {
    await ref
        .read(appSettingsProvider.notifier)
        .setUseCloudTimetableAdjustments(enabled);
    if (enabled && mounted) {
      await ref.read(scheduleProvider.notifier).applyCloudAdjustments();
    }
  }

  // ignore: unused_element
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

  // ignore: unused_element
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

  String _widgetThemeLabel(WidgetThemePreference preference) =>
      switch (preference) {
        WidgetThemePreference.system => '跟随系统',
        WidgetThemePreference.light => '浅色',
        WidgetThemePreference.dark => '深色',
      };

  String _themeTitle(AppThemePreference preference) => switch (preference) {
    AppThemePreference.system => '跟随系统',
    AppThemePreference.light => '浅色模式',
    AppThemePreference.dark => '深色模式',
  };

  String _borderTypeLabel(TimetableBorderType type) => switch (type) {
    TimetableBorderType.none => '无边框',
    TimetableBorderType.solid => '实线',
    TimetableBorderType.dashed => '虚线',
  };

  String _colorLabel(Color? color) {
    if (color == null) return '跟随主题';
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  Future<void> _openStyleColorSheet({
    required String title,
    required Color? current,
    required Future<void> Function(Color? value) onSave,
  }) async {
    final resetToken = Object();
    const palette = [
      Color(0xFF172033),
      Color(0xFF475569),
      Color(0xFF64748B),
      Color(0xFF2563EB),
      Color(0xFF047857),
      Color(0xFFBE123C),
      Color(0xFFC2410C),
      Color(0xFF7C3AED),
      Color(0xFFF8FAFC),
    ];
    final selected = await showAppSheet<Object?>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final color in palette)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(color),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: current == color
                              ? context.theme.colors.primary
                              : context.theme.colors.border,
                          width: current == color ? 3 : 1,
                        ),
                      ),
                      child: const SizedBox(width: 38, height: 38),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => Navigator.of(context).pop(resetToken),
              child: const Text('跟随主题'),
            ),
          ],
        ),
      ),
    );
    if (selected == resetToken) {
      await onSave(null);
    } else if (selected is Color && selected != current) {
      await onSave(selected);
    }
  }

  Future<void> _openBorderTypeSheet(TimetableBorderType current) async {
    final selected = await showAppSheet<TimetableBorderType>(
      context: context,
      builder: (context) => AppOptionSheet<TimetableBorderType>(
        title: '课程块边框',
        value: current,
        options: [
          for (final type in TimetableBorderType.values)
            AppOption(
              value: type,
              title: _borderTypeLabel(type),
              icon: type == current
                  ? FLucideIcons.circleCheck
                  : FLucideIcons.square,
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    await ref
        .read(appSettingsProvider.notifier)
        .setTimetableBorderType(selected);
  }

  Future<void> _openThemeSheet(AppThemePreference current) async {
    final selected = await showAppSheet<AppThemePreference>(
      context: context,
      builder: (context) => AppOptionSheet<AppThemePreference>(
        title: '主题模式',
        value: current,
        options: const [
          AppOption(
            value: AppThemePreference.system,
            title: '跟随系统',
            icon: FLucideIcons.settings,
          ),
          AppOption(
            value: AppThemePreference.light,
            title: '浅色模式',
            icon: FLucideIcons.sun,
          ),
          AppOption(
            value: AppThemePreference.dark,
            title: '深色模式',
            icon: FLucideIcons.moon,
          ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    await ref.read(appSettingsProvider.notifier).setThemePreference(selected);
  }

  Future<void> _openThemeColorSheet(AppThemeColor current) async {
    final selected = await showAppSheet<AppThemeColor>(
      context: context,
      builder: (context) => AppOptionSheet<AppThemeColor>(
        title: '软件主题色',
        value: current,
        options: [
          for (final color in AppThemeColor.values)
            AppOption(
              value: color,
              title: color.label,
              icon: color == current
                  ? FLucideIcons.circleCheck
                  : FLucideIcons.circle,
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    await ref.read(appSettingsProvider.notifier).setThemeColor(selected);
  }

  Future<void> _openWidgetThemeSheet(WidgetThemePreference current) async {
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

class _TimetableGridPreview extends StatelessWidget {
  final AppSettings settings;
  final bool showWeekendColumns;

  const _TimetableGridPreview({
    required this.settings,
    required this.showWeekendColumns,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // A fixed, representative week keeps the preview deterministic while
    // using the same real course names, teachers and locations as the school
    // schedule. It is intentionally independent from the signed-in user's
    // data so opening settings never performs a network request.
    final previewCourses = [
      Course(
        title: '概率统计',
        teacher: '胡江',
        weekday: 1,
        sessions: [1, 2],
        weeks: List.generate(14, (i) => i + 1),
        campus: '中心校区',
        place: '敬业F308',
        colorIndex: 0,
      ),
      Course(
        title: '大学物理B(Ⅱ)',
        teacher: '陈凯',
        weekday: 1,
        sessions: [3, 4],
        weeks: List.generate(16, (i) => i + 1),
        campus: '中心校区',
        place: '敬本C401',
        colorIndex: 1,
      ),
      Course(
        title: '大学英语A（Ⅲ）— 英汉互译',
        teacher: '郝倩',
        weekday: 1,
        sessions: [7, 8],
        weeks: List.generate(16, (i) => i + 1),
        campus: '中心校区',
        place: '敬信405',
        colorIndex: 2,
      ),
      Course(
        title: '数学分析（Ⅲ）',
        teacher: '李佳',
        weekday: 2,
        sessions: [1, 2],
        weeks: List.generate(16, (i) => i + 1),
        campus: '中心校区',
        place: '敬本C401',
        colorIndex: 3,
      ),
      Course(
        title: '离散数学',
        teacher: '张克军',
        weekday: 2,
        sessions: [3, 4],
        weeks: List.generate(16, (i) => i + 1),
        campus: '中心校区',
        place: '敬本C503',
        colorIndex: 4,
      ),
      Course(
        title: '体育(Ⅲ)太极拳',
        teacher: '高成强',
        weekday: 2,
        sessions: [7, 8],
        weeks: List.generate(16, (i) => i + 1),
        campus: '中心校区',
        place: '中心校区二期操场东侧跑道或二期北门东侧梧桐树下',
        colorIndex: 5,
      ),
      Course(
        title: '中国近现代史纲要',
        teacher: '王娟',
        weekday: 2,
        sessions: [9, 10],
        weeks: [13, 14, 15, 16],
        campus: '中心校区',
        place: '敬业F310',
        colorIndex: 6,
      ),
      Course(
        title: 'Java程序设计',
        teacher: '梁传威',
        weekday: 3,
        sessions: [1, 2],
        weeks: List.generate(16, (i) => i + 1),
        campus: '中心校区',
        place: '敬知楼502',
        colorIndex: 7,
      ),
      Course(
        title: 'Java程序设计实验',
        teacher: '梁传威',
        weekday: 3,
        sessions: [3, 4],
        weeks: List.generate(16, (i) => i + 1),
        campus: '中心校区',
        place: '敬知楼502',
        colorIndex: 8,
      ),
      Course(
        title: '区块链技术与应用',
        teacher: '马静宇',
        weekday: 3,
        sessions: [12, 13],
        weeks: List.generate(16, (i) => i + 1),
        campus: '东校区',
        place: '求真307',
        colorIndex: 9,
      ),
      Course(
        title: '数学分析（Ⅲ）',
        teacher: '李佳',
        weekday: 4,
        sessions: [1, 2],
        weeks: List.generate(16, (i) => i + 1),
        campus: '中心校区',
        place: '敬本C401',
        colorIndex: 3,
      ),
      Course(
        title: '概率统计',
        teacher: '胡江',
        weekday: 4,
        sessions: [3, 4],
        weeks: List.generate(14, (i) => i + 1),
        campus: '中心校区',
        place: '敬业F310',
        colorIndex: 0,
      ),
      Course(
        title: '大学物理实验B',
        teacher: '郭星导',
        weekday: 4,
        sessions: [7, 8],
        weeks: List.generate(16, (i) => i + 1),
        campus: '中心校区',
        place: '大学物理实验室4',
        colorIndex: 10,
      ),
      Course(
        title: '离散数学',
        teacher: '张克军',
        weekday: 5,
        sessions: [1, 2],
        weeks: [9, 10, 11, 12, 13, 14, 15, 16],
        campus: '中心校区',
        place: '敬业F310',
        colorIndex: 4,
      ),
      Course(
        title: '中国近现代史纲要',
        teacher: '王娟',
        weekday: 5,
        sessions: [3, 4],
        weeks: List.generate(16, (i) => i + 1),
        campus: '中心校区',
        place: '敬业F310',
        colorIndex: 6,
      ),
      Course(
        title: 'Java程序设计',
        teacher: '梁传威',
        weekday: 5,
        sessions: [7, 8],
        weeks: [9, 10, 11, 12, 13, 14, 15, 16],
        campus: '中心校区',
        place: '敬知楼511',
        colorIndex: 7,
      ),
    ];
    final backgroundPath = settings.timetableBackgroundPath;
    return ClipRect(
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
          TimetableGrid(
            courses: previewCourses,
            week: 1,
            showWeekendColumns: showWeekendColumns,
            calendar: semesterCalendar,
            slotCount: 14,
            visibleSlots: 4,
            borderColor: theme.colors.foreground,
            borderWidth: 0.5,
            courseOpacity: settings.timetableCourseAlpha,
            courseBorderOpacity: 1.0,
            courseTextSize: settings.timetableCourseTextSize,
            timeTextSize: settings.timetableTimeTextSize,
            dateTextSize: settings.timetableDateTextSize,
            gridOpacity: settings.timetableGridOpacity,
            showHeaderDivider: backgroundPath == null || backgroundPath.isEmpty,
            showTodayGridLines: settings.showTodayGridLines,
            showGridLines: settings.showTimetableGridLines,
            sectionHeight: settings.timetableSectionHeight,
            timeColumnWidth: settings.timetableTimeColumnWidth,
            dayHeaderHeight: settings.timetableDayHeaderHeight,
            courseCornerRadius: settings.timetableCourseCornerRadius,
            courseInnerPadding: settings.timetableCourseInnerPadding,
            courseOuterPadding: settings.timetableCourseOuterPadding,
            courseFontScale: settings.timetableCourseFontScale,
            hideSectionTime: settings.timetableHideSectionTime,
            hideDateUnderDay: settings.timetableHideDateUnderDay,
            showStartTime: settings.timetableShowStartTime,
            hideLocation: settings.timetableHideLocation,
            hideTeacher: settings.timetableHideTeacher,
            removeLocationAt: settings.timetableRemoveLocationAt,
            textAlignCenterHorizontal:
                settings.timetableTextAlignCenterHorizontal,
            textAlignCenterVertical: settings.timetableTextAlignCenterVertical,
            borderType: settings.timetableBorderType.storageValue,
            pageTextColor: settings.timetablePageTextColor,
            courseTextColor: settings.timetableCourseTextColor,
          ),
        ],
      ),
    );
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
