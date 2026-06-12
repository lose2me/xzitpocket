import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/config_provider.dart';
import '../../services/cas_service.dart';
import '../../services/jp_service.dart';
import '../../services/credential_storage.dart';
import '../../utils/snackbar_helper.dart';

class JpPage extends ConsumerStatefulWidget {
  const JpPage({super.key});

  @override
  ConsumerState<JpPage> createState() => _JpPageState();
}

class _JpPageState extends ConsumerState<JpPage> {
  final _jpService = JpService();
  bool _isLoading = false;
  bool _isEvaluating = false;
  JpStatusResult? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  JpTask? get _activeTask {
    if (_status == null) return null;
    final active = _status!.tasks.where((t) => t.status == '进行中');
    return active.isNotEmpty ? active.first : null;
  }

  Future<void> _loadStatus() async {
    if (_isLoading) return;
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) return;
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      JpStatusResult result;
      try {
        result = await _jpService.queryStatus(config.studentId!, password);
      } on AuthException {
        await Future.delayed(const Duration(seconds: 1));
        result = await _jpService.queryStatus(config.studentId!, password);
      }
      if (!mounted) return;
      setState(() => _status = result);
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '查询失败');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _autoEvaluate() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) return;
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('给恩师们点赞'),
        content: const Text('将自动对所有未评课程给予满分评价，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isEvaluating = true);
    try {
      JpAutoResult result;
      try {
        result = await _jpService.autoEvaluate(config.studentId!, password);
      } on AuthException {
        await Future.delayed(const Duration(seconds: 1));
        result = await _jpService.autoEvaluate(config.studentId!, password);
      }
      if (!mounted) return;

      final msg = result.evaluated.isEmpty
          ? '没有待评课程'
          : '已评 ${result.evaluated.length} 门课';
      showAppSnackBar(context, msg);
      await _loadStatus();
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '评教失败');
    } finally {
      if (mounted) setState(() => _isEvaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = _activeTask;

    return Scaffold(
      appBar: AppBar(title: const Text('教师评价'), centerTitle: true),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : task == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rate_review_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          '暂无进行中的评教任务',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadStatus,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _buildTaskCard(theme, task),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isEvaluating || task.pending == 0
                                ? null
                                : _autoEvaluate,
                            icon: _isEvaluating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.thumb_up_outlined),
                            label: Text(task.pending > 0
                                ? '给恩师们点赞'
                                : '已全部完成'),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildTaskCard(ThemeData theme, JpTask task) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.taskName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${task.startTime} ~ ${task.endTime}  ${task.completed}/${task.total}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (task.courses.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...task.courses.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          c.done
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: c.done
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${c.courseName}(${c.teacherName})',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
