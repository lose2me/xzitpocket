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
import '../../services/debug_log_service.dart';
import '../../services/native_automation_service.dart';
import '../../services/power_service.dart';
import '../../services/tools_data_manager.dart';
import '../../services/update_service.dart';
import '../../services/widget_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../services/cas_service.dart';
import '../../services/password_reset_service.dart';
import '../home_page.dart';
import '../timetable/timetable_providers.dart';
import 'debug_page.dart';

class MePage extends ConsumerStatefulWidget {
  const MePage({super.key});

  static final globalKey = GlobalKey<MePageState>();

  @override
  ConsumerState<MePage> createState() => MePageState();
}

class MePageState extends ConsumerState<MePage> {
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
  bool _codeSent = false;
  bool _obscureNew1 = true;
  bool _obscureNew2 = true;
  int _currentPage = 0;
  String? _verifyValidateId;
  String? _selectedSid;

  final _roomIdController = TextEditingController();
  bool _roomIdInitialized = false;
  bool _isValidatingRoom = false;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _sidCtrl.dispose();
    _pwdCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _newPwdCtrl.dispose();
    _newPwd2Ctrl.dispose();
    _codeFocusNode.dispose();
    _resetService.dispose();
    _roomIdController.dispose();
    super.dispose();
  }

  void resetUnsavedRoomId() {
    final saved = ref.read(savedRoomIdProvider) ?? '';
    if (_roomIdController.text.trim() != saved) {
      _roomIdController.text = saved;
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(configProvider);
    final isLoggedIn =
        config.studentId != null && config.studentId!.isNotEmpty;

    if (!isLoggedIn || _isLoggingIn) {
      return Scaffold(
        body: SafeArea(child: _buildLoginForm(theme)),
      );
    }

    final settings = ref.watch(appSettingsProvider);
    final showNonCurrentWeekCourses =
        ref.watch(showNonCurrentWeekCoursesProvider);
    final showWeekendColumns = ref.watch(showWeekendColumnsProvider);
    final savedRoomId = ref.watch(savedRoomIdProvider);

    if (!_roomIdInitialized) {
      _roomIdController.text = savedRoomId ?? '';
      _roomIdInitialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('掌上徐工'),
            const SizedBox(height: 4),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '';
                const buildChannel = String.fromEnvironment('BUILD_CHANNEL');
                final suffix = buildChannel == 'dev' ? 'Dev' : '';
                return Text(
                  'Ver: $version$suffix License: GPL-3.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
        children: [
          _SectionLabel(title: '用户信息'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.badge_outlined,
                title: '学号',
                value: config.studentId ?? '',
              ),
              _SettingsTile(
                icon: Icons.person_outline,
                title: '姓名',
                value: config.studentName ?? '',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel(title: '补充信息'),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.apartment_outlined, size: 23, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 16),
                    Text(
                      '宿舍号',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Spacer(),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _roomIdController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: '未设置',
                          hintStyle: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onSubmitted: (_) => _submitRoomId(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isValidatingRoom)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.save_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: _submitRoomId,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel(title: '课表'),
          _SettingsCard(
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
                        '隐藏周末网格',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Checkbox(
                      value: !showWeekendColumns,
                      onChanged: (v) => ref.read(showWeekendColumnsProvider.notifier).set(!(v ?? false)),
                    ),
                  ],
                ),
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
          const SizedBox(height: 16),
          _SectionLabel(title: '软件信息'),
          _SettingsCard(
            children: [
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '';
                  return _SettingsTile(
                    icon: Icons.system_update_outlined,
                    title: '版本更新',
                    value: version,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _VersionPage()),
                    ),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.bug_report_outlined,
                title: '调试模式',
                value: DebugLogService.instance.enabled ? '已开启' : '关闭',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DebugPage()),
                  );
                  setState(() {});
                },
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: '开源许可证',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '掌上徐工',
                  applicationLegalese: 'GPL-3.0 License',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
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
        ],
      ),
    );
  }

  // ── Login form ──

  Widget _buildLoginForm(ThemeData theme) {
    final authState = ref.watch(authProvider);
    final isLoading = _isLoggingIn || authState.status == AuthStatus.loading;
    final buttons = _buildSegmentedButtons(theme, authState, isLoading);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _buildOpenSourceInfo(theme),
        ),
        Expanded(
          child: IndexedStack(
            index: _currentPage,
            children: [
              _buildLoginPanel(theme, authState, isLoading, buttons),
              _buildVerifyPanel(theme, buttons),
              _buildPasswordPanel(theme, buttons),
            ],
          ),
        ),
      ],
    );
  }

  void _switchPage(int page) {
    setState(() => _currentPage = page);
  }

  Widget _buildSegmentedButtons(
      ThemeData theme, dynamic authState, bool isLoading) {
    const dur = Duration(milliseconds: 350);
    const curve = Curves.easeInOutCubic;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;
    final surfaceVariant = theme.colorScheme.surfaceContainerHighest;
    final onReset = _currentPage > 0;

    final rightLabel =
        _currentPage == 0 ? '找回密码' : (_currentPage == 1 ? '验证' : '确定');
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

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: dur,
                curve: curve,
                left: onReset ? halfWidth : 0,
                top: 0,
                bottom: 0,
                width: halfWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReset
                          ? (_resetLoading ? null : () => _switchPage(0))
                          : (isLoading ? null : _login),
                      child: Center(
                        child: leftLoading
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: onPrimary,
                                ),
                              )
                            : AnimatedDefaultTextStyle(
                                duration: dur,
                                curve: curve,
                                style: TextStyle(
                                  color: onReset ? primary : onPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                child: const Text('登录'),
                              ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: rightAction,
                      child: Center(
                        child: rightLoading
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: onPrimary,
                                ),
                              )
                            : AnimatedDefaultTextStyle(
                                duration: dur,
                                curve: curve,
                                style: TextStyle(
                                  color: onReset ? onPrimary : primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                child: Text(rightLabel),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginPanel(
      ThemeData theme, dynamic authState, bool isLoading, Widget buttons) {
    return Align(
      alignment: const Alignment(0, -0.3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('统一身份认证', style: theme.textTheme.titleLarge),
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
              const SizedBox(height: 24),
              buttons,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyPanel(ThemeData theme, Widget buttons) {
    return Align(
      alignment: const Alignment(0, -0.3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('找回密码', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '手机号',
                hintText: '请输入绑定的手机号',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton(
                    onPressed:
                        _resetLoading || _codeSent ? null : _sendResetCode,
                    child: Text(_codeSent ? '已发送' : '发送验证码'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              focusNode: _codeFocusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitVerify(),
              decoration: const InputDecoration(
                labelText: '验证码',
                hintText: '请输入短信验证码',
                prefixIcon: Icon(Icons.sms_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            buttons,
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordPanel(ThemeData theme, Widget buttons) {
    return Align(
      alignment: const Alignment(0, -0.3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('设置新密码', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            TextField(
              controller: _newPwdCtrl,
              obscureText: _obscureNew1,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '新密码',
                hintText: '至少10位，含大小写、数字、特殊字符',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew1
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscureNew1 = !_obscureNew1),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPwd2Ctrl,
              obscureText: _obscureNew2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitReset(),
              decoration: InputDecoration(
                labelText: '确认密码',
                hintText: '再次输入新密码',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew2
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscureNew2 = !_obscureNew2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            buttons,
          ],
        ),
      ),
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
        _codeSent = true;
        _resetLoading = false;
      });
      showAppSnackBar(context, '验证码已发送');
      _codeFocusNode.requestFocus();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, e.message);
    } catch (_) {
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
        selectedSid = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('选择账号'),
            children: accounts
                .map((a) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, a.sid),
                      child: Text(a.info.isNotEmpty
                          ? '${a.sid} (${a.info})'
                          : a.sid),
                    ))
                .toList(),
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
    } catch (_) {
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
          phone, pwd, _selectedSid!, _verifyValidateId!);
      if (!mounted) return;
      showAppSnackBar(context, '密码重置成功，正在登录...');
      _phoneCtrl.clear();
      _codeCtrl.clear();
      _newPwdCtrl.clear();
      _newPwd2Ctrl.clear();
      setState(() {
        _codeSent = false;
        _resetLoading = false;
        _verifyValidateId = null;
      });

      _sidCtrl.text = _selectedSid!;
      _pwdCtrl.text = pwd;
      _selectedSid = null;
      _switchPage(0);
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      _login();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _resetLoading = false);
      showAppSnackBar(context, e.message);
    } catch (_) {
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
    _pwdCtrl.clear();
    if (result != null) {
      final (loginResult, examResult) = result;
      await CredentialStorage.setSavedPassword(pwd);

      ToolsDataManager.instance.setExams(examResult,
          ref.read(preferencesStorageProvider));

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

      if (mounted) {
        setState(() => _isLoggingIn = false);
        showAppSnackBar(context, '登录成功');
        HomePage.globalKey.currentState?.switchToTimetable();
      }

      final prefs = ref.read(preferencesStorageProvider);
      ToolsDataManager.instance.startBackgroundLoading(
        studentId: sid,
        password: pwd,
        prefs: prefs,
        roomId: prefs.getSavedPowerRoomId(),
      );
    } else if (mounted) {
      setState(() => _isLoggingIn = false);
      final authState = ref.read(authProvider);
      showAppSnackBar(context, authState.errorMessage ?? '登录失败');
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
            const buildChannel = String.fromEnvironment('BUILD_CHANNEL');
            final suffix = buildChannel == 'dev' ? 'Dev' : '';
            return Text(
              'Ver: $version$suffix License: GPL-3.0',
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
    final input = _roomIdController.text.trim();
    if (input.isEmpty) {
      final prefs = ref.read(preferencesStorageProvider);
      await prefs.setSavedPowerRoomId('');
      await prefs.clearPowerCache();
      ref.read(savedRoomIdProvider.notifier).set(null);
      if (mounted) showAppSnackBar(context, '已清除宿舍号');
      return;
    }

    setState(() => _isValidatingRoom = true);
    final valid = await PowerService().validateRoom(input);
    if (!mounted) return;
    setState(() => _isValidatingRoom = false);

    if (valid) {
      final upper = input.toUpperCase();
      _roomIdController.text = upper;
      final prefs = ref.read(preferencesStorageProvider);
      await prefs.setSavedPowerRoomId(upper);
      await prefs.clearPowerCache();
      ref.read(savedRoomIdProvider.notifier).set(upper);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      showAppSnackBar(context, '保存成功');
    } else {
      showAppSnackBar(context, '无此房间号');
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
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveValueColor =
        theme.colorScheme.onSurfaceVariant.withAlpha(200);

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
                  if (onTap != null)
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
                    _buildProgressLine(_progress),
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

}

class _VersionPage extends StatefulWidget {
  const _VersionPage();

  @override
  State<_VersionPage> createState() => _VersionPageState();
}

class _VersionPageState extends State<_VersionPage> {
  bool _isChecking = true;
  String? _error;
  UpdateCheckResult? _result;
  String _currentVersion = '';

  // Inline download state
  bool _isDownloading = false;
  UpdateDownloadProgress _downloadProgress = const UpdateDownloadProgress(
    stage: UpdateDownloadStage.preparing,
  );
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _loadVersionAndCheck();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _loadVersionAndCheck() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _currentVersion = info.version);
    await _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (!UpgradeConfig.isConfigured) {
      setState(() => _isChecking = false);
      return;
    }
    setState(() {
      _isChecking = true;
      _error = null;
    });
    try {
      final result = await UpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _result = result;
        _isChecking = false;
      });
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isChecking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '检查更新失败';
        _isChecking = false;
      });
    }
  }

  Future<void> _startDownload() async {
    final updateInfo = _result?.updateInfo;
    if (updateInfo == null) return;

    if (!await UpdateService.canInstallPackages()) {
      await UpdateService.requestInstallPermission();
      if (!mounted) return;
      if (!await UpdateService.canInstallPackages()) {
        if (mounted) showAppSnackBar(context, '需要允许安装未知应用才能更新');
        return;
      }
    }

    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    setState(() {
      _isDownloading = true;
      _cancelToken = cancelToken;
      _downloadProgress = const UpdateDownloadProgress(
        stage: UpdateDownloadStage.preparing,
        message: '准备下载更新包',
      );
    });

    try {
      await UpdateService.downloadAndInstallUpdate(
        updateInfo,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _isDownloading = false);
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      if (!e.message.contains('取消')) {
        showAppSnackBar(context, e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      showAppSnackBar(context, '下载更新失败，请稍后重试');
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    setState(() => _isDownloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUpdate = _result?.hasUpdate == true && _result?.updateInfo != null;
    final updateInfo = _result?.updateInfo;

    final scrollBody = SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          Icon(Icons.code, size: 36, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'github.com/lose2me/xzitpocket',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasUpdate
                ? 'Ver $_currentVersion → ${updateInfo!.versionName}'
                : 'Ver $_currentVersion  |  License: GPL-3.0',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: hasUpdate
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withAlpha(150),
              fontWeight: hasUpdate ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 24),
          if (_isChecking)
            const CircularProgressIndicator()
          else if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _checkForUpdate,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ] else if (hasUpdate) ...[
            if (updateInfo!.releaseNotes.trim().isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '更新说明',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withAlpha(100),
                  ),
                ),
                child: Text(
                  updateInfo.releaseNotes.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isDownloading ? _cancelDownload : _startDownload,
                icon: Icon(_isDownloading
                    ? Icons.close
                    : Icons.system_update_alt_outlined),
                label: Text(_isDownloading ? '取消' : '立即更新'),
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              _buildDownloadProgress(theme),
            ],
          ] else
            Text(
              UpgradeConfig.isConfigured ? '当前已是最新版本' : '升级服务未配置',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
        ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('版本更新'), centerTitle: true),
      body: Align(alignment: Alignment.topCenter, child: scrollBody),
    );
  }

  Widget _buildDownloadProgress(ThemeData theme) {
    final progressValue = _downloadProgress.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: progressValue),
        const SizedBox(height: 8),
        Text(
          _downloadProgress.message ?? '',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          _buildProgressLine(_downloadProgress),
          style: theme.textTheme.bodySmall,
        ),
        if (_downloadProgress.stage == UpdateDownloadStage.downloading) ...[
          const SizedBox(height: 2),
          Text(
            '速率: ${_formatSpeed(_downloadProgress.bytesPerSecond)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Shared download-progress helpers ──

String _buildProgressLine(UpdateDownloadProgress p) {
  if (p.stage == UpdateDownloadStage.installing) {
    return '已下载 ${_formatBytes(p.receivedBytes)}';
  }
  final received = _formatBytes(p.receivedBytes);
  if (p.totalBytes > 0) {
    final total = _formatBytes(p.totalBytes);
    final percent = ((p.progress ?? 0) * 100).clamp(0.0, 100.0);
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
