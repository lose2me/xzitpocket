import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';

/// 弹出登录对话框
Future<void> showLoginDialog(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _LoginSheet(),
  );
}

class _LoginSheet extends ConsumerStatefulWidget {
  const _LoginSheet();

  @override
  ConsumerState<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<_LoginSheet> {
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
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽指示条
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // 标题
                Text(
                  '登录教务系统',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '使用学号和密码登录以同步课表',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),

                // 学号
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
                  validator: (v) =>
                      v == null || v.isEmpty ? '请输入学号' : null,
                ),
                const SizedBox(height: 16),

                // 密码
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
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? '请输入密码' : null,
                ),

                // 错误提示
                if (authState.status == AuthStatus.error) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withAlpha(120),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authState.errorMessage ?? '登录失败',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // 登录按钮
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: isLoading ? null : _login,
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('登录', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final sid = _sidCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final result = await ref.read(authProvider.notifier).login(sid, pwd);
    if (result != null) {
      final storage = ref.read(storageServiceProvider);
      await storage.setStudentId(sid);
      await storage.setSavedPassword(pwd);

      await ref.read(scheduleProvider.notifier).updateFromLoginResult(
            courses: result.courses,
            studentId: result.studentId ?? sid,
            studentName: result.studentName ?? '',
          );

      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('登录成功，课表已同步')),
        );
      }
    }
  }
}
