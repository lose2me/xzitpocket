import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

/// A compact, copy-friendly viewer for the complete Talker history.
class DebugLogPage extends StatefulWidget {
  const DebugLogPage({super.key});

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  static const _pageSize = 40;

  late List<TalkerData> _logs;
  late bool _loggingEnabled;
  int _visibleCount = 0;
  final _listController = ScrollController();
  StreamSubscription<TalkerData>? _subscription;

  @override
  void initState() {
    super.initState();
    _loggingEnabled = talker.settings.enabled;
    _logs = List<TalkerData>.of(talker.history.reversed);
    _visibleCount = min(_pageSize, _logs.length);
    _listController.addListener(_loadMoreIfNeeded);
    _subscription = talker.stream.listen((_) {
      if (!mounted) return;
      final updated = List<TalkerData>.of(talker.history.reversed);
      setState(() {
        _logs = updated;
        _visibleCount = min(_logs.length, max(_visibleCount, _pageSize));
      });
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _listController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (!_listController.hasClients ||
        _listController.position.extentAfter > 240 ||
        _visibleCount >= _logs.length) {
      return;
    }
    setState(() {
      _visibleCount = min(_visibleCount + _pageSize, _logs.length);
    });
  }

  void _setLoggingEnabled(bool enabled) {
    setTalkerLoggingEnabled(enabled);
    setState(() => _loggingEnabled = enabled);
  }

  void _clear() {
    talker.cleanHistory();
    setState(() {
      _logs = const [];
      _visibleCount = 0;
    });
  }

  String _formatLog(TalkerData data) {
    final lines = <String>[
      data.generateTextMessage(timeFormat: TimeFormat.timeAndSeconds),
    ];
    if (data.exception != null) lines.add('Exception: ${data.exception}');
    if (data.error != null) lines.add('Error: ${data.error}');
    return lines.join('\n');
  }

  String get _logText =>
      _logs.map(_formatLog).join('\n\n${List.filled(64, '-').join()}\n\n');

  Future<void> _copyLogs() async {
    if (_logs.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _logText));
    if (mounted) showAppSnackBar(context, '日志已复制');
  }

  @override
  Widget build(BuildContext context) {
    final logHeight = (MediaQuery.sizeOf(context).height * 0.58).clamp(
      320.0,
      640.0,
    );
    return AppPage(
      title: '调试日志',
      actions: [
        AppIconButton(
          icon: FLucideIcons.copy,
          onPress: _logs.isEmpty ? null : _copyLogs,
          tooltip: '复制全部日志',
          variant: FButtonVariant.ghost,
          size: FButtonSizeVariant.sm,
        ),
        AppIconButton(
          icon: FLucideIcons.trash2,
          onPress: _logs.isEmpty ? null : _clear,
          tooltip: '清空日志',
          variant: FButtonVariant.ghost,
          size: FButtonSizeVariant.sm,
        ),
      ],
      child: AppPageListView(
        maxWidth: AppLayout.contentMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          FTileGroup(
            children: [
              FTile(
                prefix: const Icon(FLucideIcons.bug, size: 20),
                title: const Text('调试模式'),
                details: Text(_loggingEnabled ? '已开启' : '已关闭'),
                suffix: FSwitch(
                  value: _loggingEnabled,
                  semanticsLabel: '调试模式',
                  onChange: _setLoggingEnabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_logs.isEmpty)
            const AppStateView(
              icon: FLucideIcons.fileSearch,
              title: '暂无日志',
              description: '新的请求和运行事件会实时显示在这里',
            )
          else
            FCard(
              child: SizedBox(
                height: logHeight,
                child: ListView.separated(
                  controller: _listController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _visibleCount,
                  separatorBuilder: (_, _) => const FDivider(),
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SingleChildScrollView(
                      primary: false,
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _formatLog(_logs[index]),
                        softWrap: false,
                        style: context.theme.typography.body.sm.copyWith(
                          color: context.theme.colors.foreground,
                          fontFamily: 'monospace',
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
