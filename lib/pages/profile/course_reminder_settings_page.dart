import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/native_automation_service.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';
import 'profile_components.dart';

class CourseReminderSettingsPage extends ConsumerStatefulWidget {
  const CourseReminderSettingsPage({super.key});

  @override
  ConsumerState<CourseReminderSettingsPage> createState() =>
      _CourseReminderSettingsPageState();
}

class _CourseReminderSettingsPageState
    extends ConsumerState<CourseReminderSettingsPage>
    with WidgetsBindingObserver {
  CourseReminderPermissionStatus? _permissionStatus;
  bool _automationPermissionFlowActive = false;
  final _promptedAutomationPermissions = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadPermissionStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadPermissionStatus());
      unawaited(NativeAutomationService.refreshCourseReminders());
      if (_automationPermissionFlowActive) {
        unawaited(_continueAutomationPermissionFlow());
      }
    }
  }

  Future<void> _loadPermissionStatus() async {
    final status =
        await NativeAutomationService.getCourseReminderPermissionStatus();
    if (mounted) setState(() => _permissionStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    return AppPage(
      title: '课程提醒',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          const ProfileSectionLabel(title: '上课提醒'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.bell,
                title: '开启课程提醒',
                value: settings.courseReminderEnabled,
                onChange: (value) async {
                  await notifier.setCourseReminderEnabled(value);
                  if (value) {
                    await NativeAutomationService.requestNotificationPermission();
                    await NativeAutomationService.refreshCourseReminders();
                    await _loadPermissionStatus();
                  }
                },
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.clock3,
                title: '提前提醒时间',
                value: '${settings.courseReminderMinutes} 分钟',
                onTap: () => _openMinutesSheet(
                  context,
                  ref,
                  settings.courseReminderMinutes,
                ),
              ),
              ProfileSettingsCheckboxTile(
                icon: FLucideIcons.watch,
                title: '兼容穿戴设备通知',
                value: settings.wearableNotificationCompatibility,
                onChange: notifier.setWearableNotificationCompatibility,
              ),
            ],
          ),
          if (settings.courseReminderEnabled &&
              _permissionStatus != null &&
              !_permissionStatus!.isFullyGranted) ...[
            const SizedBox(height: AppSpacing.md),
            _PermissionStatusNotice(status: _permissionStatus!),
          ],
          const SizedBox(height: AppSpacing.md),
          const ProfileSettingsHint(
            '提醒通过系统通知发送。开启穿戴设备兼容模式后，提醒会使用可自动收起的普通通知，更容易被手表或手环同步。',
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '后台与权限'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.bell,
                title: '通知权限',
                value: _permissionStatus == null
                    ? '检查中'
                    : _permissionLabel(_permissionStatus!.notificationsGranted),
                onTap: () async {
                  await NativeAutomationService.openNotificationSettings();
                  await _loadPermissionStatus();
                },
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.alarmClock,
                title: '精确闹钟权限',
                value: _permissionStatus == null
                    ? '检查中'
                    : _permissionLabel(_permissionStatus!.exactAlarmGranted),
                onTap: () async {
                  await NativeAutomationService.openExactAlarmSettings();
                  await _loadPermissionStatus();
                },
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.bellOff,
                title: '勿扰模式权限',
                value: _permissionStatus == null
                    ? '检查中'
                    : _permissionLabel(_permissionStatus!.dndGranted),
                onTap: () async {
                  await NativeAutomationService.openDndSettings();
                  await _loadPermissionStatus();
                },
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.smartphone,
                title: '后台运行和自启',
                value: '打开系统设置',
                onTap:
                    NativeAutomationService.openBackgroundAndAutostartSettings,
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.battery,
                title: '忽略电池优化',
                value: _permissionStatus == null
                    ? '检查中'
                    : _permissionStatus!.batteryOptimizationIgnored
                    ? '已忽略'
                    : '未忽略',
                onTap: () async {
                  await NativeAutomationService.openBatteryOptimizationSettings();
                  await _loadPermissionStatus();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '课堂勿扰'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsControlTile(
                icon: FLucideIcons.bellOff,
                title: '课堂勿扰',
                child: ProfileSettingsOptionButtons<ClassAutomationMode>(
                  value: settings.classAutomationMode,
                  options: const [
                    ProfileSettingsOption(
                      value: ClassAutomationMode.off,
                      label: '关闭',
                    ),
                    ProfileSettingsOption(
                      value: ClassAutomationMode.dnd,
                      label: '上课恢复',
                    ),
                    ProfileSettingsOption(
                      value: ClassAutomationMode.dndKeep,
                      label: '保持勿扰',
                    ),
                  ],
                  onChanged: (mode) => unawaited(_setAutomationMode(mode)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _permissionLabel(bool granted) => granted ? '已授权' : '未授权';

  Future<void> _setAutomationMode(ClassAutomationMode selected) async {
    final currentMode = ref.read(appSettingsProvider).classAutomationMode;
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

  static Future<void> _openMinutesSheet(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final selected = await showAppSheet<int>(
      context: context,
      builder: (context) => AppOptionSheet<int>(
        title: '提前提醒时间',
        value: current,
        options: [
          for (final minutes in const [5, 10, 15, 20, 30, 45, 60])
            AppOption(
              value: minutes,
              title: '$minutes 分钟',
              icon: minutes == current
                  ? FLucideIcons.circleCheck
                  : FLucideIcons.clock3,
            ),
        ],
      ),
    );
    if (selected != null && selected != current) {
      await ref
          .read(appSettingsProvider.notifier)
          .setCourseReminderMinutes(selected);
    }
  }
}

class _PermissionStatusNotice extends StatelessWidget {
  final CourseReminderPermissionStatus status;

  const _PermissionStatusNotice({required this.status});

  @override
  Widget build(BuildContext context) {
    final missing = [
      if (!status.notificationsGranted) '通知权限',
      if (!status.exactAlarmGranted) '精确闹钟权限',
    ].join('、');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.theme.colors.semantic.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.theme.colors.semantic.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              FLucideIcons.circleAlert,
              size: 18,
              color: context.theme.colors.semantic.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '尚未获得$missing，提醒可能延迟或无法显示。',
                style: context.theme.typography.caption.copyWith(
                  color: context.theme.colors.semantic.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
