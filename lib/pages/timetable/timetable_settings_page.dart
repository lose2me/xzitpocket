import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/native_automation_service.dart';
import '../../utils/snackbar_helper.dart';

class TimetableSettingsPage extends ConsumerStatefulWidget {
  const TimetableSettingsPage({super.key});

  @override
  ConsumerState<TimetableSettingsPage> createState() =>
      _TimetableSettingsPageState();
}

class _TimetableSettingsPageState
    extends ConsumerState<TimetableSettingsPage>
    with WidgetsBindingObserver {
  AutomationPermissionStatus? _permissionStatus;
  bool _isLoadingPermissions = true;
  late ClassAutomationMode _previewAutomationMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialMode = ref.read(appSettingsProvider).classAutomationMode;
    _previewAutomationMode = initialMode == ClassAutomationMode.off
        ? ClassAutomationMode.dnd
        : initialMode;
    _loadPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPermissions(resyncAutomation: true);
    }
  }

  Future<void> _loadPermissions({bool resyncAutomation = false}) async {
    final status = await NativeAutomationService.getPermissionStatus();
    if (!mounted) return;

    setState(() {
      _permissionStatus = status;
      _isLoadingPermissions = false;
    });

    if (resyncAutomation &&
        ref.read(appSettingsProvider).classAutomationMode !=
            ClassAutomationMode.off) {
      await NativeAutomationService.refreshClassAutomation();
    }
  }

  Future<void> _updateTheme(AppThemePreference preference) async {
    await ref.read(appSettingsProvider.notifier).setThemePreference(preference);
  }

  Future<void> _updateAutomationMode(ClassAutomationMode mode) async {
    if (mode != ClassAutomationMode.off) {
      setState(() {
        _previewAutomationMode = mode;
      });
    }
    await ref.read(appSettingsProvider.notifier).setClassAutomationMode(mode);
    await _loadPermissions();

    if (!mounted) return;
    final status = _permissionStatus;
    if (mode != ClassAutomationMode.off &&
        status != null &&
        !status.isFullyGranted) {
      showAppSnackBar(context, '还需要开启相关权限后才能按时生效');
    }
  }

  void _updateShowNonCurrentWeekCourses(bool value) {
    ref.read(showNonCurrentWeekCoursesProvider.notifier).state = value;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final showNonCurrentWeekCourses = ref.watch(showNonCurrentWeekCoursesProvider);
    final permissionStatus = _permissionStatus;
    final isAutomationEnabled =
        settings.classAutomationMode != ClassAutomationMode.off;
    final selectedAutomationMode = isAutomationEnabled
        ? settings.classAutomationMode
        : _previewAutomationMode;

    return Scaffold(
      appBar: AppBar(title: const Text('课表设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_isLoadingPermissions)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (permissionStatus != null)
            _PermissionCard(
              permissionStatus: permissionStatus,
              onOpenDndSettings: NativeAutomationService.openDndSettings,
              onOpenExactAlarmSettings:
                  NativeAutomationService.openExactAlarmSettings,
            ),
          const SizedBox(height: 20),
          _SectionSwitchHeader(
            title: '课堂勿扰模式',
            value: isAutomationEnabled,
            onChanged: (value) {
              _updateAutomationMode(
                value ? _previewAutomationMode : ClassAutomationMode.off,
              );
            },
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isAutomationEnabled ? 1 : 0.52,
            child: IgnorePointer(
              ignoring: !isAutomationEnabled,
              child: RadioGroup<ClassAutomationMode>(
                groupValue: selectedAutomationMode,
                onChanged: (value) {
                  if (value != null) {
                    _updateAutomationMode(value);
                  }
                },
                child: Column(
                  children: ClassAutomationMode.values
                      .where((mode) => mode != ClassAutomationMode.off)
                      .map(
                        (mode) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SelectionCard<ClassAutomationMode>(
                            value: mode,
                            title: _automationTitle(mode),
                            leadingIcon: _automationIcon(mode),
                            selected: selectedAutomationMode == mode,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionSwitchHeader(
            title: '显示非本周课程',
            value: showNonCurrentWeekCourses,
            onChanged: _updateShowNonCurrentWeekCourses,
          ),
          const SizedBox(height: 20),
          const _SectionHeader(
            title: '主题模式',
          ),
          const SizedBox(height: 10),
          RadioGroup<AppThemePreference>(
            groupValue: settings.themePreference,
            onChanged: (value) {
              if (value != null) {
                _updateTheme(value);
              }
            },
            child: Column(
              children: AppThemePreference.values
                  .map(
                    (preference) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SelectionCard<AppThemePreference>(
                        value: preference,
                        title: _themeTitle(preference),
                        leadingIcon: _themeIcon(preference),
                        selected: settings.themePreference == preference,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _automationTitle(ClassAutomationMode mode) {
    return switch (mode) {
      ClassAutomationMode.off => '关闭',
      ClassAutomationMode.dnd => '上课时开启免打扰，下课恢复',
      ClassAutomationMode.dndKeep => '上课时开启免打扰，下课不恢复',
    };
  }

  IconData _automationIcon(ClassAutomationMode mode) {
    return switch (mode) {
      ClassAutomationMode.off => Icons.remove_circle_outline,
      ClassAutomationMode.dnd => Icons.do_not_disturb_on_outlined,
      ClassAutomationMode.dndKeep => Icons.do_not_disturb_alt_outlined,
    };
  }

  String _themeTitle(AppThemePreference preference) {
    return switch (preference) {
      AppThemePreference.system => '跟随系统',
      AppThemePreference.light => '浅色主题',
      AppThemePreference.dark => '暗黑主题',
    };
  }

  IconData _themeIcon(AppThemePreference preference) {
    return switch (preference) {
      AppThemePreference.system => Icons.brightness_auto,
      AppThemePreference.light => Icons.light_mode_outlined,
      AppThemePreference.dark => Icons.dark_mode_outlined,
    };
  }
}

class _SectionSwitchHeader extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SectionSwitchHeader({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SelectionCard<T> extends StatelessWidget {
  final T value;
  final String title;
  final String? subtitle;
  final IconData leadingIcon;
  final bool selected;

  const _SelectionCard({
    required this.value,
    required this.title,
    this.subtitle,
    required this.leadingIcon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withAlpha(150)
          : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: RadioListTile<T>(
        value: value,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        secondary: Icon(
          leadingIcon,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null ? null : Text(subtitle!),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final AutomationPermissionStatus permissionStatus;
  final Future<void> Function() onOpenDndSettings;
  final Future<void> Function() onOpenExactAlarmSettings;

  const _PermissionCard({
    required this.permissionStatus,
    required this.onOpenDndSettings,
    required this.onOpenExactAlarmSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFullyGranted = permissionStatus.isFullyGranted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFullyGranted
                    ? Icons.verified_user_outlined
                    : Icons.warning_amber_rounded,
                color: isFullyGranted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFullyGranted ? '课堂勿扰模式权限完备' : '还需要开启以下权限',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!isFullyGranted) ...[
            const SizedBox(height: 12),
            _PermissionRow(
              title: '勿扰权限',
              granted: permissionStatus.hasDndPermission,
              onPressed: onOpenDndSettings,
            ),
            const SizedBox(height: 10),
            _PermissionRow(
              title: '精确闹钟',
              granted: permissionStatus.hasExactAlarmPermission,
              onPressed: onOpenExactAlarmSettings,
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String title;
  final bool granted;
  final Future<void> Function() onPressed;

  const _PermissionRow({
    required this.title,
    required this.granted,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            '$title: ${granted ? '已开启' : '未开启'}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        FilledButton.tonal(
          onPressed: () {
            onPressed();
          },
          child: const Text('去设置'),
        ),
      ],
    );
  }
}
