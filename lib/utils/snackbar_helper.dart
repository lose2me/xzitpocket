import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../ui/app_colors.dart';

/// toast 的语义分级，颜色取自主题令牌（见 `lib/ui/app_theme.dart`）。
enum ToastSeverity {
  /// 中性说明（蓝）
  info,

  /// 成功（绿）
  success,

  /// 需要注意 / 校验提示（琥珀）
  warning,

  /// 错误 / 失败（红）
  error,
}

/// 全局 toast 队列（始终只保留最新的一条）。
final List<_ToastData> _queue = [];
OverlayEntry? _hostEntry;
OverlayState? _rootOverlay;
final ValueNotifier<int> _revision = ValueNotifier(0);

class _ToastData {
  final String message;
  final Duration duration;
  final ToastSeverity severity;

  const _ToastData({
    required this.message,
    required this.duration,
    required this.severity,
  });
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
  ToastSeverity severity = ToastSeverity.info,
  // Kept for source compatibility. Toasts now always use the global layout.
  bool? showAboveNavBar,
}) {
  final overlay = context.mounted
      ? Overlay.of(context, rootOverlay: true)
      : _rootOverlay;
  if (overlay == null || !overlay.mounted) return;
  _rootOverlay = overlay;
  // 仅在 host 不存在时创建并插入，避免重复插入同一 OverlayEntry 导致崩溃。
  if (_hostEntry?.mounted != true) {
    _hostEntry?.remove();
    _hostEntry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<int>(
        valueListenable: _revision,
        builder: (_, _, _) => _ToastHost(toasts: List.of(_queue)),
      ),
    );
    overlay.insert(_hostEntry!);
  }
  // 同一时间只保留最新的一条 toast，旧的直接移除。
  _queue
    ..clear()
    ..add(_ToastData(message: message, duration: duration, severity: severity));
  _revision.value++;
}

void dismissAppSnackBar() {
  if (_queue.isEmpty && _hostEntry == null) return;
  _queue.clear();
  _revision.value++;
  _hostEntry?.remove();
  _hostEntry = null;
}

void _removeToast(_ToastData data) {
  _queue.remove(data);
  _revision.value++;
  if (_queue.isEmpty) {
    _hostEntry?.remove();
    _hostEntry = null;
  }
}

class _ToastHost extends StatelessWidget {
  final List<_ToastData> toasts;

  const _ToastHost({required this.toasts});

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    const horizontalMargin = 16.0;
    // Keep the global toast above the app navigation bar and the system
    // gesture area. The same baseline is used on every route.
    const navigationClearance = 72.0;
    final bottomMargin = viewPadding.bottom + navigationClearance;

    return IgnorePointer(
      // 让 toast 完全穿透点击/滑动，不遮挡任何操作。
      ignoring: true,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              left: horizontalMargin,
              right: horizontalMargin,
              bottom: bottomMargin,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in toasts)
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _ToastItem(
                        key: ValueKey(t),
                        data: t,
                        onDone: () => _removeToast(t),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastItem extends StatefulWidget {
  final _ToastData data;
  final VoidCallback onDone;

  const _ToastItem({super.key, required this.data, required this.onDone});

  @override
  State<_ToastItem> createState() => _ToastItemState();
}

class _ToastItemState extends State<_ToastItem> with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _exitController;
  late final Animation<double> _enter;
  late final Animation<double> _exit;
  late final AnimationController _progressController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _enter = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOutCubic,
    );
    _exit = CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic);
    _progressController = AnimationController(
      vsync: this,
      duration: widget.data.duration,
    );
    _enterController.forward();
    _progressController.forward();
    _timer = Timer(widget.data.duration, () {
      unawaited(
        _exitController.forward().then((_) {
          if (mounted) widget.onDone();
        }),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _enterController.dispose();
    _exitController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  ({Color bar, Color background, Color foreground, IconData icon}) _palette(
    FThemeData theme,
    ToastSeverity severity,
  ) {
    final colors = theme.colors;
    final semantic = colors.semantic;
    return switch (severity) {
      ToastSeverity.success => (
        bar: semantic.success,
        background: semantic.successContainer,
        foreground: semantic.onSuccessContainer,
        icon: FLucideIcons.circleCheck,
      ),
      ToastSeverity.warning => (
        bar: semantic.warning,
        background: semantic.warningContainer,
        foreground: semantic.onWarningContainer,
        icon: FLucideIcons.triangleAlert,
      ),
      ToastSeverity.info => (
        bar: semantic.info,
        background: semantic.infoContainer,
        foreground: semantic.onInfoContainer,
        icon: FLucideIcons.info,
      ),
      ToastSeverity.error => (
        bar: colors.destructive,
        background: colors.destructive.withValues(alpha: 0.12),
        foreground: colors.destructive,
        icon: FLucideIcons.circleAlert,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette(context.theme, widget.data.severity);
    final surface = _buildSurface(palette);
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _exit]),
      builder: (context, _) {
        final entering = 1 - _enter.value;
        final exiting = _exit.value;
        final opacity = (_enter.value * (1 - exiting)).clamp(0.0, 1.0);
        // Enter from the lower-left; leave toward the upper-right.
        final offset = Offset(
          -14 * entering + 14 * exiting,
          10 * entering - 10 * exiting,
        );
        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: offset, child: surface),
        );
      },
    );
  }

  Widget _buildSurface(
    ({Color bar, Color background, Color foreground, IconData icon}) palette,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.zero,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(palette.icon, size: 18, color: palette.foreground),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.data.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.foreground,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 4,
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 1 - _progressController.value,
                    heightFactor: 1,
                    child: ColoredBox(color: palette.bar),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
