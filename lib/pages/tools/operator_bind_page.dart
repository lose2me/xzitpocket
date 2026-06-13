import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../services/cas_service.dart';
import '../../services/netauth_service.dart';
import '../../utils/snackbar_helper.dart';

class OperatorBindPage extends StatefulWidget {
  final String account;
  final String password;

  const OperatorBindPage({
    super.key,
    required this.account,
    required this.password,
  });

  @override
  State<OperatorBindPage> createState() => _OperatorBindPageState();
}

class _OperatorBindPageState extends State<OperatorBindPage> {
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
    _loadTutorial(_selectedIndex);
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
    _loadTutorial(index);
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
    } on AuthException catch (e) {
      if (mounted) showAppSnackBar(context, e.message);
    } catch (_) {
      if (mounted) showAppSnackBar(context, '绑定失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tutorial = _tutorials[_selectedIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('绑定运营商'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSegmentedBar(theme),
              const SizedBox(height: 20),
              TextField(
                controller: _acctCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '宽带账号',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pwdCtrl,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_loading) _submit();
                },
                decoration: const InputDecoration(
                  labelText: '宽带密码',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('绑定'),
                ),
              ),
              if (tutorial != null && tutorial.trim().isNotEmpty) ...[
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 16),
                MarkdownBody(
                  data: tutorial,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium,
                    h1: theme.textTheme.titleLarge,
                    h2: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedBar(ThemeData theme) {
    const dur = Duration(milliseconds: 350);
    const curve = Curves.easeInOutCubic;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;
    final surfaceVariant = theme.colorScheme.surfaceContainerHighest;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / _carriers.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: dur,
                curve: curve,
                left: segmentWidth * _selectedIndex,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Row(
                children: List.generate(_carriers.length, (i) {
                  final selected = i == _selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _switchCarrier(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: dur,
                          curve: curve,
                          style: TextStyle(
                            color: selected ? onPrimary : primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          child: Text(_carriers[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
