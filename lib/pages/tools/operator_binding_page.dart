import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../../services/cas_service.dart';
import '../../services/netauth_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import '../../ui/app_markdown.dart';

class OperatorBindingPage extends StatefulWidget {
  final String account;
  final String password;

  const OperatorBindingPage({
    super.key,
    required this.account,
    required this.password,
  });

  @override
  State<OperatorBindingPage> createState() => _OperatorBindingPageState();
}

class _OperatorBindingPageState extends State<OperatorBindingPage> {
  static const _carriers = ['电信', '联通', '移动'];
  static const _tutorialAssets = [
    'assets/tutorials/bind_dianxin.md',
    'assets/tutorials/bind_liantong.md',
    'assets/tutorials/bind_yidong.md',
  ];

  int _selectedIndex = 0;
  final _acctCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;
  final _tutorials = <int, String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadTutorial(_selectedIndex));
  }

  Future<void> _loadTutorial(int index) async {
    if (_tutorials.containsKey(index)) return;
    final content = await rootBundle.loadString(_tutorialAssets[index]);
    if (mounted) setState(() => _tutorials[index] = content);
  }

  @override
  void dispose() {
    _acctCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _switchCarrier(int index) {
    if (index == _selectedIndex || _loading) return;
    setState(() {
      _selectedIndex = index;
      _acctCtrl.clear();
      _pwdCtrl.clear();
    });
    unawaited(_loadTutorial(index));
  }

  Future<void> _submit() async {
    final acct = _acctCtrl.text.trim();
    final pwd = _pwdCtrl.text.trim();
    if (acct.isEmpty || pwd.isEmpty) {
      showAppSnackBar(context, '请填写宽带账号和密码', severity: ToastSeverity.warning);
      return;
    }

    setState(() => _loading = true);
    try {
      final msg = await NetAuthService().bindOperator(
        widget.account,
        widget.password,
        carrier: _carriers[_selectedIndex],
        broadbandAccount: acct,
        broadbandPassword: pwd,
      );
      if (!mounted) return;
      showAppSnackBar(context, msg, severity: ToastSeverity.success);
      Navigator.of(context).pop();
    } on AuthException catch (e, stackTrace) {
      talker.error('运营商绑定失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, e.message, severity: ToastSeverity.error);
      }
    } catch (e, stackTrace) {
      talker.error('运营商绑定异常', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '绑定失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 与「学业情况」一致的 FTabs 样式（需求 22）；提交中不允许切换。
    return AppPage(
      title: '绑定运营商',
      child: FTabs(
        expands: true,
        // 只允许点击切换 Tab，不支持左右滑动（保留切换动画）。
        contentPhysics: const NeverScrollableScrollPhysics(),
        control: FTabControl.lifted(
          index: _selectedIndex,
          onChange: _loading ? (_) {} : _switchCarrier,
        ),
        children: [
          for (var index = 0; index < _carriers.length; index++)
            FTabEntry(
              label: Text(_carriers[index]),
              child: _buildCarrierForm(index),
            ),
        ],
      ),
    );
  }

  Widget _buildCarrierForm(int index) {
    final tutorial = _tutorials[index];
    return AppPageListView(
      maxWidth: AppLayout.formMaxWidth,
      bottomPadding: AppSpacing.xxl,
      safeArea: false,
      children: [
        AppTextField(
          controller: _acctCtrl,
          label: '宽带账号',
          prefix: const Icon(FLucideIcons.userRound),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _pwdCtrl,
          label: '宽带密码',
          prefix: const Icon(FLucideIcons.lockKeyhole),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_loading) unawaited(_submit());
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        FButton(
          onPress: _loading ? null : _submit,
          prefix: _loading
              ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
              : null,
          child: const Text('绑定'),
        ),
        if (tutorial != null && tutorial.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          const FDivider(),
          const SizedBox(height: AppSpacing.lg),
          AppMarkdown(data: tutorial),
        ],
      ],
    );
  }
}
