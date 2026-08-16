import 'package:flutter/material.dart';

import '../../services/cas_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/repair_service.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/snackbar_helper.dart';
import 'repair_form_page.dart';

class RepairPage extends StatefulWidget {
  final RepairResult initialResult;
  final String studentId;
  final String password;
  final PreferencesStorage preferencesStorage;

  const RepairPage({
    super.key,
    required this.initialResult,
    required this.studentId,
    required this.password,
    required this.preferencesStorage,
  });

  @override
  State<RepairPage> createState() => _RepairPageState();
}

class _RepairPageState extends State<RepairPage> {
  late List<RepairRecord> _records;
  late RepairUserInfo _userInfo;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _records = widget.initialResult.records;
    _userInfo = widget.initialResult.userInfo;
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final result = await ToolsDataManager.instance.refreshRepair(
        widget.studentId,
        widget.password,
        widget.preferencesStorage,
      );
      if (!mounted) return;
      if (result == null) {
        showAppSnackBar(context, '刷新失败');
        return;
      }
      setState(() {
        _records = result.records;
        _userInfo = result.userInfo;
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('报修详情刷新失败', e, stackTrace);
      if (mounted) showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      talker.error('报修详情刷新异常', e, stackTrace);
      if (mounted) showAppSnackBar(context, '刷新失败');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openForm() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RepairFormPage(
          studentId: widget.studentId,
          password: widget.password,
          userInfo: _userInfo,
        ),
      ),
    );
    if (submitted == true) {
      await _refresh();
    }
  }

  static const _knownStatuses = {
    '已完工',
    '已关闭',
    '已评价',
    '已接单',
    '已转单',
    '处理中',
    '维修中',
    '已上报',
    '已上传照片',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _records
        .where((r) => _knownStatuses.contains(r.status))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的报修'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: visible.isEmpty
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
                  itemCount: visible.length,
                  itemBuilder: (context, index) =>
                      _buildRecordCard(theme, visible[index]),
                ),
              ),
      ),
    );
  }

  Widget _buildRecordCard(ThemeData theme, RepairRecord record) {
    final statusColor = switch (record.status) {
      '已完工' || '已关闭' || '已评价' => Colors.green,
      '已接单' || '已转单' || '处理中' || '维修中' => Colors.orange,
      '已上报' || '已上传照片' => Colors.blue,
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
              record.address.isNotEmpty
                  ? '${record.areaName}(${record.address})  ${record.itemName}'
                  : '${record.areaName}  ${record.itemName}',
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
