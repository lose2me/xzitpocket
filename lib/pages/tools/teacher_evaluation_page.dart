import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../providers/config_provider.dart';
import '../../services/cas_service.dart';
import '../../services/jp_service.dart';
import '../../services/credential_storage.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

class TeacherEvaluationPage extends ConsumerStatefulWidget {
  const TeacherEvaluationPage({super.key, this.result});

  final JpStatusResult? result;

  @override
  ConsumerState<TeacherEvaluationPage> createState() =>
      _TeacherEvaluationPageState();
}

class _TeacherEvaluationPageState extends ConsumerState<TeacherEvaluationPage> {
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
        severity: ToastSeverity.warning,
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
        showAppSnackBar(context, '查询失败', severity: ToastSeverity.error);
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
      showAppSnackBar(context, e.message, severity: ToastSeverity.error);
    } catch (e, stackTrace) {
      if (!mounted) return;
      talker.error('教师评价查询异常', e, stackTrace);
      showAppSnackBar(context, '查询失败: $e', severity: ToastSeverity.error);
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
    final confirm = await showAppConfirmDialog(
      context: context,
      title: '给恩师们点赞',
      message: '将自动对所有未评课程给予满分评价，确定继续吗？',
    );
    if (!confirm || !mounted) return;
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
        showAppSnackBar(context, detail, severity: ToastSeverity.info);
      } else {
        showAppSnackBar(
          context,
          '已评 ${result.evaluated.length} 门课',
          severity: ToastSeverity.success,
        );
      }
      await _loadStatus();
    } on AuthException catch (e, stackTrace) {
      talker.error('教师评价自动评教失败', e, stackTrace);
      if (!mounted) return;
      showAppSnackBar(context, e.message, severity: ToastSeverity.error);
    } catch (e, stackTrace) {
      if (!mounted) return;
      talker.error('教师评价自动评教异常', e, stackTrace);
      showAppSnackBar(context, '评教失败: $e', severity: ToastSeverity.error);
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
    final theme = context.theme;
    final tasks = _sortedTasks;

    return AppPage(
      title: '教师评价',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _isLoading || !_campusAvailable ? null : _loadStatus,
          tooltip: '刷新评价',
          loading: _isLoading,
        ),
      ],
      child: AppPageBody(
        maxWidth: AppLayout.resultMaxWidth,
        child: _isLoading
            ? const Center(child: FCircularProgress())
            : tasks.isEmpty
            ? AppStateView(
                icon: FLucideIcons.messageSquareMore,
                title: '暂无评教任务',
                description: !_campusAvailable
                    ? (_manager.campusNetworkStatus ==
                              CampusNetworkStatus.checking
                          ? '正在检测校园网，教师评价暂不可用'
                          : '未连接校园网，教师评价暂不可用')
                    : null,
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
                      padding: EdgeInsets.fromLTRB(
                        AppLayout.pageGutter(context),
                        0,
                        AppLayout.pageGutter(context),
                        AppSpacing.lg,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIconButton(
                            icon: FLucideIcons.chevronLeft,
                            onPress: _currentPage > 0
                                ? () => _goToPage(_currentPage - 1)
                                : null,
                            tooltip: '上一项',
                            size: FButtonSizeVariant.xs,
                          ),
                          Text(
                            '${_currentPage + 1} / ${tasks.length}',
                            style: theme.typography.body.md,
                          ),
                          AppIconButton(
                            icon: FLucideIcons.chevronRight,
                            onPress: _currentPage < tasks.length - 1
                                ? () => _goToPage(_currentPage + 1)
                                : null,
                            tooltip: '下一项',
                            size: FButtonSizeVariant.xs,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildTaskPage(FThemeData theme, JpTask task) {
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      safeArea: false,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      children: [
        _buildTaskCard(theme, task),
        if (task.status == '进行中') ...[
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FButton(
              onPress: _isEvaluating || task.pending == 0 || !_campusAvailable
                  ? null
                  : () => _autoEvaluate(task),
              prefix: _isEvaluating
                  ? const FCircularProgress(
                      size: FCircularProgressSizeVariant.sm,
                    )
                  : const Icon(FLucideIcons.thumbsUp),
              child: Text(task.pending > 0 ? '给恩师们点赞' : '已全部完成'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTaskCard(FThemeData theme, JpTask task) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.taskName,
            style: theme.typography.tileTitle.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${task.startTime} ~ ${task.endTime}  ${task.completed}/${task.total}',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          if (task.courses.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...task.courses.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      c.done ? FLucideIcons.circleCheck : FLucideIcons.circle,
                      size: 18,
                      color: c.done
                          ? theme.colors.primary
                          : theme.colors.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${c.courseName}(${c.teacherName})',
                        style: theme.typography.body.md,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.bottomRight,
            child: FBadge(
              variant: task.status == '进行中'
                  ? FBadgeVariant.primary
                  : FBadgeVariant.secondary,
              child: Text(task.status),
            ),
          ),
        ],
      ),
    );
  }
}
