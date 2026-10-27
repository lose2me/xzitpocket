import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
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
import '../../utils/error_message.dart';
import '../../utils/snackbar_helper.dart';

class ConfigBackupPage extends ConsumerStatefulWidget {
  const ConfigBackupPage({super.key});

  @override
  ConsumerState<ConfigBackupPage> createState() => _ConfigBackupPageState();
}

/// 分享码只接受大写字母和数字，小写会自动转成大写。
class _ShareCodeFormatter extends TextInputFormatter {
  const _ShareCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = StringBuffer();
    for (final rune in newValue.text.toUpperCase().runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[A-Z0-9]').hasMatch(char)) filtered.write(char);
    }
    final text = filtered.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ConfigBackupPageState extends ConsumerState<ConfigBackupPage> {
  static const _personalizationSuffix = '2';
  static const _scheduleSuffix = '1';
  final _personalizationController = FOtpController(children: appOtpChildren());
  final _scheduleController = FOtpController(children: appOtpChildren());
  late final TextEditingController _secondaryNameController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _secondaryNameController = TextEditingController(
      text: ref.read(secondaryScheduleProvider).title,
    );
  }

  @override
  void dispose() {
    _personalizationController.dispose();
    _scheduleController.dispose();
    _secondaryNameController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _personalizationData() => {
    'version': 1,
    'settings': ref
        .read(preferencesStorageProvider)
        .getPersonalizationSnapshot(),
  };

  Map<String, dynamic> _scheduleData() {
    final courses = ref.read(scheduleProvider).value ?? const <Course>[];
    return courseBackup(courses: courses);
  }

  Future<void> _generate({required String suffix}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final code = await ControlService.instance.createShareCode(
        suffix: suffix,
        data: suffix == _personalizationSuffix
            ? _personalizationData()
            : _scheduleData(),
      );
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      setState(() {
        if (suffix == _personalizationSuffix) {
          _personalizationController.text = code;
        } else {
          _scheduleController.text = code;
        }
      });
      showAppSnackBar(context, '分享码已生成并复制', severity: ToastSeverity.success);
      unawaited(
        ControlService.instance.track(
          'share_code',
          properties: const {'source': 'create'},
        ),
      );
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          '生成失败：${describeError(error)}',
          severity: ToastSeverity.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import({required String suffix}) async {
    if (_busy) return;
    final controller = suffix == _personalizationSuffix
        ? _personalizationController
        : _scheduleController;
    final code = controller.text.trim();
    if (code.isEmpty) {
      showAppSnackBar(context, '请输入分享码', severity: ToastSeverity.warning);
      return;
    }
    setState(() => _busy = true);
    try {
      final payload = await ControlService.instance.fetchShareCode(code);
      final normalizedCode = code.toUpperCase();
      if (normalizedCode.length != 6 || normalizedCode[5] != suffix) {
        throw FormatException(
          suffix == _personalizationSuffix
              ? '此分享码为课表数据，请改用第二课表导入'
              : '此分享码为个性化设置，请改用个性化设置导入',
        );
      }
      if (suffix == _personalizationSuffix) {
        if (payload['version'] != 1) {
          throw const FormatException('个性化设置版本无效');
        }
        final settings = payload['settings'];
        if (settings is! Map) throw const FormatException('个性化设置格式无效');
        await ref
            .read(preferencesStorageProvider)
            .restorePersonalizationSnapshot(
              Map<String, dynamic>.from(settings),
            );
        ref.invalidate(appSettingsProvider);
      } else {
        final courses = _coursesFrom(payload);
        await ref.read(secondaryScheduleProvider.notifier).setCourses(courses);
      }
      if (mounted) {
        controller.clear();
        showAppSnackBar(context, '配置已导入', severity: ToastSeverity.success);
      }
      unawaited(
        ControlService.instance.track(
          'share_code',
          properties: const {'source': 'import'},
        ),
      );
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          describeError(error),
          severity: ToastSeverity.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Course> _coursesFrom(Map<String, dynamic> value) {
    try {
      return parseCourseBackup(jsonEncode(value));
    } catch (error) {
      throw FormatException('第二课表数据格式无效：${describeError(error)}');
    }
  }

  Future<void> _clearSecondary() async {
    if (_busy) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '清空第二课表？',
      message: '第二课表将被删除，无法恢复。',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(secondaryScheduleProvider.notifier).clear();
      if (mounted) {
        _secondaryNameController.text = ref
            .read(secondaryScheduleProvider)
            .title;
        showAppSnackBar(context, '第二课表已清空', severity: ToastSeverity.success);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section({
    required String title,
    required Key fieldKey,
    required FOtpController controller,
    required VoidCallback? onExport,
    required VoidCallback? onImport,
    Widget? footer,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: context.theme.typography.tileTitle),
      const SizedBox(height: AppSpacing.md),
      // 分享码固定六位，用格子式输入，避免手输空格/小写。
      Center(
        child: FOtpField(
          key: fieldKey,
          control: FOtpFieldControl.managed(controller: controller),
          enabled: !_busy,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.characters,
          style: appOtpFieldStyle,
          inputFormatters: const [_ShareCodeFormatter()],
          onSubmit: (_) => onImport?.call(),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: onExport,
              prefix: const Icon(FLucideIcons.share2),
              child: const Text('生成'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FButton(
              onPress: onImport,
              prefix: const Icon(FLucideIcons.download),
              child: const Text('导入'),
            ),
          ),
        ],
      ),
      if (footer != null) ...[const SizedBox(height: AppSpacing.md), footer],
    ],
  );

  @override
  Widget build(BuildContext context) => AppPage(
    title: '分享码',
    child: AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      children: [
        _section(
          title: '个性化设置',
          fieldKey: const ValueKey('config_backup_personalization_code'),
          controller: _personalizationController,
          onExport: _busy
              ? null
              : () => _generate(suffix: _personalizationSuffix),
          onImport: _busy
              ? null
              : () => _import(suffix: _personalizationSuffix),
        ),
        const SizedBox(height: AppSpacing.xl),
        _section(
          title: '第二课表',
          fieldKey: const ValueKey('config_backup_schedule_code'),
          controller: _scheduleController,
          onExport: _busy ? null : () => _generate(suffix: _scheduleSuffix),
          onImport: _busy ? null : () => _import(suffix: _scheduleSuffix),
          footer: AppTextField(
            controller: _secondaryNameController,
            label: '第二课表名称',
            enabled: !_busy,
            inputFormatters: [LengthLimitingTextInputFormatter(12)],
            onChanged: (value) => unawaited(
              ref.read(secondaryScheduleProvider.notifier).setTitle(value),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FButton(
          variant: FButtonVariant.destructive,
          onPress: _busy ? null : _clearSecondary,
          prefix: const Icon(FLucideIcons.trash2),
          child: const Text('清空第二课表'),
        ),
      ],
    ),
  );
}
