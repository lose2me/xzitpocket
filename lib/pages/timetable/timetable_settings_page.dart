import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/native_automation_service.dart';
import '../../services/talker.dart';
import '../../utils/course_adjustments.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';
import '../profile/profile_components.dart';
import 'timetable_providers.dart';

class TimetableSettingsPage extends ConsumerStatefulWidget {
  const TimetableSettingsPage({super.key});

  @override
  ConsumerState<TimetableSettingsPage> createState() =>
      _TimetableSettingsPageState();
}

class _TimetableSettingsPageState extends ConsumerState<TimetableSettingsPage> {
  final _imagePicker = ImagePicker();
  late final TextEditingController _courseAdjustmentsController;
  bool _cloudJsonExpanded = false;
  bool _localJsonExpanded = false;

  @override
  void initState() {
    super.initState();
    _courseAdjustmentsController = TextEditingController(
      text: courseAdjustmentsToJson(
        parseCourseAdjustments(
          ref.read(appSettingsProvider).courseAdjustmentsJson,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _courseAdjustmentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final showNonCurrentWeekCourses = ref.watch(
      showNonCurrentWeekCoursesProvider,
    );
    final showWeekendColumns = ref.watch(showWeekendColumnsProvider);

    return AppPage(
      title: '课表设置',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          const ProfileSectionLabel(title: '课程调整'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.cloud,
                title: '启用云端课程调整',
                value: settings.cloudCourseAdjustmentsEnabled,
                onChange: (value) => ref
                    .read(appSettingsProvider.notifier)
                    .setCloudCourseAdjustmentsEnabled(value),
              ),
              ProfileSettingsExpandableTile(
                icon: FLucideIcons.cloud,
                title: '云端课程调整 JSON',
                value: _adjustmentSummary(settings.cloudCourseAdjustmentsJson),
                expanded: _cloudJsonExpanded,
                child: _cloudAdjustmentJson(
                  settings.cloudCourseAdjustmentsJson,
                ),
                onTap: () =>
                    setState(() => _cloudJsonExpanded = !_cloudJsonExpanded),
              ),
              ProfileSettingsExpandableTile(
                icon: FLucideIcons.fileText,
                title: '本地课程调整 JSON',
                value: _adjustmentSummary(settings.courseAdjustmentsJson),
                expanded: _localJsonExpanded,
                child: _localAdjustmentEditor(),
                onTap: () =>
                    setState(() => _localJsonExpanded = !_localJsonExpanded),
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
          const ProfileSectionLabel(title: '背景图'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.image,
                title: '课表背景图',
                value: settings.timetableBackgroundPath == null ? '未设置' : '已设置',
                onTap: _pickBackground,
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
        ],
      ),
    );
  }

  String _adjustmentSummary(String source) {
    final count = parseCourseAdjustments(source).length;
    return count == 0 ? '未设置' : '$count 条规则';
  }

  Widget _cloudAdjustmentJson(String source) {
    final formatted = courseAdjustmentsToJson(parseCourseAdjustments(source));
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(formatted),
      ),
    );
  }

  Widget _localAdjustmentEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _courseAdjustmentsController,
        minLines: 8,
        maxLines: 16,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: '{"20260916": "20260917"}',
          helperText: '查看云端JSON照葫芦画瓢',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Align(
        alignment: Alignment.centerRight,
        child: FButton(
          onPress: _saveCourseAdjustments,
          prefix: const Icon(FLucideIcons.save),
          child: const Text('保存本地配置'),
        ),
      ),
    ],
  );

  Future<void> _saveCourseAdjustments() async {
    final source = _courseAdjustmentsController.text;
    final parsed = parseCourseAdjustments(source);
    // Reject non-empty input that did not contain any valid mapping instead
    // of silently losing a typo in the local configuration.
    if (source.trim().isNotEmpty && source.trim() != '{}' && parsed.isEmpty) {
      showAppSnackBar(context, '课程调整 JSON 格式无效', severity: ToastSeverity.error);
      return;
    }
    final normalized = courseAdjustmentsToJson(parsed);
    await ref
        .read(appSettingsProvider.notifier)
        .setCourseAdjustmentsJson(normalized);
    _courseAdjustmentsController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    if (mounted) {
      showAppSnackBar(
        context,
        '本地课程调整已保存，下次同步课表时生效',
        severity: ToastSeverity.success,
      );
    }
  }

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
    if (selected == null || selected == currentMode) return;
    await ref
        .read(appSettingsProvider.notifier)
        .setClassAutomationMode(selected);
    if (!mounted || selected == ClassAutomationMode.off) return;
    final status = await NativeAutomationService.getPermissionStatus();
    if (!mounted || status.isFullyGranted) return;
    final missing = <String>[];
    if (!status.hasDndPermission) missing.add('勿扰');
    if (!status.hasExactAlarmPermission) missing.add('精确闹钟');
    showAppSnackBar(
      context,
      '需要开启${missing.join('和')}权限',
      severity: ToastSeverity.warning,
    );
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

  Future<void> _pickBackground() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null || !mounted) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final extension = p.extension(picked.path).isEmpty
          ? '.jpg'
          : p.extension(picked.path);
      final targetPath = p.join(
        directory.path,
        'timetable_background_${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      await picked.saveTo(targetPath);
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
}
