import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../models/course.dart';
import '../../models/school_calendar.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../ui/app_components.dart';
import 'profile_components.dart';

class CourseRulesSettingsPage extends ConsumerStatefulWidget {
  const CourseRulesSettingsPage({super.key});

  @override
  ConsumerState<CourseRulesSettingsPage> createState() =>
      _CourseRulesSettingsPageState();
}

class _CourseRulesSettingsPageState
    extends ConsumerState<CourseRulesSettingsPage> {
  bool _localExpanded = false;
  bool _cloudExpanded = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final courses = ref.watch(scheduleProvider).value;
    final original = ref.read(scheduleProvider.notifier).originalCourses;
    final adjustments = _buildAdjustmentRules(courses, original);
    final cloudAdjustments = _cloudAdjustments;
    final hasLocalRules = original.isNotEmpty && adjustments.isNotEmpty;

    return AppPage(
      title: '课程规则',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          const ProfileSectionLabel(title: '本地规则'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsExpandableTile(
                icon: FLucideIcons.history,
                title: '本地课程规则',
                value: original.isEmpty
                    ? '暂无基线'
                    : adjustments.isEmpty
                    ? '无变动'
                    : '${adjustments.length} 条规则',
                expanded: hasLocalRules && _localExpanded,
                expandable: hasLocalRules,
                onTap: () => setState(() => _localExpanded = !_localExpanded),
                child: _buildAdjustmentDetails(
                  adjustments,
                  hasOriginalBaseline: original.isNotEmpty,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '云端规则'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.cloud,
                title: '启用云端课程规则',
                value: settings.useCloudTimetableAdjustments,
                onChange: _setCloudAdjustmentsEnabled,
              ),
              ProfileSettingsExpandableTile(
                icon: FLucideIcons.cloud,
                title: '云端课程规则',
                value: '${cloudAdjustments.length} 条规则',
                expanded: cloudAdjustments.isNotEmpty && _cloudExpanded,
                expandable: cloudAdjustments.isNotEmpty,
                onTap: () => setState(() => _cloudExpanded = !_cloudExpanded),
                child: _buildCloudRuleDetails(cloudAdjustments),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const ProfileSettingsHint('课程规则会直接作用于课表数据，小组件和课堂提醒会随课表同步更新。'),
        ],
      ),
    );
  }

  List<_CourseAdjustment> _buildAdjustmentRules(
    List<Course>? courses,
    List<Course> original,
  ) {
    final current = courses ?? const <Course>[];
    if (original.isEmpty && current.isEmpty) return const [];
    final maxWeek = <int>[
      semesterCalendar.totalWeeks,
      ...current.expand((course) => course.weeks),
      ...original.expand((course) => course.weeks),
    ].fold<int>(1, (maximum, value) => value > maximum ? value : maximum);
    final snapshots = <String, _CourseDaySnapshot>{};
    for (var week = 1; week <= maxWeek; week++) {
      final dates = semesterCalendar.weekDates(week);
      for (var weekday = 1; weekday <= 7; weekday++) {
        final date = dates[weekday - 1];
        snapshots[_dateKey(date)] = _CourseDaySnapshot(
          date: date,
          originalCourses: _coursesForDay(original, weekday, week),
          currentCourses: _coursesForDay(current, weekday, week),
        );
      }
    }

    final rules = <_CourseAdjustment>[];
    final movedSources = <String>{};
    final cloudSources = {
      for (final day in semesterCalendar.days)
        if (day.adjustment != '/' && day.adjustment.isNotEmpty)
          _dateKey(day.date): day.adjustment,
    };
    for (final target in snapshots.values) {
      final currentSignature = _courseSignatures(target.currentCourses)
          .join('\u001e');
      if (currentSignature.isEmpty ||
          currentSignature ==
              _courseSignatures(target.originalCourses).join('\u001e')) {
        continue;
      }
      final preferredSourceDate = _parseDateKey(
        cloudSources[_dateKey(target.date)] ?? '',
      );
      final preferredSource = preferredSourceDate == null
          ? null
          : snapshots[_dateKey(preferredSourceDate)];
      final candidates = snapshots.values.where((source) {
        if (source.date == target.date || source.originalCourses.isEmpty) {
          return false;
        }
        return _courseSignatures(source.originalCourses).join('\u001e') ==
            currentSignature;
      }).toList();
      final source =
          preferredSource != null &&
              _courseSignatures(preferredSource.originalCourses)
                      .join('\u001e') ==
                  currentSignature
          ? preferredSource
          : candidates.length == 1
          ? candidates.single
          : null;
      if (source != null) {
        rules.add(
          _CourseAdjustment(
            sourceDate: source.date,
            operation: '移动至',
            targetDate: target.date,
          ),
        );
        if (source.currentCourses.isEmpty) {
          movedSources.add(_dateKey(source.date));
        }
      } else {
        rules.add(_CourseAdjustment(sourceDate: target.date, operation: '调整'));
      }
    }
    for (final day in snapshots.values) {
      if (day.originalCourses.isEmpty ||
          day.currentCourses.isNotEmpty ||
          movedSources.contains(_dateKey(day.date))) {
        continue;
      }
      rules.add(_CourseAdjustment(sourceDate: day.date, operation: '清空'));
    }
    rules.sort((left, right) => left.sourceDate.compareTo(right.sourceDate));
    return rules;
  }

  List<SchoolDay> get _cloudAdjustments =>
      semesterCalendar.days.where((day) => day.adjustment.isNotEmpty).toList();

  Future<void> _setCloudAdjustmentsEnabled(bool enabled) async {
    await ref
        .read(appSettingsProvider.notifier)
        .setUseCloudTimetableAdjustments(enabled);
    if (enabled && mounted) {
      await ref.read(scheduleProvider.notifier).applyCloudAdjustments();
    }
  }

  List<Course> _coursesForDay(List<Course> courses, int weekday, int week) =>
      [
        for (final course in courses)
          if (course.weekday == weekday && course.weeks.contains(week)) course,
      ]..sort((left, right) {
        final session = left.startSession.compareTo(right.startSession);
        return session != 0 ? session : left.title.compareTo(right.title);
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
    List<_CourseAdjustment> adjustments, {
    required bool hasOriginalBaseline,
  }) {
    if (!hasOriginalBaseline || adjustments.isEmpty) {
      return const SizedBox.shrink();
    }
    return _buildRows(adjustments);
  }

  Widget _buildCloudRuleDetails(List<SchoolDay> days) {
    final rows = <_CourseAdjustment>[];
    for (final day in days) {
      final value = day.adjustment;
      if (value == '/') {
        rows.add(_CourseAdjustment(sourceDate: day.date, operation: '清空'));
      } else {
        final source = _parseDateKey(value);
        if (source != null) {
          rows.add(
            _CourseAdjustment(
              sourceDate: day.date,
              operation: '按照',
              targetDate: source,
            ),
          );
        }
      }
    }
    rows.sort((left, right) => left.sourceDate.compareTo(right.sourceDate));
    return rows.isEmpty ? const SizedBox.shrink() : _buildRows(rows);
  }

  Widget _buildRows(List<_CourseAdjustment> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < rows.length; index++) ...[
        if (index > 0)
          Divider(height: AppSpacing.lg, color: context.theme.colors.border),
        _buildAdjustmentRow(rows[index]),
      ],
    ],
  );

  Widget _buildAdjustmentRow(_CourseAdjustment adjustment) => Row(
    children: [
      Expanded(child: _dateOperationLabel(adjustment.sourceDate)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(
          adjustment.operation,
          style: context.theme.typography.caption.copyWith(
            color: adjustment.operation == '清空'
                ? context.theme.colors.destructive
                : context.theme.colors.primary,
          ),
        ),
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

  Widget _dateOperationLabel(DateTime date) => Text(
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    style: context.theme.typography.bodySmall.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  DateTime? _parseDateKey(String value) {
    if (!RegExp(r'^\d{8}$').hasMatch(value)) return null;
    final date = DateTime(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(4, 6)),
      int.parse(value.substring(6, 8)),
    );
    return _dateKey(date) == value ? date : null;
  }
}

class _CourseAdjustment {
  final DateTime sourceDate;
  final String operation;
  final DateTime? targetDate;

  const _CourseAdjustment({
    required this.sourceDate,
    required this.operation,
    this.targetDate,
  });
}

class _CourseDaySnapshot {
  final DateTime date;
  final List<Course> originalCourses;
  final List<Course> currentCourses;

  const _CourseDaySnapshot({
    required this.date,
    required this.originalCourses,
    required this.currentCourses,
  });
}
