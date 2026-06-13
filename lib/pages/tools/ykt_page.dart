import 'package:flutter/material.dart';

import '../../services/cas_service.dart';
import '../../services/ykt_service.dart';
import '../../utils/snackbar_helper.dart';

class YktPage extends StatefulWidget {
  final YktDetailResult result;
  final String studentId;
  final String password;

  const YktPage({
    super.key,
    required this.result,
    required this.studentId,
    required this.password,
  });

  @override
  State<YktPage> createState() => _YktPageState();
}

class _YktPageState extends State<YktPage> {
  static const _pageSize = 7;
  int _currentPage = 0;
  bool _isRefreshing = false;

  late YktDetailResult _result;
  late List<YktTransaction> _txns;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    _txns = _result.transactions.reversed.toList();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final result = await YktService().getDetail(
        widget.studentId,
        widget.password,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _txns = result.transactions.reversed.toList();
        _currentPage = 0;
      });
    } on AuthException catch (e) {
      if (mounted) showAppSnackBar(context, e.message);
    } catch (_) {
      if (mounted) showAppSnackBar(context, '刷新失败');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  int get _totalPages => (_txns.length / _pageSize).ceil().clamp(1, 999);

  List<YktTransaction> _pageItems(int page) {
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, _txns.length);
    return _txns.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bal = _result.balance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('一卡通查询'),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '卡片信息',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCell(theme, '卡号', bal.cardNo),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCell(theme, '余额', '${bal.balance} 元'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_txns.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      '交易明细(30天)',
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
              ),
              const SizedBox(height: 8),
              ..._pageItems(_currentPage).map((t) => _buildTxnTile(theme, t)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCell(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(110),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxnTile(ThemeData theme, YktTransaction t) {
    final isNeg = t.amount.startsWith('-');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.location.isNotEmpty ? t.location : t.type,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.time,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isNeg ? '' : '+'}${t.amount}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isNeg
                        ? theme.colorScheme.error
                        : Colors.green,
                  ),
                ),
                if (t.balance.isNotEmpty)
                  Text(
                    '余 ${t.balance}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
