import 'dart:async';

import 'package:flutter/material.dart' show InputBorder;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/credential_storage.dart';
import '../../services/native_automation_service.dart';
import '../../services/password_reset_service.dart';
import '../../services/power_service.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../services/widget_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import '../about/open_source_license_page.dart';
import '../../services/cas_service.dart';
import '../home_page.dart';
import '../timetable/timetable_providers.dart';
import 'profile_components.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static final globalKey = GlobalKey<ProfilePageState>();

  @override
  ConsumerState<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _sidCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Password reset
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _newPwd2Ctrl = TextEditingController();
  final _codeFocusNode = FocusNode();
  final _resetService = PasswordResetService();
  bool _resetLoading = false;
  int _codeCountdown = 0;
  Timer? _codeTimer;
  bool _obscureNew1 = true;
  bool _obscureNew2 = true;
  int _currentPage = 0;
  String? _verifyValidateId;
  String? _selectedSid;

  final _roomIdController = TextEditingController();
  final _roomIdFocusNode = FocusNode();
  bool _roomIdInitialized = false;
  bool _isSavingRoom = false;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _roomIdFocusNode.addListener(_saveRoomOnFocusLoss);
  }

  @override
  void dispose() {
    _sidCtrl.dispose();
    _pwdCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _newPwdCtrl.dispose();
    _newPwd2Ctrl.dispose();
    _codeFocusNode.dispose();
    _codeTimer?.cancel();
    _resetService.dispose();
    _roomIdController.dispose();
    _roomIdFocusNode.dispose();
    super.dispose();
  }

  void _saveRoomOnFocusLoss() {
    if (!_roomIdFocusNode.hasFocus && mounted) {
      unawaited(_submitRoomId());
    }
  }

  void finishRoomIdEditing() => _roomIdFocusNode.unfocus();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final config = ref.watch(configProvider);
    final isLoggedIn = config.studentId != null && config.studentId!.isNotEmpty;

    if (!isLoggedIn || _isLoggingIn) {
      return AppPage(
        root: true,
        child: SafeArea(child: _buildLoginForm(theme)),
      );
    }

    final settings = ref.watch(appSettingsProvider);
    final showNonCurrentWeekCourses = ref.watch(
      showNonCurrentWeekCoursesProvider,
    );
    final showWeekendColumns = ref.watch(showWeekendColumnsProvider);
    final savedRoomId = ref.watch(savedRoomIdProvider);

    if (!_roomIdInitialized) {
      _roomIdController.text = savedRoomId ?? '';
      _roomIdInitialized = true;
    }

    return AppPage(
      title: '掌上徐工',
      root: true,
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        children: [
          _buildVersionLine(theme),
          const SizedBox(height: AppSpacing.md),
          const ProfileSectionLabel(title: '用户信息'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.badge,
                title: '学号',
                value: config.studentId ?? '',
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.userRound,
                title: '姓名',
                value: config.studentName ?? '',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '补充信息'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsControlTile(
                icon: FLucideIcons.building2,
                title: '宿舍号',
                onTap: _roomIdFocusNode.requestFocus,
                child: SizedBox(
                  width: 112,
                  height: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.colors.mutedForeground),
                      ),
                    ),
                    child: AppTextField(
                      controller: _roomIdController,
                      focusNode: _roomIdFocusNode,
                      hint: '未设置',
                      size: FTextFieldSizeVariant.sm,
                      style: FTextFieldStyleDelta.delta(
                        constraints: const BoxConstraints.tightFor(height: 24),
                        contentPadding: const EdgeInsetsGeometryDelta.value(
                          EdgeInsets.zero,
                        ),
                        border: FVariantsValueDelta.delta([
                          FVariantValueDeltaOperation.all(InputBorder.none),
                        ]),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      onSubmitted: (_) => _roomIdFocusNode.unfocus(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '课表'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.bellOff,
                title: '课堂勿扰',
                value: _automationLabel(settings.classAutomationMode),
                onTap: () => _openAutomationSheet(settings.classAutomationMode),
              ),
              ProfileSettingsToggleTile(
                icon: FLucideIcons.eye,
                title: '显示非本周课程',
                value: showNonCurrentWeekCourses,
                onChange: _updateShowNonCurrentWeekCourses,
              ),
              ProfileSettingsToggleTile(
                icon: FLucideIcons.calendarDays,
                title: '隐藏周末网格',
                value: !showWeekendColumns,
                onChange: (v) =>
                    ref.read(showWeekendColumnsProvider.notifier).set(!v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '外观'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.palette,
                title: '主题模式',
                value: _themeTitle(settings.themePreference),
                onTap: () => _openThemeSheet(settings.themePreference),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '软件信息'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.bug,
                title: '调试模式',
                value: talker.settings.enabled ? '已开启' : '关闭',
                onTap: () async {
                  await Navigator.of(context).push(
                    appRoute(
                      name: AppRouteNames.debugLogs,
                      builder: (context) => TalkerScreen(
                        talker: talker,
                        appBarTitle: '调试日志',
                        isLogOrderReversed: true,
                        isLogsExpanded: true,
                      ),
                    ),
                  );
                  setState(() {});
                },
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.fileText,
                title: '开源许可证',
                onTap: () => Navigator.of(context).push(
                  appRoute(
                    name: AppRouteNames.licenses,
                    builder: (_) => const OpenSourceLicensePage(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FButton(
              variant: FButtonVariant.destructive,
              onPress: () => _logout(context),
              prefix: const Icon(FLucideIcons.logOut),
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Login form ──

  Widget _buildLoginForm(FThemeData theme) {
    final authState = ref.watch(authProvider);
    final isLoading = _isLoggingIn || authState.status == AuthStatus.loading;
    final buttons = _buildAccessActions(isLoading);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          AppLayout.pageGutter(context),
          AppSpacing.lg,
          AppLayout.pageGutter(context),
          AppSpacing.xxl,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - AppSpacing.spacious).clamp(
              0.0,
              double.infinity,
            ),
          ),
          child: Transform.translate(
            offset: const Offset(0, -40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOpenSourceInfo(theme),
                const SizedBox(height: AppSpacing.xxl),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.formMaxWidth,
                  ),
                  child: IndexedStack(
                    index: _currentPage,
                    children: [
                      _buildLoginPanel(theme, isLoading, buttons),
                      _buildVerifyPanel(theme, buttons),
                      _buildPasswordPanel(theme, buttons),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _switchPage(int page) {
    setState(() => _currentPage = page);
  }

  Widget _buildAccessActions(bool isLoading) {
    final onReset = _currentPage > 0;

    final rightLabel = _currentPage == 0
        ? '找回密码'
        : (_currentPage == 1 ? '验证' : '确定');
    final leftLoading = !onReset && isLoading;
    final rightLoading = onReset && _resetLoading;

    VoidCallback? rightAction;
    if (_currentPage == 0) {
      rightAction = isLoading ? null : () => _switchPage(1);
    } else if (_currentPage == 1) {
      rightAction = _resetLoading ? null : _submitVerify;
    } else {
      rightAction = _resetLoading ? null : _submitReset;
    }

    return Row(
      children: [
        Expanded(
          child: FButton(
            variant: onReset ? FButtonVariant.outline : FButtonVariant.primary,
            onPress: onReset
                ? (_resetLoading ? null : () => _switchPage(0))
                : (isLoading ? null : _login),
            prefix: leftLoading
                ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
                : null,
            child: const Text('登录'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FButton(
            variant: onReset ? FButtonVariant.primary : FButtonVariant.outline,
            onPress: rightAction,
            prefix: rightLoading
                ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
                : null,
            child: Text(rightLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPanel(FThemeData theme, bool isLoading, Widget buttons) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('统一身份认证', style: theme.typography.pageTitle),
          const SizedBox(height: AppSpacing.xxl),
          AppTextFormField(
            controller: _sidCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            label: '学号',
            hint: '请输入学号',
            prefix: const Icon(FLucideIcons.userRound),
            validator: (v) => v == null || v.isEmpty ? '请输入学号' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextFormField(
            controller: _pwdCtrl,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!isLoading) unawaited(_login());
            },
            label: '密码',
            hint: '请输入密码',
            prefix: const Icon(FLucideIcons.lockKeyhole),
            suffix: AppIconButton(
              icon: _obscurePassword ? FLucideIcons.eyeOff : FLucideIcons.eye,
              onPress: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
              size: FButtonSizeVariant.xs,
            ),
            validator: (v) => v == null || v.isEmpty ? '请输入密码' : null,
          ),
          const SizedBox(height: AppSpacing.xxl),
          buttons,
        ],
      ),
    );
  }

  Widget _buildVerifyPanel(FThemeData theme, Widget buttons) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('找回密码', style: theme.typography.pageTitle),
        const SizedBox(height: AppSpacing.xxl),
        AppTextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          label: '手机号',
          hint: '输入手机号码',
          prefix: const Icon(FLucideIcons.phone),
          suffix: FButton(
            variant: FButtonVariant.ghost,
            size: FButtonSizeVariant.md,
            mainAxisSize: MainAxisSize.min,
            onPress: _resetLoading || _codeCountdown > 0 ? null : _sendResetCode,
            child: Text(
              _codeCountdown > 0 ? '${_codeCountdown}s' : '发送验证码',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _codeCtrl,
          focusNode: _codeFocusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitVerify(),
          label: '验证码',
          hint: '输入六位验证码',
          prefix: const Icon(FLucideIcons.messageSquare),
        ),
        const SizedBox(height: AppSpacing.xxl),
        buttons,
      ],
    );
  }

  Widget _buildPasswordPanel(FThemeData theme, Widget buttons) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('设置新密码', style: theme.typography.pageTitle),
        const SizedBox(height: AppSpacing.xxl),
        AppTextField(
          controller: _newPwdCtrl,
          obscureText: _obscureNew1,
          textInputAction: TextInputAction.next,
          label: '新密码',
          hint: '至少10位，含大小写、数字、特殊字符',
          prefix: const Icon(FLucideIcons.lockKeyhole),
          suffix: AppIconButton(
            icon: _obscureNew1 ? FLucideIcons.eyeOff : FLucideIcons.eye,
            onPress: () => setState(() => _obscureNew1 = !_obscureNew1),
            tooltip: _obscureNew1 ? '显示密码' : '隐藏密码',
            size: FButtonSizeVariant.xs,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _newPwd2Ctrl,
          obscureText: _obscureNew2,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitReset(),
          label: '确认密码',
          hint: '再次输入新密码',
          prefix: const Icon(FLucideIcons.lockKeyhole),
          suffix: AppIconButton(
            icon: _obscureNew2 ? FLucideIcons.eyeOff : FLucideIcons.eye,
            onPress: () => setState(() => _obscureNew2 = !_obscureNew2),
            tooltip: _obscureNew2 ? '显示密码' : '隐藏密码',
            size: FButtonSizeVariant.xs,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        buttons,
      ],
    );
  }

  Future<void> _sendResetCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      showAppSnackBar(context, '请输入手机号');
      return;
    }
    setState(() => _resetLoading = true);
    try {
      await _resetService.sendCode(phone);
      if (!mounted) return;
      setState(() {
        _codeCountdown = 60;
        _resetLoading = false;
      });
      _codeTimer?.cancel();
      _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _codeCountdown--;
          if (_codeCountdown <= 0) {
            _codeCountdown = 0;
            timer.cancel();
          }
        });
      });
      showAppSnackBar(context, '验证码已发送');
      _codeFocusNode.requestFocus();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      talker.error('密码重置验证码发送异常', e, stackTrace);
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, '发送失败');
    }
  }

  Future<void> _submitVerify() async {
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (phone.isEmpty) {
      showAppSnackBar(context, '请输入手机号');
      return;
    }
    if (code.isEmpty) {
      showAppSnackBar(context, '请输入验证码');
      return;
    }

    setState(() => _resetLoading = true);
    try {
      final verifyResult = await _resetService.verifyCode(phone, code);
      if (!mounted) return;

      String? selectedSid;
      final accounts = verifyResult.accounts;
      if (accounts.isEmpty) {
        showAppSnackBar(context, '未找到关联账号');
        setState(() => _resetLoading = false);
        return;
      } else if (accounts.length == 1) {
        selectedSid = accounts.first.sid;
      } else {
        selectedSid = await showAppSheet<String>(
          context: context,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(padding: EdgeInsets.all(8), child: Text('选择账号')),
                ...accounts.map(
                  (a) => FItem(
                    title: Text(
                      a.info.isNotEmpty ? '${a.sid} (${a.info})' : a.sid,
                    ),
                    onPress: () => Navigator.pop(ctx, a.sid),
                  ),
                ),
              ],
            ),
          ),
        );
        if (selectedSid == null || !mounted) {
          setState(() => _resetLoading = false);
          return;
        }
      }

      setState(() {
        _verifyValidateId = verifyResult.validateId;
        _selectedSid = selectedSid;
        _resetLoading = false;
      });
      _switchPage(2);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      talker.error('密码重置身份验证异常', e, stackTrace);
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, '验证失败');
    }
  }

  Future<void> _submitReset() async {
    final phone = _phoneCtrl.text.trim();
    final pwd = _newPwdCtrl.text;
    final pwd2 = _newPwd2Ctrl.text;

    if (pwd.isEmpty) {
      showAppSnackBar(context, '请输入新密码');
      return;
    }
    if (pwd != pwd2) {
      showAppSnackBar(context, '两次密码不一致');
      return;
    }
    final valErr = PasswordResetService.validatePassword(pwd);
    if (valErr.isNotEmpty) {
      showAppSnackBar(context, valErr);
      return;
    }
    if (_selectedSid == null || _verifyValidateId == null) {
      showAppSnackBar(context, '请先完成验证');
      return;
    }

    setState(() => _resetLoading = true);
    try {
      await _resetService.resetPassword(
        phone,
        pwd,
        _selectedSid!,
        _verifyValidateId!,
      );
      if (!mounted) return;
      showAppSnackBar(context, '密码重置成功，正在登录...');
      _phoneCtrl.clear();
      _codeCtrl.clear();
      _newPwdCtrl.clear();
      _newPwd2Ctrl.clear();
      setState(() {
        _codeCountdown = 0;
        _codeTimer?.cancel();
        _resetLoading = false;
        _verifyValidateId = null;
      });

      _sidCtrl.text = _selectedSid!;
      _pwdCtrl.text = pwd;
      _selectedSid = null;
      _switchPage(0);
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      await _login();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      talker.error('密码重置异常', e, stackTrace);
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, '重置失败');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final sid = _sidCtrl.text.trim();
    final pwd = _pwdCtrl.text;

    setState(() => _isLoggingIn = true);

    final result = await ref.read(authProvider.notifier).login(sid, pwd);
    if (result != null) {
      _pwdCtrl.clear();
      final (loginResult, examResult) = result;
      await CredentialStorage.setSavedPassword(pwd);

      try {
        await ref
            .read(scheduleProvider.notifier)
            .updateFromLoginResult(
              courses: loginResult.courses,
              studentId: loginResult.studentId ?? sid,
              studentName: loginResult.studentName ?? '',
            );
      } on WidgetSyncException catch (e) {
        if (mounted) {
          setState(() => _isLoggingIn = false);
          showAppSnackBar(context, '登录成功，但$e');
        }
        return;
      }

      await ToolsDataManager.instance.setExams(
        examResult,
        ref.read(preferencesStorageProvider),
      );

      if (mounted) {
        setState(() => _isLoggingIn = false);
        showAppSnackBar(context, '登录成功');
        HomePage.globalKey.currentState?.switchToTimetable();
      }

      final prefs = ref.read(preferencesStorageProvider);
      unawaited(
        ToolsDataManager.instance.startBackgroundLoading(
          studentId: sid,
          password: pwd,
          prefs: prefs,
          roomId: prefs.getSavedPowerRoomId(),
        ),
      );
    } else if (mounted) {
      setState(() => _isLoggingIn = false);
      final authState = ref.read(authProvider);
      showAppSnackBar(context, authState.errorMessage ?? '登录失败');
    }
  }

  // ── Open source & update ──

  Widget _buildVersionLine(FThemeData theme) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '';
        return Text(
          'Ver: $version  ·  GPL-3.0',
          textAlign: TextAlign.center,
          style: theme.typography.caption.copyWith(
            color: theme.colors.mutedForeground,
          ),
        );
      },
    );
  }

  Widget _buildOpenSourceInfo(FThemeData theme) {
    return Column(
      children: [
        Icon(FLucideIcons.code2, size: 28, color: theme.colors.mutedForeground),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'github.com/lose2me/xzitpocket',
          style: theme.typography.caption.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 2),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '';
            return Text(
              'Ver: $version License: GPL-3.0',
              style: theme.typography.caption.copyWith(
                color: theme.colors.mutedForeground,
              ),
            );
          },
        ),
      ],
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

  Future<void> _submitRoomId() async {
    if (_isSavingRoom) return;

    final input = _roomIdController.text.trim().toUpperCase();
    final saved = ref.read(savedRoomIdProvider) ?? '';
    if (input == saved) return;

    if (input.isEmpty) {
      final prefs = ref.read(preferencesStorageProvider);
      await prefs.setSavedPowerRoomId('');
      await prefs.clearPowerCache();
      ref.read(savedRoomIdProvider.notifier).set(null);
      if (mounted) showAppSnackBar(context, '已清除宿舍号');
      return;
    }

    _isSavingRoom = true;
    late final bool valid;
    try {
      valid = await PowerService().validateRoom(input);
    } catch (error, stackTrace) {
      talker.error('宿舍号本地校验失败', error, stackTrace);
      if (mounted) showAppSnackBar(context, '宿舍号校验失败');
      return;
    } finally {
      _isSavingRoom = false;
    }

    if (!mounted) return;

    if (valid) {
      _roomIdController.text = input;
      final prefs = ref.read(preferencesStorageProvider);
      await prefs.setSavedPowerRoomId(input);
      await prefs.clearPowerCache();
      ref.read(savedRoomIdProvider.notifier).set(input);
      if (!mounted) return;
      showAppSnackBar(context, '保存成功');
    } else {
      showAppSnackBar(context, '无此房间号');
    }
  }

  Future<void> _openAutomationSheet(ClassAutomationMode currentMode) async {
    final selected = await showAppSheet<ClassAutomationMode>(
      context: context,
      builder: (context) => ProfileOptionSheet<ClassAutomationMode>(
        value: currentMode,
        options: ClassAutomationMode.values
            .map(
              (mode) => ProfileOption<ClassAutomationMode>(
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
    final selected = await showAppSheet<AppThemePreference>(
      context: context,
      builder: (context) => ProfileOptionSheet<AppThemePreference>(
        value: currentPreference,
        options: AppThemePreference.values
            .map(
              (preference) => ProfileOption<AppThemePreference>(
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
    unawaited(_logoutAfterConfirmation(context));
  }

  Future<void> _logoutAfterConfirmation(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '退出登录',
      message: '退出将清除本地课表数据，确定继续吗？',
      confirmLabel: '退出',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(scheduleProvider.notifier).clearAll();
    } on WidgetSyncException catch (e) {
      if (!mounted) return;
      showAppSnackBar(this.context, '已退出登录，但$e');
    }
    await ref.read(configProvider.notifier).logout();
    ref.read(authProvider.notifier).reset();
  }
}
