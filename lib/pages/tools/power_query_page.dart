import 'package:flutter/material.dart';

import '../../constants/semester_config.dart';
import '../../services/power_service.dart';
import '../../utils/week_calculator.dart';

class PowerQueryPage extends StatefulWidget {
  final PowerQueryData result;

  const PowerQueryPage({super.key, required this.result});

  @override
  State<PowerQueryPage> createState() => _PowerQueryPageState();
}

class _PowerQueryPageState extends State<PowerQueryPage> {
  static const _pageSize = 7;
  int _currentPage = 0;

  late final List<PowerDailyUsage> _reversed =
      widget.result.dailyUsage.reversed.toList();

  int get _totalPages =>
      (_reversed.length / _pageSize).ceil().clamp(1, 999);

  List<PowerDailyUsage> get _currentPageItems {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _reversed.length);
    return _reversed.sublist(start, end);
  }

  int _weekForPage(int page) {
    final week = currentWeek(semesterStartDate);
    return week - page;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('电费查询'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [_buildResultCard(theme, widget.result)],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme, PowerQueryData result) {
    final metrics = <_MetricItem>[
      _MetricItem('剩余电量', '${result.available} 度'),
      _MetricItem('电价', '${result.price} 元/度'),
      if (result.monthUsage != null)
        _MetricItem('本月用电', '${result.monthUsage} 度'),
      if (result.estDays != null)
        _MetricItem('预计可用', _formatEstDays(result.estDays!)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '查询结果',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.7,
            ),
            itemCount: metrics.length,
            itemBuilder: (context, index) =>
                _buildMetricTile(theme, metrics[index]),
          ),
          if (result.dailyUsage.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  '用电明细 - 第${_weekForPage(_currentPage)}周',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 22,
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                Text(
                  '${_currentPage + 1}/$_totalPages',
                  style: theme.textTheme.bodyMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 22,
                  onPressed: _currentPage < _totalPages - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._currentPageItems.map((item) => _buildUsageRow(theme, item)),
          ] else ...[
            const SizedBox(height: 18),
            Text(
              '当前房间暂未返回日用量明细。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatEstDays(String value) {
    if (RegExp(r'^\d+$').hasMatch(value)) {
      return '$value 天';
    }
    return value;
  }

  Widget _buildMetricTile(ThemeData theme, _MetricItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(110),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageRow(ThemeData theme, PowerDailyUsage item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: Text(item.date, style: theme.textTheme.bodyMedium)),
          Text(
            '${item.usage} 度',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem {
  final String label;
  final String value;

  const _MetricItem(this.label, this.value);
}
