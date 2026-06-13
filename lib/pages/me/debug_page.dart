import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/debug_log_service.dart';
import '../../utils/snackbar_helper.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final _scrollController = ScrollController();
  final _service = DebugLogService.instance;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _service.onUpdate = _onLogUpdate;
  }

  @override
  void dispose() {
    _service.onUpdate = null;
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogUpdate() {
    if (!mounted) return;
    setState(() {});
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _service.entries;

    return Scaffold(
      appBar: AppBar(title: const Text('调试模式'), centerTitle: true),
      body: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('启用调试日志'),
            subtitle: Text(
              _service.enabled ? '正在记录...' : '关闭',
              style: TextStyle(
                color: _service.enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: _service.enabled,
            onChanged: (v) {
              setState(() => _service.enabled = v);
              if (v) _service.collectEnvironment();
            },
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      _service.enabled ? '等待日志...' : '开启开关后操作APP即可记录日志',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is UserScrollNotification) {
                        final atBottom = _scrollController.position.pixels >=
                            _scrollController.position.maxScrollExtent - 50;
                        if (_autoScroll != atBottom) {
                          setState(() => _autoScroll = atBottom);
                        }
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 800,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: entries.length,
                          itemBuilder: (_, i) => _LogTile(entry: entries[i]),
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: entries.isEmpty
                        ? null
                        : () {
                            _service.clear();
                            setState(() {});
                          },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清除'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: entries.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(
                              ClipboardData(text: _service.export()),
                            );
                            showAppSnackBar(
                              context,
                              '已复制 ${entries.length} 条日志',
                            );
                          },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('复制'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final DebugLogEntry entry;

  const _LogTile({required this.entry});

  Color _categoryColor(ThemeData theme) => switch (entry.category) {
        DebugLogCategory.network => theme.colorScheme.primary,
        DebugLogCategory.auth => Colors.orange,
        DebugLogCategory.navigation => Colors.teal,
        DebugLogCategory.action => theme.colorScheme.secondary,
        DebugLogCategory.error => theme.colorScheme.error,
        DebugLogCategory.lifecycle => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _categoryColor(theme);
    final text = entry.detail.isEmpty
        ? entry.title
        : '${entry.title}  ${entry.detail}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            entry.timeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.categoryLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontFamily: 'monospace',
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}
