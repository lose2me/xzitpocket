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
import '../../utils/error_message.dart';
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
  final Set<String> _expandedTasks = {};

  static const _collapsedCourseCount = 5;

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
    _status = widget.result;
    unawaited(_loadStatus());
  }

  @override
  void dispose() {
    _manager.removeListener(_onCampusNetworkChanged);
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

  Future<void> _loadStatus({bool forceRefresh = false}) async {
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
      JpStatusResult? result;
      if (forceRefresh) {
        result = await _manager.refreshJp(config.studentId!, password, prefs);
      } else {
        await _manager.loadJp(config.studentId!, password, prefs);
        result = _manager.jp;
      }
      if (!mounted) return;
      if (result == null) {
        showAppSnackBar(context, '查询失败', severity: ToastSeverity.error);
        return;
      }
      final changed = !identical(result, _status);
      setState(() {
        if (changed) {
          _status = result;
        }
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('教师评价详情刷新失败', e, stackTrace);
      if (!mounted) return;
      showAppSnackBar(context, e.message, severity: ToastSeverity.error);
    } catch (e, stackTrace) {
      if (!mounted) return;
      talker.error('教师评价查询异常', e, stackTrace);
      showAppSnackBar(
        context,
        '查询失败: ${describeError(e)}',
        severity: ToastSeverity.error,
      );
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
      title: '给所有未评课程打满分？',
      message: '将自动对所有未评课程给予满分评价，提交后不可修改。',
      confirmLabel: '确认评价',
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
      await _loadStatus(forceRefresh: true);
    } on AuthException catch (e, stackTrace) {
      talker.error('教师评价自动评教失败', e, stackTrace);
      if (!mounted) return;
      showAppSnackBar(context, e.message, severity: ToastSeverity.error);
    } catch (e, stackTrace) {
      if (!mounted) return;
      talker.error('教师评价自动评教异常', e, stackTrace);
      showAppSnackBar(
        context,
        '评教失败: ${describeError(e)}',
        severity: ToastSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _isEvaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tasks = _sortedTasks;

    return AppPage(
      title: '教师评价',
      child: AppPageBody(
        maxWidth: AppLayout.resultMaxWidth,
        onRefresh: tasks.isEmpty && !_isLoading && _campusAvailable
            ? () => _loadStatus(forceRefresh: true)
            : null,
        child: _isLoading && _status == null
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
            : AppPageListView(
                maxWidth: AppLayout.resultMaxWidth,
                topPadding: AppSpacing.lg,
                bottomPadding: AppSpacing.xxl,
                onRefresh: _campusAvailable
                    ? () => _loadStatus(forceRefresh: true)
                    : null,
                children: [
                  // 离线但有缓存任务时正常展示缓存，并给出居中小字提示
                  //（样式与电费页一致，需求 9）。
                  if (!_campusAvailable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        _manager.campusNetworkStatus ==
                                CampusNetworkStatus.checking
                            ? '正在检测校园网，当前显示缓存数据'
                            : '未连接校园网，当前显示缓存数据',
                        textAlign: TextAlign.center,
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                  for (final task in tasks) _buildTaskCard(theme, task),
                ],
              ),
      ),
    );
  }

  Widget _buildTaskCard(FThemeData theme, JpTask task) {
    final expanded = _expandedTasks.contains(task.taskId);
    final courses = task.courses;
    final visible = expanded || courses.length <= _collapsedCourseCount
        ? courses
        : courses.take(_collapsedCourseCount).toList();
    final hidden = courses.length - visible.length;
    final time = _taskTimeLabel(task);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppStatusChip(status: task.status),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    time,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              task.taskName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '已完成 ${task.completed}/${task.total}',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            if (courses.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final course in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(
                        course.done
                            ? FLucideIcons.circleCheck
                            : FLucideIcons.circle,
                        size: 16,
                        color: course.done
                            ? theme.colors.primary
                            : theme.colors.mutedForeground,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${course.courseName}(${course.teacherName})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.body.md,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hidden > 0 || expanded)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FTappable(
                    onPress: () => setState(() {
                      if (expanded) {
                        _expandedTasks.remove(task.taskId);
                      } else {
                        _expandedTasks.add(task.taskId);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                        horizontal: AppSpacing.xs,
                      ),
                      child: Text(
                        expanded ? '收起' : '展开剩余 $hidden 门',
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            if (task.status == '进行中') ...[
              const SizedBox(height: AppSpacing.md),
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
        ),
      ),
    );
  }

  String _taskTimeLabel(JpTask task) {
    if (task.startTime.isEmpty) return task.endTime;
    if (task.endTime.isEmpty) return task.startTime;
    return '${task.startTime} ~ ${task.endTime}';
  }
}
