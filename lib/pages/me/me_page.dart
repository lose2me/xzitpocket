import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../constants/upgrade_config.dart';
import '../../models/app_settings.dart';
import '../../models/update_info.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/credential_storage.dart';
import '../../services/native_automation_service.dart';
import '../../services/power_service.dart';
import '../../services/update_service.dart';
import '../../services/widget_service.dart';
import '../../utils/snackbar_helper.dart';
import '../timetable/timetable_providers.dart';

class MePage extends ConsumerStatefulWidget {
  const MePage({super.key});

  @override
  ConsumerState<MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<MePage> {
  bool _isCheckingUpdate = false;

  final _formKey = GlobalKey<FormState>();
  final _sidCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _sidCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(configProvider);
    final isLoggedIn =
        config.studentId != null && config.studentId!.isNotEmpty;

    if (!isLoggedIn) {
      return Scaffold(
        body: SafeArea(child: _buildLoginForm(theme)),
      );
    }

    final settings = ref.watch(appSettingsProvider);
    final showNonCurrentWeekCourses =
        ref.watch(showNonCurrentWeekCoursesProvider);
    final showWeekendColumns = ref.watch(showWeekendColumnsProvider);
    final savedRoomId = ref.watch(savedRoomIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        children: [
          _buildOpenSourceInfo(theme),
          if (UpgradeConfig.isConfigured) ...[
            const SizedBox(height: 16),
            Center(child: _buildCheckUpdateButton()),
          ],
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SectionLabel(title: '补充信息'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.apartment_outlined,
                  title: '宿舍号',
                  value: savedRoomId ?? '未设置',
                  onTap: () => _openRoomIdDialog(savedRoomId),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SectionLabel(title: '课堂'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.do_not_disturb_on_outlined,
                  title: '课堂勿扰',
                  value: _automationLabel(settings.classAutomationMode),
                  onTap: () =>
                      _openAutomationSheet(settings.classAutomationMode),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 23, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '显示非本周课程',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Checkbox(
                        value: showNonCurrentWeekCourses,
                        onChanged: (v) => _updateShowNonCurrentWeekCourses(v ?? false),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.view_week_outlined, size: 23, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '显示周末网格',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Checkbox(
                        value: showWeekendColumns,
                        onChanged: (v) => ref.read(showWeekendColumnsProvider.notifier).set(v ?? true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SectionLabel(title: '外观'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: '主题模式',
                  value: _themeTitle(settings.themePreference),
                  onTap: () => _openThemeSheet(settings.themePreference),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  '退出登录',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Login form ──

  Widget _buildLoginForm(ThemeData theme) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOpenSourceInfo(theme),
              const SizedBox(height: 24),
              if (UpgradeConfig.isConfigured) ...[
                _buildCheckUpdateButton(),
                const SizedBox(height: 24),
              ],
              Text('登录教务系统', style: theme.textTheme.titleLarge),
              const SizedBox(height: 24),
              TextFormField(
                controller: _sidCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '学号',
                  hintText: '请输入学号',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? '请输入学号' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pwdCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!isLoading) _login();
                },
                decoration: InputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? '请输入密码' : null,
              ),
              if (authState.status == AuthStatus.error) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authState.errorMessage ?? '登录失败',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: isLoading ? null : _login,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('登录', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final sid = _sidCtrl.text.trim();
    final pwd = _pwdCtrl.text;

    final result = await ref.read(authProvider.notifier).login(sid, pwd);
    _pwdCtrl.clear();
    if (result != null) {
      await CredentialStorage.setSavedPassword(pwd);

      try {
        await ref
            .read(scheduleProvider.notifier)
            .updateFromLoginResult(
              courses: result.courses,
              studentId: result.studentId ?? sid,
              studentName: result.studentName ?? '',
            );
      } on WidgetSyncException catch (e) {
        if (mounted) {
          showAppSnackBar(context, '登录成功，但$e');
        }
        return;
      }

      if (mounted) {
        showAppSnackBar(context, '登录成功，课表已同步');
      }
    }
  }

  // ── Open source & update ──

  Widget _buildOpenSourceInfo(ThemeData theme) {
    return Column(
      children: [
        Icon(Icons.code, size: 28, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          'github.com/lose2me/xzitpocket',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '';
            return Text(
              'Ver: $version License: GPL-3.0',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCheckUpdateButton() {
    return OutlinedButton.icon(
      onPressed: _isCheckingUpdate ? null : _checkForUpdate,
      icon: _isCheckingUpdate
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.system_update_alt_outlined),
      label: Text(_isCheckingUpdate ? '检查中...' : '检查更新'),
    );
  }

  // ── Settings actions ──

  Future<void> _updateTheme(AppThemePreference preference) async {
    await ref.read(appSettingsProvider.notifier).setThemePreference(preference);
  }

  Future<void> _updateAutomationMode(ClassAutomationMode mode) async {
    await ref.read(appSettingsProvider.notifier).setClassAutomationMode(mode);

    if (!mounted || mode == ClassAutomationMode.off) return;

    final status = await NativeAutomationService.getPermissionStatus();
    if (!mounted) return;

    if (!status.isFullyGranted) {
      final missing = <String>[];
      if (!status.hasDndPermission) missing.add('勿扰');
      if (!status.hasExactAlarmPermission) missing.add('精确闹钟');
      showAppSnackBar(context, '需要开启${missing.join('和')}权限');
    }
  }

  void _updateShowNonCurrentWeekCourses(bool value) {
    ref.read(showNonCurrentWeekCoursesProvider.notifier).set(value);
  }

  Future<void> _openRoomIdDialog(String? currentRoomId) async {
    final controller = TextEditingController(text: currentRoomId ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var isValidating = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('宿舍号'),
            content: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: '请输入宿舍号',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: isValidating
                    ? null
                    : () async {
                        final input = controller.text.trim();
                        if (input.isEmpty) {
                          Navigator.pop(ctx, '');
                          return;
                        }
                        setDialogState(() => isValidating = true);
                        final valid =
                            await PowerService().validateRoom(input);
                        if (!ctx.mounted) return;
                        if (valid) {
                          Navigator.pop(ctx, input.toUpperCase());
                        } else {
                          setDialogState(() => isValidating = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('无此房间号')),
                          );
                        }
                      },
                child: isValidating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    final prefs = ref.read(preferencesStorageProvider);
    await prefs.setSavedPowerRoomId(result);
    await prefs.clearPowerCache();
    ref.read(savedRoomIdProvider.notifier).set(result.isEmpty ? null : result);
    if (mounted) {
      showAppSnackBar(context, result.isEmpty ? '已清除宿舍号' : '保存成功');
    }
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

  // ── Helpers ──

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

  // ── Logout ──

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出将清除本地课表数据，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(scheduleProvider.notifier).clearAll();
              } on WidgetSyncException catch (e) {
                if (!mounted) return;
                showAppSnackBar(this.context, '已退出登录，但$e');
              }
              await ref.read(configProvider.notifier).logout();
              ref.read(authProvider.notifier).reset();
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Check update ──

  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;

    setState(() => _isCheckingUpdate = true);
    try {
      final result = await UpdateService.checkForUpdate();
      if (!mounted) return;

      if (!result.hasUpdate || result.updateInfo == null) {
        showAppSnackBar(context, result.message ?? '当前已是最新版本');
        return;
      }

      await _showUpdateDialog(result.updateInfo!);
    } on UpdateException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '检查更新失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo updateInfo) {
    final notes = updateInfo.releaseNotes.trim();
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.isForced,
      builder: (ctx) => AlertDialog(
        title: Text(updateInfo.upgradeLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('发现新版本 ${updateInfo.versionName}'),
            const SizedBox(height: 8),
            Text('版本号: ${updateInfo.versionCode}'),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('更新说明'),
              const SizedBox(height: 4),
              Text(notes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (updateInfo.isForced) {
                await SystemNavigator.pop();
                return;
              }
              Navigator.pop(ctx);
            },
            child: Text(updateInfo.isForced ? '取消' : '稍后'),
          ),
          FilledButton(
            onPressed: () async {
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              await _showDownloadDialog(updateInfo);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDownloadDialog(UpdateInfo updateInfo) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDownloadDialog(updateInfo: updateInfo),
    );
  }
}

// ── Settings widgets ──

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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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

// ── Bottom sheets ──

class _SheetOption<T> {
  final T value;
  final String title;

  const _SheetOption({required this.value, required this.title});
}

class _OptionSheet<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<_SheetOption<T>> options;

  const _OptionSheet({
    super.key,
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
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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

// ── Update download dialog ──

class _UpdateDownloadDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const _UpdateDownloadDialog({required this.updateInfo});

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  UpdateDownloadProgress _progress = const UpdateDownloadProgress(
    stage: UpdateDownloadStage.preparing,
    message: '准备下载更新包',
  );
  String? _errorMessage;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    setState(() {
      _errorMessage = null;
      _cancelToken = cancelToken;
      _progress = const UpdateDownloadProgress(
        stage: UpdateDownloadStage.preparing,
        message: '准备下载更新包',
      );
    });

    try {
      await UpdateService.downloadAndInstallUpdate(
        widget.updateInfo,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
          });
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '下载更新失败，请稍后重试';
      });
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressValue = _progress.progress;
    final title = switch (_progress.stage) {
      UpdateDownloadStage.preparing => '准备更新',
      UpdateDownloadStage.downloading => '正在下载',
      UpdateDownloadStage.installing => '准备安装',
    };

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(_errorMessage == null ? title : '更新失败'),
        content: _errorMessage == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('发现新版本 ${widget.updateInfo.versionName}'),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(value: progressValue),
                  const SizedBox(height: 12),
                  Text(
                    _progress.message ?? '',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _buildProgressLine(),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_progress.stage ==
                      UpdateDownloadStage.downloading) ...[
                    const SizedBox(height: 4),
                    Text(
                      '速率: ${_formatSpeed(_progress.bytesPerSecond)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              )
            : Text(_errorMessage!),
        actions: [
          if (_errorMessage == null && !widget.updateInfo.isForced)
            TextButton(
              onPressed: _cancelDownload,
              child: const Text('取消'),
            ),
          if (_errorMessage != null)
            TextButton(
              onPressed: () async {
                if (widget.updateInfo.isForced) {
                  await SystemNavigator.pop();
                  return;
                }
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: Text(widget.updateInfo.isForced ? '退出应用' : '关闭'),
            ),
          if (_errorMessage != null)
            FilledButton(
              onPressed: _startDownload,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }

  String _buildProgressLine() {
    if (_progress.stage == UpdateDownloadStage.installing) {
      return '已下载 ${_formatBytes(_progress.receivedBytes)}';
    }

    final received = _formatBytes(_progress.receivedBytes);
    if (_progress.totalBytes > 0) {
      final total = _formatBytes(_progress.totalBytes);
      final percent = ((_progress.progress ?? 0) * 100).clamp(0.0, 100.0);
      return '$received / $total  (${percent.toStringAsFixed(1)}%)';
    }
    return received;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final fractionDigits = unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
  }

  String _formatSpeed(double bytesPerSecond) {
    final safeValue = bytesPerSecond.isFinite ? bytesPerSecond : 0;
    return '${_formatBytes(safeValue.round())}/s';
  }
}
