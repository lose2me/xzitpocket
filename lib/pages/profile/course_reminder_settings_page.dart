import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/native_automation_service.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CourseReminderPermissionStatus? _permissionStatus;
  final _scrollController = ScrollController();
  final _notificationPermissionKey = GlobalKey();
  final _exactAlarmPermissionKey = GlobalKey();
  final _dndPermissionKey = GlobalKey();
  late final AnimationController _permissionAttentionController;
  late final Animation<double> _permissionAttention;
  Timer? _permissionAttentionTimer;
  Set<_PermissionTarget> _highlightedPermissions = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionAttentionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _permissionAttention = CurvedAnimation(
      parent: _permissionAttentionController,
      curve: Curves.easeInOut,
    );
    unawaited(_loadPermissionStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionAttentionTimer?.cancel();
    _permissionAttentionController.dispose();
    _scrollController.dispose();
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
    final notifier = ref.read(appSettingsProvider.notifier);
    return AppPage(
      title: '课程提醒',
      child: AppPageListView(
        controller: _scrollController,
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
                onChange: notifier.setWearableNotificationCompatibility,
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
                key: _notificationPermissionKey,
                icon: FLucideIcons.bell,
                title: '通知权限',
                value: _permissionStatus == null
                    ? '检查中'
                    : _permissionLabel(_permissionStatus!.notificationsGranted),
                attentionAnimation:
                    _highlightedPermissions.contains(
                      _PermissionTarget.notifications,
                    )
                    ? _permissionAttention
                    : null,
                onTap: () async {
                  await NativeAutomationService.openNotificationSettings();
                  await _loadPermissionStatus();
                },
              ),
              ProfileSettingsTile(
                key: _exactAlarmPermissionKey,
                icon: FLucideIcons.alarmClock,
                title: '精确闹钟权限',
                value: _permissionStatus == null
                    ? '检查中'
                    : _permissionLabel(_permissionStatus!.exactAlarmGranted),
                attentionAnimation:
                    _highlightedPermissions.contains(
                      _PermissionTarget.exactAlarm,
                    )
                    ? _permissionAttention
                    : null,
                onTap: () async {
                  await NativeAutomationService.openExactAlarmSettings();
                  await _loadPermissionStatus();
                },
              ),
              ProfileSettingsTile(
                key: _dndPermissionKey,
                icon: FLucideIcons.bellOff,
                title: '勿扰模式权限',
                value: _permissionStatus == null
                    ? '检查中'
                    : _permissionLabel(_permissionStatus!.dndGranted),
                attentionAnimation:
                    _highlightedPermissions.contains(_PermissionTarget.dnd)
                    ? _permissionAttention
                    : null,
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
      await _focusPermissions(missing);
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
      await _focusPermissions(missing);
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

  Future<void> _focusPermissions(Set<_PermissionTarget> permissions) async {
    _permissionAttentionTimer?.cancel();
    _permissionAttentionController
      ..stop()
      ..reset()
      ..repeat(reverse: true);
    setState(() => _highlightedPermissions = permissions);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final first = [
      _PermissionTarget.notifications,
      _PermissionTarget.exactAlarm,
      _PermissionTarget.dnd,
    ].firstWhere(permissions.contains);
    final targetContext = switch (first) {
      _PermissionTarget.notifications =>
        _notificationPermissionKey.currentContext,
      _PermissionTarget.exactAlarm => _exactAlarmPermissionKey.currentContext,
      _PermissionTarget.dnd => _dndPermissionKey.currentContext,
    };
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.2,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    _permissionAttentionTimer = Timer(const Duration(milliseconds: 1800), () {
      _permissionAttentionController
        ..stop()
        ..reset();
      if (mounted) setState(() => _highlightedPermissions = const {});
    });
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
