import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/config_provider.dart';
import '../../services/cas_service.dart';
import '../../services/jp_service.dart';
import '../../services/credential_storage.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/snackbar_helper.dart';

class JpPage extends ConsumerStatefulWidget {
  const JpPage({super.key, this.result});

  final JpStatusResult? result;

  @override
  ConsumerState<JpPage> createState() => _JpPageState();
}

class _JpPageState extends ConsumerState<JpPage> {
  final _jpService = JpService();
  final _manager = ToolsDataManager.instance;
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
    _manager.addListener(_onCampusNetworkChanged);
    if (widget.result != null) {
      _status = widget.result;
    } else {
      unawaited(_loadStatus());
    }
  }

  @override
  void dispose() {
    _manager.removeListener(_onCampusNetworkChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onCampusNetworkChanged() {
    if (mounted) setState(() {});
  }

  bool get _campusAvailable => _manager.isCampusNetworkAvailable;

  bool _requireCampusNetwork() {
    if (_campusAvailable) return true;
    if (mounted) {
      showAppSnackBar(
        context,
        _manager.campusNetworkStatus == CampusNetworkStatus.checking
            ? '正在检测校园网，请稍后再试'
            : '请连接校园网',
      );
    }
    return false;
  }

  Future<void> _loadStatus() async {
    if (_isLoading) return;
    if (!_requireCampusNetwork()) return;
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) return;
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) return;
    if (!_requireCampusNetwork()) return;
    final prefs = ref.read(preferencesStorageProvider);

    setState(() => _isLoading = true);
    try {
      final result = await _manager.refreshJp(
        config.studentId!,
        password,
        prefs,
      );
      if (!mounted) return;
      if (result == null) {
        showAppSnackBar(context, '查询失败');
        return;
      }
      setState(() {
        _status = result;
        _currentPage = 0;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    } on AuthException catch (e, stackTrace) {
      talker.error('教师评价详情刷新失败', e, stackTrace);
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      if (!mounted) return;
      talker.error('教师评价查询异常', e, stackTrace);
      showAppSnackBar(context, '查询失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _autoEvaluate(JpTask task) async {
    if (!_requireCampusNetwork()) return;
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) return;
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) return;
    if (!_requireCampusNetwork()) return;

    if (!mounted) return;
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
    if (!_requireCampusNetwork()) return;

    setState(() => _isEvaluating = true);
    try {
      JpAutoResult result;
      try {
        result = await _jpService.autoEvaluate(config.studentId!, password);
      } on AuthException {
        await Future.delayed(const Duration(seconds: 1));
        if (!_requireCampusNetwork()) return;
        result = await _jpService.autoEvaluate(config.studentId!, password);
      }
      if (!mounted) return;

      if (result.evaluated.isEmpty) {
        final detail = result.skipped.isEmpty
            ? '没有待评课程'
            : '没有待评课程 (跳过${result.skipped.length}门)';
        talker.info(
          '[ACTION] 评教结果\n已评=0, 跳过=${result.skipped.length}: '
          '${result.skipped.join(', ')}',
        );
        showAppSnackBar(context, detail);
      } else {
        showAppSnackBar(context, '已评 ${result.evaluated.length} 门课');
      }
      await _loadStatus();
    } on AuthException catch (e, stackTrace) {
      talker.error('教师评价自动评教失败', e, stackTrace);
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      if (!mounted) return;
      talker.error('教师评价自动评教异常', e, stackTrace);
      showAppSnackBar(context, '评教失败: $e');
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
      appBar: AppBar(
        title: const Text('教师评价'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading || !_campusAvailable ? null : _loadStatus,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
        bottom: !_campusAvailable
            ? PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _manager.campusNetworkStatus == CampusNetworkStatus.checking
                        ? '正在检测校园网，教师评价暂不可用'
                        : '未连接校园网，教师评价暂不可用',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : tasks.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemBuilder: (_, i) => _buildTaskPage(theme, tasks[i]),
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
                onPressed:
                    _isEvaluating || task.pending == 0 || !_campusAvailable
                    ? null
                    : () => _autoEvaluate(task),
                icon: _isEvaluating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.thumb_up_outlined),
                label: Text(task.pending > 0 ? '给恩师们点赞' : '已全部完成'),
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
              ...task.courses.map(
                (c) => Padding(
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
                ),
              ),
            ],
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            ),
          ],
        ),
      ),
    );
  }
}
