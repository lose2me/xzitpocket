import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/config_provider.dart';
import '../../services/power_service.dart';
import '../../utils/snackbar_helper.dart';
import 'power_query_page.dart';

class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage> {
  final _powerService = PowerService();

  bool _isLoading = false;
  PowerQueryData? _cachedData;

  @override
  void initState() {
    super.initState();
    _loadPowerData();
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadPowerData() async {
    final prefs = ref.read(preferencesStorageProvider);
    final roomId = prefs.getSavedPowerRoomId();
    if (roomId == null || roomId.isEmpty) return;

    final cacheDate = prefs.getPowerCacheDate();
    final cacheJson = prefs.getPowerCache();
    if (cacheDate == _todayString() && cacheJson != null) {
      setState(() {
        _cachedData = PowerQueryData.fromJson(
          jsonDecode(cacheJson) as Map<String, dynamic>,
        );
      });
      return;
    }

    await _refreshPowerData();
  }

  Future<void> _refreshPowerData() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      if (mounted) showAppSnackBar(context, '此功能需登录使用');
      return;
    }

    final prefs = ref.read(preferencesStorageProvider);
    final roomId = prefs.getSavedPowerRoomId();
    if (roomId == null || roomId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await _powerService.queryRoom(roomId);
      if (!mounted) return;
      await prefs.setPowerCache(jsonEncode(result.toJson()), _todayString());
      setState(() => _cachedData = result);
    } on PowerQueryException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '查询失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomId = ref.watch(savedRoomIdProvider);
    final hasRoom = roomId != null && roomId.isNotEmpty;

    ref.listen(savedRoomIdProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        _loadPowerData();
      } else {
        setState(() => _cachedData = null);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('工具'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [_buildPowerCard(theme, hasRoom, roomId)],
        ),
      ),
    );
  }

  Widget _buildPowerCard(ThemeData theme, bool hasRoom, String? roomId) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: hasRoom && _cachedData != null
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PowerQueryPage(result: _cachedData!),
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: !hasRoom
                    ? Text(
                        '请先在「我的」中设置宿舍号',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : _cachedData != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '电费查询',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '剩余 ${_cachedData!.available} 度',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : _isLoading
                            ? Text(
                                '电费查询',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Text(
                                '暂无数据，点击刷新',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
              ),
              if (hasRoom && _isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasRoom && _cachedData != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              else if (hasRoom)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _refreshPowerData,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
