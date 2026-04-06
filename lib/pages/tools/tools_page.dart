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
  final _roomController = TextEditingController();
  final _powerService = PowerService();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final savedRoomId = ref.read(storageServiceProvider).getSavedPowerRoomId();
    if (savedRoomId != null && savedRoomId.isNotEmpty) {
      _roomController.text = savedRoomId;
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('工具'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [_buildPowerQueryCard(theme)],
        ),
      ),
    );
  }

  Widget _buildPowerQueryCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.bolt_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '电费查询',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _roomController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                if (!_isLoading) {
                  _queryPower();
                }
              },
              decoration: const InputDecoration(
                labelText: '房间号',
                hintText: '请输入房间号',
                prefixIcon: Icon(Icons.meeting_room_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _queryPower,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isLoading ? '查询中...' : '查询电费'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _queryPower() async {
    FocusScope.of(context).unfocus();

    final rawRoomId = _roomController.text.trim();
    if (rawRoomId.isEmpty) {
      showAppSnackBar(context, '请输入房间号');
      return;
    }

    final roomId = rawRoomId.toUpperCase();

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _powerService.queryRoom(roomId);
      if (!mounted) return;
      await ref.read(storageServiceProvider).setSavedPowerRoomId(rawRoomId);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PowerQueryPage(result: result)));
    } on PowerQueryException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '查询失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
