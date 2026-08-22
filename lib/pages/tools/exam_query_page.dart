import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/auth_service.dart';
import '../../services/cas_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/exam_utils.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

class ExamQueryPage extends StatefulWidget {
  final ExamResult result;
  final String studentId;
  final String password;
  final PreferencesStorage preferencesStorage;

  const ExamQueryPage({
    super.key,
    required this.result,
    required this.studentId,
    required this.password,
    required this.preferencesStorage,
  });

  @override
  State<ExamQueryPage> createState() => _ExamQueryPageState();
}

class _ExamQueryPageState extends State<ExamQueryPage> {
  late ExamResult _result;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final result = await ToolsDataManager.instance.refreshExam(
        widget.studentId,
        widget.password,
        widget.preferencesStorage,
      );
      if (!mounted) return;
      if (result == null) {
        showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
        return;
      }
      setState(() => _result = result);
    } on AuthException catch (e, stackTrace) {
      talker.error('考试详情刷新失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, e.message, severity: ToastSeverity.error);
      }
    } catch (e, stackTrace) {
      talker.error('考试详情况刷新异常', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  int? _daysUntil(String time) {
    final d = parseExamDate(time);
    if (d == null) return null;
    final today = DateTime.now();
    return DateTime(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final now = DateTime.now();
    final exams =
        _result.exams.where((e) {
          final d = parseExamDate(e.time);
          return d == null || !d.isBefore(now);
        }).toList()..sort((a, b) {
          final da = parseExamDate(a.time);
          final db = parseExamDate(b.time);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });

    return AppPage(
      title: '考试查询',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _isRefreshing ? null : _refresh,
          tooltip: '刷新考试',
          loading: _isRefreshing,
        ),
      ],
      child: exams.isEmpty
          ? const AppPageBody(
              maxWidth: AppLayout.resultMaxWidth,
              child: AppStateView(
                icon: FLucideIcons.calendarCheck,
                title: '暂无考试安排',
              ),
            )
          : AppPageListView(
              maxWidth: AppLayout.resultMaxWidth,
              topPadding: AppSpacing.lg,
              bottomPadding: AppSpacing.xxl,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    '还剩 ${exams.length} 门考试，比格咬它',
                    textAlign: TextAlign.center,
                    style: theme.typography.bodySmall.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
                for (final exam in exams) _buildExamCard(theme, exam),
              ],
            ),
    );
  }

  Widget _buildExamCard(FThemeData theme, ExamItem exam) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exam.title,
                    style: theme.typography.tileTitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (exam.location.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(
                    FLucideIcons.mapPin,
                    size: 16,
                    color: theme.colors.mutedForeground,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    exam.location,
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
                if (exam.isResit) ...[
                  const SizedBox(width: 8),
                  FBadge(
                    variant: FBadgeVariant.destructive,
                    child: const Text('补考'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (exam.time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      FLucideIcons.clock3,
                      size: 16,
                      color: theme.colors.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        exam.time,
                        style: theme.typography.body.md.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                    if (_daysUntil(exam.time) case final days? when days >= 0)
                      Text(
                        '$days 天',
                        style: theme.typography.body.md.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
