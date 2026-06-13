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
  int _currentPage = 0;
  final _pageController = PageController();

  List<JpTask> get _sortedTasks {
    if (_status == null) return [];
    final tasks = List<JpTask>.from(_status!.tasks);
    tasks.sort((a, b) {
      if (a.status == '进行中' && b.status != '进行中') return -1;
      if (a.status != '进行中' && b.status == '进行中') return 1;
      return 0;
    });
    return tasks;
  }

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
      setState(() {
        _status = result;
        _currentPage = 0;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
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

  Future<void> _autoEvaluate(JpTask task) async {
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

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = _sortedTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('教师评价'), centerTitle: true),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rate_review_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          '暂无评教任务',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: tasks.length,
                          onPageChanged: (i) =>
                              setState(() => _currentPage = i),
                          itemBuilder: (_, i) =>
                              _buildTaskPage(theme, tasks[i]),
                        ),
                      ),
                      if (tasks.length > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 0
                                    ? () => _goToPage(_currentPage - 1)
                                    : null,
                              ),
                              Text(
                                '${_currentPage + 1} / ${tasks.length}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentPage < tasks.length - 1
                                    ? () => _goToPage(_currentPage + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTaskPage(ThemeData theme, JpTask task) {
    return RefreshIndicator(
      onRefresh: _loadStatus,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildTaskCard(theme, task),
          if (task.status == '进行中') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isEvaluating || task.pending == 0
                    ? null
                    : () => _autoEvaluate(task),
                icon: _isEvaluating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.thumb_up_outlined),
                label: Text(
                    task.pending > 0 ? '给恩师们点赞' : '已全部完成'),
              ),
            ),
          ],
        ],
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.taskName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: task.status == '进行中'
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: task.status == '进行中'
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
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
