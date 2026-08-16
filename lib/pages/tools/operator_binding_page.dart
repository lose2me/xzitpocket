import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:forui/forui.dart';

import '../../services/cas_service.dart';
import '../../services/netauth_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

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
  static const _carriers = ['电信', '移动', '联通'];
  static const _tutorialAssets = [
    'assets/tutorials/bind_dianxin.md',
    'assets/tutorials/bind_yidong.md',
    'assets/tutorials/bind_liantong.md',
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
      showAppSnackBar(context, '请填写宽带账号和密码');
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
      showAppSnackBar(context, msg);
      Navigator.of(context).pop();
    } on AuthException catch (e, stackTrace) {
      talker.error('运营商绑定失败', e, stackTrace);
      if (mounted) showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      talker.error('运营商绑定异常', e, stackTrace);
      if (mounted) showAppSnackBar(context, '绑定失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tutorial = _tutorials[_selectedIndex];

    return AppPage(
      title: '绑定运营商',
      child: AppPageListView(
        maxWidth: AppLayout.formMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.section,
        children: [
          _buildSegmentedBar(theme),
          const SizedBox(height: 20),
          AppTextField(
            controller: _acctCtrl,
            label: '宽带账号',
            prefix: const Icon(FLucideIcons.userRound),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FButton(
              onPress: _loading ? null : _submit,
              prefix: _loading
                  ? const FCircularProgress(
                      size: FCircularProgressSizeVariant.sm,
                    )
                  : null,
              child: const Text('绑定'),
            ),
          ),
          if (tutorial != null && tutorial.trim().isNotEmpty) ...[
            const SizedBox(height: 28),
            const FDivider(),
            const SizedBox(height: 16),
            MarkdownBody(
              data: tutorial,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: theme.typography.bodyText.copyWith(
                  color: theme.colors.foreground,
                ),
                h1: theme.typography.pageTitle.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
                h2: theme.typography.tileTitle.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
                h3: theme.typography.sectionTitle.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
                code: theme.typography.body.sm.copyWith(
                  color: theme.colors.foreground,
                  fontFamily: 'monospace',
                  backgroundColor: theme.colors.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedBar(FThemeData theme) {
    return Row(
      children: List.generate(_carriers.length, (i) {
        final selected = i == _selectedIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: i == _carriers.length - 1 ? 0 : AppSpacing.sm,
            ),
            child: FButton(
              variant: selected
                  ? FButtonVariant.primary
                  : FButtonVariant.outline,
              onPress: _loading ? null : () => _switchCarrier(i),
              child: Text(_carriers[i]),
            ),
          ),
        );
      }),
    );
  }
}
