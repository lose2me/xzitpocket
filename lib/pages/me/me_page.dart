import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import 'login_form.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final isLoggedIn =
        config.studentId != null && config.studentId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isLoggedIn
                  ? Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            config.studentName?.isNotEmpty == true
                                ? config.studentName![0]
                                : '?',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.studentName ?? '',
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '学号: ${config.studentId}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    )
                  : const Center(
                      child: Text('未登录',
                          style: TextStyle(color: Colors.grey)),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Login / Sync section
          if (!isLoggedIn) ...[
            FilledButton.icon(
              onPressed: () => showLoginDialog(context),
              icon: const Icon(Icons.login),
              label: const Text('登录'),
            ),
            const SizedBox(height: 16),
          ] else ...[
            FilledButton.icon(
              onPressed: () => _syncSchedule(context, ref),
              icon: const Icon(Icons.sync),
              label: const Text('同步课表'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _logout(context, ref),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('退出登录',
                  style: TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 16),
          ],

          // About
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              subtitle: const Text('掌上徐工 v1.0.0'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: '掌上徐工',
                  applicationVersion: '1.0.0',
                  children: [
                    const Text('徐州工程学院掌上校园应用'),
                    const SizedBox(height: 8),
                    const Text('基于教务系统数据，提供课表查看与管理功能。'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncSchedule(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    final sid = storage.getStudentId();
    final pwd = storage.getSavedPassword();
    if (sid == null || pwd == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
      return;
    }

    final result = await ref.read(authProvider.notifier).login(sid, pwd);
    if (result != null) {
      await ref.read(scheduleProvider.notifier).updateFromLoginResult(
            courses: result.courses,
            studentId: result.studentId ?? sid,
            studentName: result.studentName ?? '',
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('同步成功')),
        );
      }
    } else {
      final authState = ref.read(authProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authState.errorMessage ?? '同步失败')),
        );
      }
    }
  }

  void _logout(BuildContext context, WidgetRef ref) {
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
            onPressed: () {
              ref.read(configProvider.notifier).logout();
              ref.read(scheduleProvider.notifier).clearAll();
              ref.read(authProvider.notifier).reset();
              Navigator.pop(ctx);
            },
            child:
                const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
