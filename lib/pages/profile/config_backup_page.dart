import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../models/course.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/secondary_schedule_provider.dart';
import '../../services/course_backup.dart';
import '../../services/preferences_storage.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';

/// Clipboard backups for personalization and the two independent timetables.
class ConfigBackupPage extends ConsumerStatefulWidget {
  const ConfigBackupPage({super.key});

  @override
  ConsumerState<ConfigBackupPage> createState() => _ConfigBackupPageState();
}

class _ConfigBackupPageState extends ConsumerState<ConfigBackupPage> {
  final _settingsController = TextEditingController();
  final _coursesController = TextEditingController();
  final _secondaryCoursesController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshSettingsExport();
      _refreshCoursesExport(secondary: false);
      _refreshCoursesExport(secondary: true);
    });
  }

  @override
  void dispose() {
    _settingsController.dispose();
    _coursesController.dispose();
    _secondaryCoursesController.dispose();
    super.dispose();
  }

  PreferencesStorage get _storage => ref.read(preferencesStorageProvider);

  void _refreshSettingsExport() {
    _settingsController.text = jsonEncode({
      'type': 'xzitpocket_personalization',
      'version': 1,
      'settings': _storage.getPersonalizationSnapshot(),
    });
  }

  void _refreshCoursesExport({required bool secondary}) {
    final courses = secondary
        ? ref.read(secondaryScheduleProvider).courses
        : ref.read(scheduleProvider).value ?? const <Course>[];
    final controller = secondary
        ? _secondaryCoursesController
        : _coursesController;
    controller.text = jsonEncode(courseBackup(courses: courses));
  }

  Future<void> _copy(TextEditingController controller) async {
    await Clipboard.setData(ClipboardData(text: controller.text));
    if (mounted) showAppSnackBar(context, 'JSON 已复制');
  }

  Map<String, dynamic> _parseSettings(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('个性化设置必须是 JSON 对象');
    if (decoded.containsKey('type') &&
        (decoded['type'] != 'xzitpocket_personalization' ||
            decoded['version'] != 1)) {
      throw const FormatException('请选择个性化设置 JSON');
    }
    final raw = decoded['settings'] ?? decoded;
    if (raw is! Map) throw const FormatException('找不到 settings 对象');
    return Map<String, dynamic>.from(raw);
  }

  Future<void> _importSettings() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final settings = _parseSettings(_settingsController.text.trim());
      await _storage.restorePersonalizationSnapshot(settings);
      ref.invalidate(appSettingsProvider);
      if (mounted) {
        _refreshSettingsExport();
        showAppSnackBar(context, '个性化设置已导入', severity: ToastSeverity.success);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, '导入失败：$error', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importCourses({required bool secondary}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final controller = secondary
          ? _secondaryCoursesController
          : _coursesController;
      final courses = parseCourseBackup(controller.text.trim());
      if (secondary) {
        await ref.read(secondaryScheduleProvider.notifier).setCourses(courses);
      } else {
        final confirmed = await showAppConfirmDialog(
          context: context,
          title: '导入主课表',
          message: '导入会替换当前主课表，并同步小组件和课程提醒。确定继续吗？',
          confirmLabel: '替换',
        );
        if (!confirmed || !mounted) return;
        await ref.read(scheduleProvider.notifier).replaceCourses(courses);
      }
      if (mounted) {
        _refreshCoursesExport(secondary: secondary);
        showAppSnackBar(
          context,
          secondary ? '已导入备用课表（${courses.length} 门课程）' : '主课表已导入',
          severity: ToastSeverity.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, '导入失败：$error', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _jsonSection({
    required String title,
    required String fieldKey,
    required TextEditingController controller,
    required VoidCallback onImport,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: context.theme.typography.tileTitle),
      const SizedBox(height: AppSpacing.sm),
      AppTextField(
        key: ValueKey(fieldKey),
        controller: controller,
        enabled: !_busy,
        keyboardType: TextInputType.multiline,
        minLines: 1,
        maxLines: 1,
        size: FTextFieldSizeVariant.sm,
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: FButton(
              variant: FButtonVariant.outline,
              prefix: const Icon(FLucideIcons.copy),
              onPress: _busy ? null : () => _copy(controller),
              child: const Text('复制'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FButton(
              variant: FButtonVariant.outline,
              prefix: const Icon(FLucideIcons.clipboardPaste),
              onPress: _busy ? null : onImport,
              child: const Text('导入'),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AppPage(
    title: '配置备份',
    child: AppPageBody(
      maxWidth: AppLayout.contentMaxWidth,
      child: FTabs(
        expands: true,
        style: appSegmentedTabsStyle(context.theme),
        children: [
          FTabEntry(
            label: const Text('个性化配置'),
            child: AppPageListView(
              maxWidth: AppLayout.resultMaxWidth,
              safeArea: false,
              topPadding: AppSpacing.lg,
              bottomPadding: AppSpacing.xxl,
              children: [
                _jsonSection(
                  title: '个性化设置 JSON',
                  fieldKey: 'backup_settings_json',
                  controller: _settingsController,
                  onImport: _importSettings,
                ),
              ],
            ),
          ),
          FTabEntry(
            label: const Text('课表'),
            child: AppPageListView(
              maxWidth: AppLayout.resultMaxWidth,
              safeArea: false,
              topPadding: AppSpacing.lg,
              bottomPadding: AppSpacing.xxl,
              children: [
                _jsonSection(
                  title: '当前课程 JSON',
                  fieldKey: 'backup_primary_courses_json',
                  controller: _coursesController,
                  onImport: () => _importCourses(secondary: false),
                ),
                const SizedBox(height: AppSpacing.xl),
                _jsonSection(
                  title: '备用课程 JSON',
                  fieldKey: 'backup_secondary_courses_json',
                  controller: _secondaryCoursesController,
                  onImport: () => _importCourses(secondary: true),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
