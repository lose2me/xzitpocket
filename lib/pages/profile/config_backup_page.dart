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
import '../../services/control_service.dart';
import '../../services/course_backup.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';

/// Shares all local timetable and personalization settings through a short-lived code.
class ConfigBackupPage extends ConsumerStatefulWidget {
  const ConfigBackupPage({super.key});

  @override
  ConsumerState<ConfigBackupPage> createState() => _ConfigBackupPageState();
}

class _ConfigBackupPageState extends ConsumerState<ConfigBackupPage> {
  final _importController = TextEditingController();
  final _generatedController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _importController.dispose();
    _generatedController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _exportData() {
    final primary = ref.read(scheduleProvider).value ?? const <Course>[];
    final secondary = ref.read(secondaryScheduleProvider);
    return {
      'version': 1,
      'settings': ref
          .read(preferencesStorageProvider)
          .getPersonalizationSnapshot(),
      'primaryCourses': courseBackup(courses: primary),
      'secondaryCourses': courseBackup(courses: secondary.courses),
      'secondaryTitle': secondary.title,
    };
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final code = await ControlService.instance.createShareCode(_exportData());
      if (!mounted) return;
      setState(() => _generatedController.text = code);
      showAppSnackBar(
        context,
        '分享码已生成，有效期 7 天',
        severity: ToastSeverity.success,
      );
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, '生成失败：$error', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    final code = _importController.text.trim();
    if (code.isEmpty) {
      showAppSnackBar(context, '请输入分享码', severity: ToastSeverity.warning);
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await ControlService.instance.fetchShareCode(code);
      final settings = data['settings'];
      if (settings is! Map) throw const FormatException('个性化设置格式无效');
      final primary = _coursesFrom(data['primaryCourses'], '主课表');
      final secondary = _coursesFrom(data['secondaryCourses'], '备用课表');
      await ref
          .read(preferencesStorageProvider)
          .restorePersonalizationSnapshot(Map<String, dynamic>.from(settings));
      ref.invalidate(appSettingsProvider);
      await ref.read(scheduleProvider.notifier).replaceCourses(primary);
      if (secondary.isEmpty) {
        await ref.read(secondaryScheduleProvider.notifier).clear();
      } else {
        await ref
            .read(secondaryScheduleProvider.notifier)
            .setCourses(secondary);
      }
      await ref
          .read(secondaryScheduleProvider.notifier)
          .setTitle(
            data['secondaryTitle']?.toString() ?? defaultSecondaryScheduleTitle,
          );
      if (mounted) {
        _importController.clear();
        showAppSnackBar(context, '配置已导入', severity: ToastSeverity.success);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, '导入失败：$error', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Course> _coursesFrom(Object? value, String label) {
    if (value is! Map) throw FormatException('$label数据格式无效');
    try {
      return parseCourseBackup(jsonEncode(value));
    } catch (error) {
      throw FormatException('$label数据格式无效：$error');
    }
  }

  Future<void> _copyGenerated() async {
    if (_generatedController.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _generatedController.text));
    if (mounted) showAppSnackBar(context, '分享码已复制');
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: '分享码',
    child: AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      children: [
        Text('分享码', style: context.theme.typography.pageTitle),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '分享码包含个性化设置、主课表和备用课表，有效期 7 天。',
          style: context.theme.typography.bodySmall.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          key: const ValueKey('config_backup_import_code'),
          controller: _importController,
          label: '输入分享码',
          hint: '六位字母和数字',
          enabled: !_busy,
          textCapitalization: TextCapitalization.characters,
          suffix: AppIconButton(
            icon: FLucideIcons.download,
            onPress: _busy ? null : _import,
            tooltip: '导入分享码',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FButton(
            onPress: _busy ? null : _import,
            prefix: const Icon(FLucideIcons.download),
            child: const Text('导入配置'),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppTextField(
          key: const ValueKey('config_backup_generated_code'),
          controller: _generatedController,
          label: '生成的分享码',
          readOnly: true,
          suffix: AppIconButton(
            icon: FLucideIcons.copy,
            onPress: _generatedController.text.isEmpty ? null : _copyGenerated,
            tooltip: '复制分享码',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: _busy ? null : _generate,
            prefix: const Icon(FLucideIcons.plus),
            child: const Text('生成分享码'),
          ),
        ),
      ],
    ),
  );
}
