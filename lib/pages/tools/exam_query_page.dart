import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class ExamQueryPage extends StatelessWidget {
  final ExamResult result;

  const ExamQueryPage({super.key, required this.result});

  DateTime? _parseExamDate(String time) {
    final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(time);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      23, 59, 59,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final exams = result.exams
        .where((e) {
          final d = _parseExamDate(e.time);
          return d == null || !d.isBefore(now);
        })
        .toList()
      ..sort((a, b) {
        final da = _parseExamDate(a.time);
        final db = _parseExamDate(b.time);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('考试查询'), centerTitle: true),
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
                itemCount: exams.length,
                itemBuilder: (context, index) =>
                    _buildExamCard(theme, exams[index]),
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
                if (exam.isResit)
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
            ),
            const SizedBox(height: 10),
            if (exam.time.isNotEmpty) _infoRow(theme, Icons.access_time, exam.time),
            if (exam.location.isNotEmpty)
              _infoRow(theme, Icons.location_on_outlined, exam.location),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
