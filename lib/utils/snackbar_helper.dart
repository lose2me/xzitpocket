import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// MD 配色（Material Design Red 色板）
const _kDeepRed = Color(0xFFD32F2F); // red 700，进度条
const _kLightRed = Color(0xFFFFCDD2); // red 100，内容背景
const _kRedText = Color(0xFFB71C1C); // red 900，文字

/// 右上角抽屉式 toast 队列（最新的在最上方，最多同时显示 3 条）。
final List<_ToastData> _queue = [];
OverlayEntry? _hostEntry;
final ValueNotifier<int> _revision = ValueNotifier(0);

class _ToastData {
  final String message;
  final Duration duration;

  const _ToastData({required this.message, required this.duration});
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  if (!context.mounted) return;
  // 插入 Navigator 的 Overlay（rootOverlay: false），
  // 这样 toast 显示在页面之上，且其 context 向上能找到 Navigator（用于判断底部导航）。
  final overlay = Overlay.of(context);
  // 仅在 host 不存在时创建并插入，避免重复插入同一 OverlayEntry 导致崩溃。
  if (_hostEntry == null) {
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
    ..add(_ToastData(message: message, duration: duration));
  _revision.value++;
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
    // forui FBottomNavigationBar 基础高度 ≈ 61px（icon 24 + padding 5×2 + spacing 2 + 文字 ≈15 + bar padding 5×2）
    final navBarHeight = 61.0 + viewPadding.bottom * 2 / 3;
    // 根页面（有底部导航）toast 贴导航栏上缘；push 出的详情页无底部导航则贴屏幕底部。
    final hasBottomNav = !Navigator.of(context).canPop();

    return IgnorePointer(
      // 让 toast 完全穿透点击/滑动，不遮挡任何操作。
      ignoring: true,
      child: SafeArea(
        // FBottomNavigationBar 的 safeAreaBottom 默认为 false（导航栏高 = 61 + viewPadding.bottom×2/3），
        // 有底部导航时 toast 不再额外加完整手势条安全区，避免出现空隙；
        // 详情页无底部导航时保留底部安全区。
        bottom: !hasBottomNav,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: hasBottomNav ? navBarHeight : 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in toasts.take(3))
                  _ToastItem(
                    key: ValueKey(t),
                    data: t,
                    onDone: () => _removeToast(t),
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

class _ToastItemState extends State<_ToastItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  late final Animation<double> _expand;
  late final AnimationController _progressController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _expand = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOut,
    );
    _progressController = AnimationController(
      vsync: this,
      duration: widget.data.duration,
    );
    _expandController.forward();
    _progressController.forward();
    _timer = Timer(widget.data.duration, () {
      unawaited(
        _expandController.reverse().then((_) {
          if (mounted) widget.onDone();
        }),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expandController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 高度展开动画：底部锚定在导航栏线条处，高度从 0 向上生长（伸出）、
    // 收回时向下压缩回线条，本体与动画全程在线条之上。
    return SizeTransition(
      sizeFactor: _expand,
      alignment: Alignment.bottomCenter,
      child: Stack(
        children: [
          // 内容区：全宽（与底部导航栏等长），浅红背景 + 深红文字，无圆弧
          Container(
            width: double.infinity,
            color: _kLightRed,
            padding: const EdgeInsets.only(
              left: 14,
              right: 14,
              top: 16,
              bottom: 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  FLucideIcons.circleAlert,
                  size: 18,
                  color: _kRedText,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.data.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _kRedText,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 顶部伸缩条（深红，从满到空收缩），与内容等宽
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
                  child: const ColoredBox(color: _kDeepRed),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
