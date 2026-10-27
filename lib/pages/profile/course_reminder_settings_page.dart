import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/native_automation_service.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';
import '../tools/repair_picker_sheet.dart';
import 'profile_components.dart';

enum _PermissionTarget { notifications, exactAlarm, dnd }

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
    }
  }

  Future<CourseReminderPermissionStatus> _loadPermissionStatus() async {
    final status =
        await NativeAutomationService.getCourseReminderPermissionStatus();
    if (!mounted) return status;
    final settings = ref.read(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    if (settings.courseReminderEnabled && !status.isFullyGranted) {
      await notifier.setCourseReminderEnabled(false);
    }
    if (settings.classAutomationMode != ClassAutomationMode.off &&
        (!status.dndGranted || !status.exactAlarmGranted)) {
      await notifier.setClassAutomationMode(ClassAutomationMode.off);
    }
    if (mounted) setState(() => _permissionStatus = status);
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
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
                onChange: _setCourseReminderEnabled,
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
                onChange: _setWearableCompatibility,
              ),
            ],
          ),
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
                value: '系统设置',
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
              ProfileSettingsChoiceTile<ClassAutomationMode>(
                icon: FLucideIcons.bellOff,
                title: '课堂勿扰',
                value: settings.classAutomationMode,
                options: const [
                  ProfileSettingsOption(
                    value: ClassAutomationMode.off,
                    label: '关闭',
                  ),
                  ProfileSettingsOption(
                    value: ClassAutomationMode.dnd,
                    label: '下课后恢复',
                  ),
                  ProfileSettingsOption(
                    value: ClassAutomationMode.dndKeep,
                    label: '下课后不恢复',
                  ),
                ],
                onChanged: (mode) => unawaited(_setAutomationMode(mode)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _permissionLabel(bool granted) => granted ? '已授权' : '未授权';

  Future<void> _setWearableCompatibility(bool enabled) async {
    final notifier = ref.read(appSettingsProvider.notifier);
    if (!enabled) {
      await notifier.setWearableNotificationCompatibility(false);
      return;
    }
    if (!ref.read(appSettingsProvider).courseReminderEnabled) {
      showAppSnackBar(context, '请先开启课程提醒', severity: ToastSeverity.warning);
      return;
    }
    await notifier.setWearableNotificationCompatibility(true);
  }

  Future<void> _setCourseReminderEnabled(bool enabled) async {
    final notifier = ref.read(appSettingsProvider.notifier);
    if (!enabled) {
      await notifier.setCourseReminderEnabled(false);
      return;
    }
    final status = await _loadPermissionStatus();
    if (!mounted) return;
    final missing = <_PermissionTarget>{
      if (!status.notificationsGranted) _PermissionTarget.notifications,
      if (!status.exactAlarmGranted) _PermissionTarget.exactAlarm,
    };
    if (missing.isNotEmpty) {
      showAppSnackBar(
        context,
        '请先开启${_permissionLabels(missing)}',
        severity: ToastSeverity.warning,
      );
      // 只弹 toast 提示缺失权限，不再滚动定位到对应条目。
      return;
    }
    await notifier.setCourseReminderEnabled(true);
  }

  Future<void> _setAutomationMode(ClassAutomationMode selected) async {
    final currentMode = ref.read(appSettingsProvider).classAutomationMode;
    if (selected == currentMode) return;
    final notifier = ref.read(appSettingsProvider.notifier);
    if (selected == ClassAutomationMode.off) {
      await notifier.setClassAutomationMode(selected);
      return;
    }
    final status = await _loadPermissionStatus();
    if (!mounted) return;
    final missing = <_PermissionTarget>{
      if (!status.exactAlarmGranted) _PermissionTarget.exactAlarm,
      if (!status.dndGranted) _PermissionTarget.dnd,
    };
    if (missing.isNotEmpty) {
      showAppSnackBar(
        context,
        '请先开启${_permissionLabels(missing)}',
        severity: ToastSeverity.warning,
      );
      // 只弹 toast 提示缺失权限，不再滚动定位到对应条目。
      return;
    }
    await notifier.setClassAutomationMode(selected);
  }

  String _permissionLabels(Set<_PermissionTarget> permissions) {
    final labels = [
      if (permissions.contains(_PermissionTarget.notifications)) '通知权限',
      if (permissions.contains(_PermissionTarget.exactAlarm)) '精确闹钟权限',
      if (permissions.contains(_PermissionTarget.dnd)) '勿扰模式权限',
    ];
    return labels.join('和');
  }

  /// 与「新建报修 → 选择报修区域」一致的上弹滚轮选择器样式。
  static Future<void> _openMinutesSheet(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    // 5-60 分钟的任意整数。
    final minutesOptions = [
      for (var minutes = 5; minutes <= 60; minutes++) minutes,
    ];
    final choices = [
      for (final minutes in minutesOptions)
        WheelChoice(label: '$minutes 分钟', value: minutes),
    ];
    // 滚轮默认停在当前分钟数；当前值不在选项内时停在最接近的一项。
    var initialIndex = minutesOptions.indexOf(current);
    if (initialIndex < 0) {
      initialIndex = 0;
      for (var index = 0; index < minutesOptions.length; index++) {
        if ((minutesOptions[index] - current).abs() <
            (minutesOptions[initialIndex] - current).abs()) {
          initialIndex = index;
        }
      }
    }
    final selected = await showAppSheet<WheelChoice<int>>(
      context: context,
      maxHeightRatio: 0.5,
      builder: (context) => SingleWheelSheet<int>(
        title: '提前提醒时间',
        choices: choices,
        initialIndex: initialIndex,
      ),
    );
    if (selected != null && selected.value != current) {
      await ref
          .read(appSettingsProvider.notifier)
          .setCourseReminderMinutes(selected.value);
    }
  }
}
