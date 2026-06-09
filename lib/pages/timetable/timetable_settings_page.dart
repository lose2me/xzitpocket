import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/native_automation_service.dart';
import '../../utils/snackbar_helper.dart';
import 'timetable_providers.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    ref.read(showNonCurrentWeekCoursesProvider.notifier).set(value);
  }

  Future<void> _openAutomationSheet(ClassAutomationMode currentMode) async {
    final selected = await showModalBottomSheet<ClassAutomationMode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _OptionSheet<ClassAutomationMode>(
        title: '课堂勿扰',
        value: currentMode,
        options: ClassAutomationMode.values
            .map(
              (mode) => _SheetOption<ClassAutomationMode>(
                value: mode,
                title: _automationTitle(mode),
              ),
            )
            .toList(),
      ),
    );

    if (selected != null && selected != currentMode) {
      await _updateAutomationMode(selected);
    }
  }

  Future<void> _openThemeSheet(AppThemePreference currentPreference) async {
    final selected = await showModalBottomSheet<AppThemePreference>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _OptionSheet<AppThemePreference>(
        title: '主题模式',
        value: currentPreference,
        options: AppThemePreference.values
            .map(
              (preference) => _SheetOption<AppThemePreference>(
                value: preference,
                title: _themeTitle(preference),
              ),
            )
            .toList(),
      ),
    );

    if (selected != null && selected != currentPreference) {
      await _updateTheme(selected);
    }
  }

  Future<void> _openVisibilitySheet(bool currentValue) async {
    final selected = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _OptionSheet<bool>(
        title: '显示非本周课程',
        value: currentValue,
        options: const [
          _SheetOption<bool>(
            value: true,
            title: '显示',
          ),
          _SheetOption<bool>(
            value: false,
            title: '隐藏',
          ),
        ],
      ),
    );

    if (selected != null && selected != currentValue) {
      _updateShowNonCurrentWeekCourses(selected);
    }
  }

  Future<void> _openPermissionSheet(
    AutomationPermissionStatus permissionStatus,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PermissionSheet(
        permissionStatus: permissionStatus,
        onOpenDndSettings: () async {
          Navigator.pop(context);
          await NativeAutomationService.openDndSettings();
        },
        onOpenExactAlarmSettings: () async {
          Navigator.pop(context);
          await NativeAutomationService.openExactAlarmSettings();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final showNonCurrentWeekCourses = ref.watch(showNonCurrentWeekCoursesProvider);
    final permissionStatus = _permissionStatus;
    final bgColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
        : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        children: [
          if (_isLoadingPermissions)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          _SectionLabel(title: '所需权限'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.verified_user_outlined,
                title: '所需权限',
                value: permissionStatus == null
                    ? '检测中'
                    : _permissionSummary(permissionStatus),
                valueColor: permissionStatus != null &&
                        !permissionStatus.isFullyGranted
                    ? theme.colorScheme.error
                    : null,
                onTap: permissionStatus == null
                    ? null
                    : () => _openPermissionSheet(permissionStatus),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel(title: '课堂'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.do_not_disturb_on_outlined,
                title: '课堂勿扰',
                value: _automationLabel(settings.classAutomationMode),
                onTap: () => _openAutomationSheet(
                  settings.classAutomationMode,
                ),
              ),
              _SettingsTile(
                icon: Icons.visibility_outlined,
                title: '显示非本周课程',
                value: showNonCurrentWeekCourses ? '显示' : '隐藏',
                onTap: () => _openVisibilitySheet(showNonCurrentWeekCourses),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel(title: '外观'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: '主题模式',
                value: _themeTitle(settings.themePreference),
                onTap: () => _openThemeSheet(settings.themePreference),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _automationLabel(ClassAutomationMode mode) {
    return switch (mode) {
      ClassAutomationMode.off => '关闭',
      ClassAutomationMode.dnd => '上课时开启',
      ClassAutomationMode.dndKeep => '下课不恢复',
    };
  }

  String _automationTitle(ClassAutomationMode mode) {
    return switch (mode) {
      ClassAutomationMode.off => '关闭',
      ClassAutomationMode.dnd => '上课开启，下课恢复',
      ClassAutomationMode.dndKeep => '上课开启，下课不恢复',
    };
  }

  String _themeTitle(AppThemePreference preference) {
    return switch (preference) {
      AppThemePreference.system => '跟随系统',
      AppThemePreference.light => '浅色模式',
      AppThemePreference.dark => '深色模式',
    };
  }

  String _permissionSummary(AutomationPermissionStatus status) {
    if (status.isFullyGranted) return '已完备';

    var count = 0;
    if (!status.hasDndPermission) count++;
    if (!status.hasExactAlarmPermission) count++;
    return '待开启 $count 项';
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(children.length * 2 - 1, (index) {
          if (index.isEven) {
            return children[index ~/ 2];
          }
          return Padding(
            padding: const EdgeInsets.only(left: 62, right: 18),
            child: Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withAlpha(120),
            ),
          );
        }),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveValueColor =
        valueColor ?? theme.colorScheme.onSurfaceVariant.withAlpha(200);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
        child: Row(
          children: [
            Icon(icon, size: 23, color: theme.colorScheme.onSurface),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 138),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value != null)
                    Flexible(
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: effectiveValueColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  if (value != null) const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(170),
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

class _SheetOption<T> {
  final T value;
  final String title;

  const _SheetOption({
    required this.value,
    required this.title,
  });
}

class _OptionSheet<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<_SheetOption<T>> options;

  const _OptionSheet({
    required this.title,
    required this.value,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ...options.map((option) {
                final selected = option.value == value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected
                        ? theme.colorScheme.primaryContainer.withAlpha(72)
                        : theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => Navigator.pop(context, option.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionSheet extends StatelessWidget {
  final AutomationPermissionStatus permissionStatus;
  final Future<void> Function() onOpenDndSettings;
  final Future<void> Function() onOpenExactAlarmSettings;

  const _PermissionSheet({
    required this.permissionStatus,
    required this.onOpenDndSettings,
    required this.onOpenExactAlarmSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '所需权限',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _PermissionRow(
                title: '勿扰权限',
                granted: permissionStatus.hasDndPermission,
                onPressed: onOpenDndSettings,
              ),
              const SizedBox(height: 12),
              _PermissionRow(
                title: '精确闹钟',
                granted: permissionStatus.hasExactAlarmPermission,
                onPressed: onOpenExactAlarmSettings,
              ),
            ],
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  granted ? '已开启' : '未开启',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: granted
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onPressed,
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
}
