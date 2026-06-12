import 'package:flutter/material.dart';

import '../../services/cas_service.dart';
import '../../services/repair_service.dart';
import '../../utils/snackbar_helper.dart';
import 'repair_form_page.dart';

class RepairPage extends StatefulWidget {
  final CasSession session;
  final RepairResult initialResult;

  const RepairPage({
    super.key,
    required this.session,
    required this.initialResult,
  });

  @override
  State<RepairPage> createState() => _RepairPageState();
}

class _RepairPageState extends State<RepairPage> {
  late List<RepairRecord> _records;
  late RepairUserInfo _userInfo;

  @override
  void initState() {
    super.initState();
    _records = widget.initialResult.records;
    _userInfo = widget.initialResult.userInfo;
  }

  @override
  void dispose() {
    widget.session.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final records = await RepairService().queryRepairs(widget.session);
      if (!mounted) return;
      setState(() => _records = records);
    } catch (_) {
      if (mounted) showAppSnackBar(context, '刷新失败');
    }
  }

  Future<void> _openForm() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RepairFormPage(
          session: widget.session,
          userInfo: _userInfo,
        ),
      ),
    );
    if (submitted == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('在线报修'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: _records.isEmpty
            ? Center(
                child: Text(
                  '暂无报修记录',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _records.length,
                  itemBuilder: (context, index) =>
                      _buildRecordCard(theme, _records[index]),
                ),
              ),
      ),
    );
  }

  Widget _buildRecordCard(ThemeData theme, RepairRecord record) {
    final statusColor = switch (record.status) {
      '已完成' || '已办结' => Colors.green,
      '处理中' || '维修中' => Colors.orange,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record.status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  record.createTime,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              record.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${record.areaName}  ${record.itemName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (record.address.isNotEmpty)
              Text(
                record.address,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
