import 'package:flutter/material.dart';

import '../../services/power_service.dart';

class PowerQueryPage extends StatelessWidget {
  final PowerQueryData result;

  const PowerQueryPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('电费查询'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [_buildResultCard(theme, result)],
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
            Text(
              '本月用电',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...result.dailyUsage.map((item) => _buildUsageRow(theme, item)),
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
