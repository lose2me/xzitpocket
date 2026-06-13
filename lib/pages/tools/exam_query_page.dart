import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/cas_service.dart';
import '../../utils/exam_utils.dart';
import '../../utils/snackbar_helper.dart';

class ExamQueryPage extends StatefulWidget {
  final ExamResult result;
  final String studentId;
  final String password;

  const ExamQueryPage({
    super.key,
    required this.result,
    required this.studentId,
    required this.password,
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
      final result = await AuthService().fetchExams(
        widget.studentId,
        widget.password,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on AuthException catch (e) {
      if (mounted) showAppSnackBar(context, e.message);
    } catch (_) {
      if (mounted) showAppSnackBar(context, '刷新失败');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  int? _daysUntil(String time) {
    final d = parseExamDate(time);
    if (d == null) return null;
    final today = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final exams = _result.exams
        .where((e) {
          final d = parseExamDate(e.time);
          return d == null || !d.isBefore(now);
        })
        .toList()
      ..sort((a, b) {
        final da = parseExamDate(a.time);
        final db = parseExamDate(b.time);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('考试查询'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refresh,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(
        child: exams.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_available,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      '暂无考试安排',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: exams.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '还剩 ${exams.length} 门考试，比格咬它',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return _buildExamCard(theme, exams[index - 1]);
                },
              ),
      ),
    );
  }

  Widget _buildExamCard(ThemeData theme, ExamItem exam) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
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
                    exam.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (exam.location.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.location_on_outlined,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(
                    exam.location,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (exam.isResit) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '补考',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (exam.time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        exam.time,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (_daysUntil(exam.time) case final days? when days >= 0)
                      Text(
                        '$days 天',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
