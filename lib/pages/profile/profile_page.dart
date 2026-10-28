import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/secondary_schedule_provider.dart';
import '../../services/credential_storage.dart';
import '../../services/password_reset_service.dart';
import '../../services/power_service.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../services/widget_service.dart';
import '../../utils/error_message.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import '../../ui/update_prompt.dart';
import '../about/extra_pages_page.dart';
import '../about/faq_page.dart';
import '../about/open_source_license_page.dart';
import '../../services/cas_service.dart';
import '../../services/control_service.dart';
import '../home_page.dart';
import 'profile_components.dart';
import 'appearance_settings_page.dart';
import 'course_reminder_settings_page.dart';
import 'course_rules_settings_page.dart';
import 'config_backup_page.dart';
import '../timetable/timetable_settings_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static final globalKey = GlobalKey<ProfilePageState>();

  @override
  ConsumerState<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends ConsumerState<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final _sidCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Password reset
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = FOtpController(children: appOtpChildren());
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
    super.build(context);
    final theme = context.theme;
    final config = ref.watch(configProvider);
    final isLoggedIn = config.studentId != null && config.studentId!.isNotEmpty;

    if (!isLoggedIn || _isLoggingIn) {
      return AppPage(
        root: true,
        // Home provides only the keyboard overlap below this root viewport.
        resizeToAvoidBottomInset: true,
        child: SafeArea(child: _buildLoginForm(theme)),
      );
    }

    final savedRoomId = ref.watch(savedRoomIdProvider);

    ref.listen(savedRoomIdProvider, (previous, next) {
      if (next != _roomIdController.text) {
        _roomIdController.text = next ?? '';
      }
    });

    if (!_roomIdInitialized) {
      _roomIdController.text = savedRoomId ?? '';
      _roomIdInitialized = true;
    }

    return AppPage(
      title: '掌上徐工',
      root: true,
      resizeToAvoidBottomInset: true,
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.sm,
        children: [
          _buildVersionLine(theme),
          const SizedBox(height: AppSpacing.md),
          const _ProfileUpdateCard(),
          const SizedBox(height: AppSpacing.md),
          const ProfileSectionLabel(title: '用户信息'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.building2,
                title: '学院',
                value: config.collegeName ?? '',
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.userRound,
                title: '用户',
                value: [config.className, config.studentName]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' '),
              ),
              ProfileSettingsInlineControlTile(
                icon: FLucideIcons.building2,
                title: '宿舍号',
                onTap: _roomIdFocusNode.requestFocus,
                child: SizedBox(
                  width: 112,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.colors.border),
                      ),
                    ),
                    child: AppTextField(
                      controller: _roomIdController,
                      focusNode: _roomIdFocusNode,
                      hint: '如 7B216',
                      size: FTextFieldSizeVariant.sm,
                      style: FTextFieldStyleDelta.delta(
                        color: FVariantsValueDelta.delta([
                          FVariantValueDeltaOperation.all(Colors.transparent),
                        ]),
                        constraints: const BoxConstraints.tightFor(height: 32),
                        contentPadding: const EdgeInsetsGeometryDelta.value(
                          EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        ),
                        border: FVariantsValueDelta.delta([
                          FVariantValueDeltaOperation.all(InputBorder.none),
                        ]),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.start,
                      onSubmitted: (_) => _roomIdFocusNode.unfocus(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '软件设置'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.palette,
                title: '个性化设置',
                onTap: () => Navigator.of(context).push(
                  appRoute(
                    name: AppRouteNames.timetableSettings,
                    builder: (_) => const TimetableSettingsPage(),
                  ),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.bell,
                title: '课程提醒',
                onTap: () => Navigator.of(context).push(
                  appRoute(
                    name: AppRouteNames.courseReminderSettings,
                    builder: (_) => const CourseReminderSettingsPage(),
                  ),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.history,
                title: '课程规则',
                onTap: () => Navigator.of(context).push(
                  appRoute(
                    name: AppRouteNames.courseRulesSettings,
                    builder: (_) => const CourseRulesSettingsPage(),
                  ),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.settings,
                title: '功能启用',
                onTap: () => Navigator.of(context).push(
                  appRoute(
                    name: AppRouteNames.appearanceSettings,
                    builder: (_) => const AppearanceSettingsPage(),
                  ),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.share2,
                title: '分享码',
                onTap: () => Navigator.of(context).push(
                  appRoute(
                    name: AppRouteNames.configBackup,
                    builder: (_) => const ConfigBackupPage(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '软件信息'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.files,
                title: '附加页面',
                onTap: () => Navigator.of(context).push(
                  appRoute(
                    name: AppRouteNames.extraPages,
                    builder: (_) => const ExtraPagesPage(),
                  ),
                ),
              ),
              ProfileSettingsTile(
                icon: FLucideIcons.bug,
                title: '调试模式',
                value: talker.settings.enabled ? '已开启' : '关闭',
                onTap: _openDebugLogs,
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
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => _logout(context),
            prefix: const Icon(FLucideIcons.logOut),
            child: const Text('退出登录'),
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
                  child: switch (_currentPage) {
                    0 => _buildLoginPanel(theme, isLoading, buttons),
                    1 => _buildVerifyPanel(theme, buttons),
                    _ => _buildPasswordPanel(theme, buttons),
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                // 登录页底部的低调入口：常见问题 / 调试模式。
                // 免责声明仅在首次安装时弹出，不提供常设入口。
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSubtleEntry(
                      theme,
                      icon: FLucideIcons.circleHelp,
                      label: '常见问题',
                      onTap: _openFaq,
                    ),
                    _buildSubtleEntry(
                      theme,
                      icon: FLucideIcons.bug,
                      label: '调试模式',
                      onTap: _openDebugLogs,
                    ),
                  ],
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

  /// Shared low-key icon+text entry so the three login-page shortcuts keep an
  /// identical style.
  Widget _buildSubtleEntry(
    FThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return FTappable(
      onPress: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colors.mutedForeground),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFaq() async {
    await Navigator.of(
      context,
    ).push(appRoute(name: AppRouteNames.faq, builder: (_) => const FaqPage()));
    // 返回登录页后不聚焦任何输入框，避免键盘自动弹出。
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _openDebugLogs() async {
    await Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.debugLogs,
        builder: (context) => TalkerScreen(
          talker: talker,
          appBarTitle: '调试日志',
          isLogOrderReversed: true,
          isLogsExpanded: false,
        ),
      ),
    );
    // 返回登录页后不聚焦任何输入框，避免键盘自动弹出。
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) setState(() {});
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
            onPress: _resetLoading || _codeCountdown > 0
                ? null
                : _sendResetCode,
            child: Text(_codeCountdown > 0 ? '${_codeCountdown}s' : '发送验证码'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('验证码', style: theme.typography.label),
        ),
        const SizedBox(height: AppSpacing.xs),
        // 六位验证码：一格一个字符，支持短信自动填充。
        Center(
          child: FOtpField(
            control: FOtpFieldControl.managed(controller: _codeCtrl),
            focusNode: _codeFocusNode,
            enabled: !_resetLoading,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            style: appOtpFieldStyle,
            onSubmit: (_) => _submitVerify(),
          ),
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
      showAppSnackBar(context, '请输入手机号', severity: ToastSeverity.warning);
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
      showAppSnackBar(context, '验证码已发送', severity: ToastSeverity.success);
      _codeFocusNode.requestFocus();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, e.message, severity: ToastSeverity.error);
    } catch (e, stackTrace) {
      talker.error('密码重置验证码发送异常', e, stackTrace);
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, '发送失败', severity: ToastSeverity.error);
    }
  }

  Future<void> _submitVerify() async {
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (phone.isEmpty) {
      showAppSnackBar(context, '请输入手机号', severity: ToastSeverity.warning);
      return;
    }
    if (code.isEmpty) {
      showAppSnackBar(context, '请输入验证码', severity: ToastSeverity.warning);
      return;
    }

    setState(() => _resetLoading = true);
    try {
      final verifyResult = await _resetService.verifyCode(phone, code);
      if (!mounted) return;

      String? selectedSid;
      final accounts = verifyResult.accounts;
      if (accounts.isEmpty) {
        showAppSnackBar(context, '未找到关联账号', severity: ToastSeverity.error);
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
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: Text('选择账号')),
                ),
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
      showAppSnackBar(context, e.message, severity: ToastSeverity.error);
    } catch (e, stackTrace) {
      talker.error('密码重置身份验证异常', e, stackTrace);
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, '验证失败', severity: ToastSeverity.error);
    }
  }

  Future<void> _submitReset() async {
    final phone = _phoneCtrl.text.trim();
    final pwd = _newPwdCtrl.text;
    final pwd2 = _newPwd2Ctrl.text;

    if (pwd.isEmpty) {
      showAppSnackBar(context, '请输入新密码', severity: ToastSeverity.warning);
      return;
    }
    if (pwd != pwd2) {
      showAppSnackBar(context, '两次密码不一致', severity: ToastSeverity.warning);
      return;
    }
    final valErr = PasswordResetService.validatePassword(pwd);
    if (valErr.isNotEmpty) {
      showAppSnackBar(context, valErr, severity: ToastSeverity.warning);
      return;
    }
    if (_selectedSid == null || _verifyValidateId == null) {
      showAppSnackBar(context, '请先完成验证', severity: ToastSeverity.warning);
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
      showAppSnackBar(
        context,
        '密码重置成功，正在登录...',
        severity: ToastSeverity.success,
      );
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
      showAppSnackBar(context, e.message, severity: ToastSeverity.error);
    } catch (e, stackTrace) {
      talker.error('密码重置异常', e, stackTrace);
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, '重置失败', severity: ToastSeverity.error);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final sid = _sidCtrl.text.trim();
    final pwd = _pwdCtrl.text;

    setState(() => _isLoggingIn = true);
    final prefs = ref.read(preferencesStorageProvider);

    // 1. 先注册 control、拉取校历与课程时间（作息）。登录页已拿到学号，临时
    //    打开 control 通信门禁；任何失败都不阻塞后续教务登录。
    final previousStudentId = prefs.getStudentId();
    ControlService.instance.updateLoginGate(sid);
    try {
      await ControlService.instance.initialize().timeout(
        const Duration(seconds: 4),
      );
      await ControlService.instance
          .refreshSchoolCalendarIfChanged(prefs, force: true)
          .timeout(const Duration(seconds: 4));
    } catch (error, stackTrace) {
      talker.warning('登录前 control 初始化失败', error, stackTrace);
    }

    // 2. OA login. The schedule read defines success, so local persistence and
    //    navigation happen as soon as it returns; exams/grades/book list keep
    //    loading in the background.
    final result = await ref
        .read(authProvider.notifier)
        .login(
          sid,
          pwd,
          onScheduleReady: (loginResult) async {
            try {
              // OA has now supplied the actual college. Its periods can differ
              // from the global calendar loaded before login.
              try {
                await ControlService.instance
                    .refreshSchoolCalendarIfChanged(
                      prefs,
                      college: loginResult.collegeName ?? '',
                    )
                    .timeout(const Duration(seconds: 4));
              } catch (error, stackTrace) {
                talker.warning('登录后刷新学院校历失败', error, stackTrace);
              }
              await CredentialStorage.setSavedPassword(pwd);
              try {
                await ref
                    .read(scheduleProvider.notifier)
                    .updateFromLoginResult(
                      courses: loginResult.courses,
                      studentId: loginResult.studentId ?? sid,
                      studentName: loginResult.studentName ?? '',
                      collegeName: loginResult.collegeName ?? '',
                      className: loginResult.className ?? '',
                      majorName: loginResult.majorName ?? '',
                    );
              } on WidgetSyncException catch (e) {
                if (mounted) {
                  showAppSnackBar(
                    context,
                    '登录成功，但${describeError(e)}',
                    severity: ToastSeverity.warning,
                  );
                }
              }
              if (!mounted) return;
              _pwdCtrl.clear();
              setState(() => _isLoggingIn = false);
              showAppSnackBar(context, '登录成功', severity: ToastSeverity.success);
              HomePage.globalKey.currentState?.switchToTimetable();
            } catch (error, stackTrace) {
              talker.warning('登录后本地保存失败', error, stackTrace);
            }
          },
        );

    if (result != null) {
      // 3. Portal (一卡通/校园网/电费) and control (题库/上报) data continue
      //    in the background after the OA login completes. Disabled
      //    features are skipped entirely so they never issue requests.
      final examResult = result.$2;
      if (examResult != null) {
        await ToolsDataManager.instance.setExams(examResult, prefs);
      }
      final hidden = ref.read(appSettingsProvider).hiddenServiceFeatures;
      bool visible(AppServiceFeature feature) => !hidden.contains(feature);
      unawaited(
        ToolsDataManager.instance.startBackgroundLoading(
          studentId: sid,
          password: pwd,
          prefs: prefs,
          roomId: prefs.getSavedPowerRoomId(),
          displayName: result.$1.studentName ?? '',
          loadYktData: visible(AppServiceFeature.campusCard),
          loadPowerData: visible(AppServiceFeature.power),
          loadRepairData: visible(AppServiceFeature.repair),
          loadNetAuthData: visible(AppServiceFeature.network),
          loadJpData: visible(AppServiceFeature.teacherEvaluation),
        ),
      );
    } else {
      // 登录失败：恢复原有门禁，未登录时不保持 control 通信。
      ControlService.instance.updateLoginGate(previousStudentId);
      if (mounted) {
        setState(() => _isLoggingIn = false);
        final authState = ref.read(authProvider);
        showAppSnackBar(
          context,
          authState.errorMessage ?? '登录失败',
          severity: ToastSeverity.error,
        );
      }
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
      if (mounted) {
        showAppSnackBar(context, '已清除宿舍号', severity: ToastSeverity.info);
      }
      return;
    }

    _isSavingRoom = true;
    late final bool valid;
    try {
      valid = await PowerService().validateRoom(input);
    } catch (error, stackTrace) {
      talker.error('宿舍号本地校验失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '宿舍号校验失败', severity: ToastSeverity.error);
      }
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
      showAppSnackBar(context, '保存成功', severity: ToastSeverity.success);
    } else {
      _roomIdController.clear();
      showAppSnackBar(context, '无此房间号', severity: ToastSeverity.error);
    }
  }

  // ── Logout ──

  void _logout(BuildContext context) {
    unawaited(_logoutAfterConfirmation(context));
  }

  Future<void> _logoutAfterConfirmation(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '退出登录？',
      message: '本地课表数据和个性化样式会被清除，资源中心与已下载文件保留。',
      confirmLabel: '退出',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(scheduleProvider.notifier).clearAll();
    } on WidgetSyncException catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        this.context,
        '已退出登录，但${describeError(e)}',
        severity: ToastSeverity.warning,
      );
    }
    await ref.read(secondaryScheduleProvider.notifier).clear();
    await ref.read(configProvider.notifier).logout();
    ref.read(authProvider.notifier).reset();
  }
}

/// 「发现新版本 x → y」入口：点击进入版本更新二级页面
/// （上方下载模块，下方更新日志模块）。不自动弹出任何通知。
class _ProfileUpdateCard extends ConsumerStatefulWidget {
  const _ProfileUpdateCard();

  @override
  ConsumerState<_ProfileUpdateCard> createState() => _ProfileUpdateCardState();
}

class _ProfileUpdateCardState extends ConsumerState<_ProfileUpdateCard> {
  bool _loading = true;
  ControlRelease? _release;
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final info = await PackageInfo.fromPlatform();
    final prefs = ref.read(preferencesStorageProvider);
    final cached = ControlService.instance.cachedRelease(prefs, info.version);
    if (cached != null && mounted) {
      setState(() {
        _release = cached;
        _currentVersion = info.version;
        _loading = false;
      });
    }
    final result = await ControlService.instance.checkForUpdateState(
      prefs: prefs,
    );
    if (!mounted) return;
    setState(() {
      // Keep showing the cached release when control was unreachable; only
      // an answer from the server may remove the update card.
      if (result.reachable) _release = result.release;
      _currentVersion = info.version;
      _loading = false;
    });
  }

  void _openUpdatePage() {
    final release = _release;
    if (release == null) return;
    unawaited(
      Navigator.of(context).push(
        appRoute(
          name: AppRouteNames.appUpdate,
          builder: (_) =>
              AppUpdatePage(release: release, currentVersion: _currentVersion),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final release = _release;
    if (_loading || release == null) return const SizedBox.shrink();
    // 按钮样式入口：左侧下载图标 +「发现新版本」，右侧「当前 → 最新」。
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: FTappable(
        onPress: _openUpdatePage,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colors.primary.withValues(alpha: 0.08),
            border: Border.all(color: theme.colors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                FLucideIcons.download,
                size: 18,
                color: theme.colors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('发现新版本', style: theme.typography.bodyText),
              const Spacer(),
              Text(
                '$_currentVersion → ${release.latestVersion}',
                style: theme.typography.bodySmall.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
