import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../utils/snackbar_helper.dart';
import 'app_tokens.dart';

class AppPage extends StatelessWidget {
  final String? title;
  final List<Widget> actions;
  final Widget child;
  final Widget? footer;
  final bool root;
  final bool childPad;
  final bool transparentBackground;
  final bool? resizeToAvoidBottomInset;
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// 嵌套页左上角返回按钮开关（免责声明页等强制选择场景使用）。
  final bool showBackButton;

  /// 自定义标题栏样式（默认跟随主题）。
  final FHeaderStyleDelta? headerStyle;

  const AppPage({
    super.key,
    required this.child,
    this.title,
    this.actions = const [],
    this.footer,
    this.root = false,
    this.childPad = false,
    this.transparentBackground = false,
    this.resizeToAvoidBottomInset,
    this.systemOverlayStyle,
    this.headerStyle,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final ambientMediaQuery = MediaQuery.of(context);
    final header = title == null
        ? null
        : root
        ? FHeader(
            title: Center(
              child: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            style: headerStyle ?? FHeaderStyleDelta.context(),
            suffixes: actions,
          )
        : FHeader.nested(
            title: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis),
            titleAlignment: Alignment.center,
            prefixes: showBackButton
                ? [
                    FHeaderAction.back(
                      onPress: () => Navigator.maybePop(context),
                    ),
                  ]
                : const [],
            suffixes: actions,
          );

    final content = title == null
        ? child
        : MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          );

    final scaffoldChild = root && resizeToAvoidBottomInset != true
        ? MediaQuery(data: ambientMediaQuery, child: content)
        : content;
    final scaffold = FScaffold(
      header: header,
      footer: footer,
      scaffoldStyle: transparentBackground
          ? const FScaffoldStyleDelta.delta(
              backgroundColor: Color(0x00000000),
              sidebarBackgroundColor: Color(0x00000000),
            )
          : const FScaffoldStyleDelta.context(),
      childPad: childPad,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? !root,
      child: scaffoldChild,
    );

    // Root pages are hosted inside HomePage's shell. Their content still gets
    // the live keyboard inset when needed, but idle timetable/tools roots do
    // not make their scaffold render objects relayout for every IME frame.
    final isolatedScaffold = root && resizeToAvoidBottomInset != true
        ? MediaQuery(
            data: ambientMediaQuery.copyWith(viewInsets: EdgeInsets.zero),
            child: scaffold,
          )
        : scaffold;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle ?? context.theme.colors.systemOverlayStyle,
      child: isolatedScaffold,
    );
  }
}

/// Pull-to-refresh wrapper matching the app's theme.
///
/// The scrollable keeps its own drag recognizer. Refresh physics consumes the
/// entire pull gesture before it can change the scroll offset, including any
/// upward movement after the indicator has retracted to zero.
class AppRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  /// Notifies ancestors that are outside the refresh viewport (e.g. a
  /// [PageView]) to lock from the first pull until release and full retraction.
  /// This includes pulls that are cancelled without running [onRefresh].
  final ValueChanged<bool>? onRefreshingChanged;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.onRefreshingChanged,
  });

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

// Fraction of the viewport that has to be pulled for a full-strength pull.
const double _kRefreshDragExtent = 0.25;
// The indicator overshoots its resting `displacement` by this factor.
const double _kRefreshSizeFactor = 1.5;
const double _kRefreshDisplacement = 40.0;
const Duration _kRefreshSnapDuration = Duration(milliseconds: 150);
const Duration _kRefreshFadeDuration = Duration(milliseconds: 200);

class _AppRefreshIndicatorState extends State<AppRefreshIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _position = AnimationController(vsync: this);
  late final AnimationController _scale = AnimationController(vsync: this);
  late final Animation<double> _sizeFactor = _position.drive(
    Tween<double>(begin: 0.0, end: _kRefreshSizeFactor),
  );
  late final Animation<double> _scaleFactor = _scale.drive(
    Tween<double>(begin: 1.0, end: 0.0),
  );

  /// Pull distance in logical pixels; only user drags move it.
  double _dragOffset = 0;
  bool _dragging = false;
  bool _dragCancelled = false;
  bool _refreshing = false;
  bool _active = false;
  late ScrollBehavior _scrollBehavior;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final behavior = ScrollConfiguration.of(context);
    // Keep the same physics instance through animation rebuilds. Replacing
    // scroll physics mid-drag can recreate the child's ScrollPosition.
    _scrollBehavior = behavior.copyWith(
      overscroll: false,
      physics: _RefreshScrollPhysics(
        owner: this,
        parent: behavior.getScrollPhysics(context),
      ),
    );
  }

  @override
  void dispose() {
    _position.dispose();
    _scale.dispose();
    super.dispose();
  }

  void _setActive(bool value) {
    if (_active == value) return;
    setState(() => _active = value);
    if (const bool.fromEnvironment('APP_REFRESH_TRACE')) {
      debugPrint('[refresh] active=$value');
    }
    widget.onRefreshingChanged?.call(value);
  }

  // Called before ScrollPosition applies the user's delta. Notifications alone
  // are too late to prevent the list from moving when the finger reverses.
  bool _consumeUserOffset(ScrollMetrics metrics, double delta) {
    if (metrics.axisDirection != AxisDirection.down) return false;
    if (_active && !_dragging) return true;
    if (!_dragging) {
      if (delta <= 0 || metrics.pixels > metrics.minScrollExtent) return false;
      _dragOffset = 0;
      _dragCancelled = false;
      _dragging = true;
      _setActive(true);
    }

    // Keep owning the gesture even when this reaches zero. Only ScrollEnd can
    // release it, so reversing further cannot start scrolling the content.
    _dragOffset = (_dragOffset + delta).clamp(0.0, double.infinity);
    final extent = metrics.viewportDimension * _kRefreshDragExtent;
    _position.value = extent > 0 ? (_dragOffset / extent).clamp(0.0, 1.0) : 0;
    if (const bool.fromEnvironment('APP_REFRESH_TRACE')) {
      debugPrint(
        '[refresh] delta=$delta pixels=${metrics.pixels} '
        'pull=$_dragOffset indicator=${_position.value} consumed=true',
      );
    }
    return true;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axisDirection != AxisDirection.down ||
        notification is! ScrollEndNotification ||
        !_dragging) {
      return false;
    }

    _dragging = false;
    // Flutter may produce DragEndDetails even for PointerCancelEvent after the
    // drag recognizer wins. The outer Listener records cancellation first.
    if (!_dragCancelled &&
        notification.dragDetails != null &&
        _position.value >= 1.0) {
      unawaited(_refresh());
    } else {
      unawaited(_retract());
    }
    return false;
  }

  Future<void> _refresh() async {
    final startedAt = DateTime.now();
    setState(() => _refreshing = true);
    try {
      await _position
          .animateTo(1 / _kRefreshSizeFactor, duration: _kRefreshSnapDuration)
          .orCancel;
      if (!mounted) return;
      await widget.onRefresh();
    } on TickerCanceled {
      // Disposing during the snap must not leave a pending animation future.
    } finally {
      if (mounted) {
        // 每次下拉刷新都要有反馈；页面自己在刷新过程中已经 toast 过
        // （例如「同步成功」「刷新失败」）时不再重复。
        if (!appFeedbackShownSince(startedAt)) {
          showAppSnackBar(context, '已刷新', severity: ToastSeverity.success);
        }
        await _retract(refreshed: true);
      }
    }
  }

  Future<void> _retract({bool refreshed = false}) async {
    // The gesture recognizer stays alive while dragging; after release this
    // rebuild blocks new pointer sequences throughout the retract animation.
    setState(() {});
    try {
      if (refreshed) {
        await _scale.animateTo(1.0, duration: _kRefreshFadeDuration).orCancel;
      } else if (_position.value > 0) {
        await _position
            .animateTo(
              0.0,
              duration: _kRefreshFadeDuration,
              curve: Curves.easeOut,
            )
            .orCancel;
      }
      if (!mounted) return;
      _position.value = 0;
      _scale.value = 0;
      _refreshing = false;
      _dragOffset = 0;
      _setActive(false);
    } on TickerCanceled {
      // The widget was disposed while the indicator was retracting.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = theme.colors.primary;
    return Listener(
      onPointerCancel: (_) {
        if (_dragging) _dragCancelled = true;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: AnimatedBuilder(
          animation: Listenable.merge([_position, _scale]),
          child: widget.child,
          builder: (context, child) {
            final value = _position.value;
            return Stack(
              children: [
                IgnorePointer(
                  ignoring: _active && !_dragging,
                  child: ScrollConfiguration(
                    behavior: _scrollBehavior,
                    child: child!,
                  ),
                ),
                if (value > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SizeTransition(
                      alignment: Alignment.bottomCenter,
                      sizeFactor: _sizeFactor,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: _kRefreshDisplacement,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ScaleTransition(
                            scale: _scaleFactor,
                            child: RefreshProgressIndicator(
                              semanticsLabel: MaterialLocalizations.of(context)
                                  .refreshIndicatorSemanticLabel,
                              value: _refreshing ? null : value * 0.75,
                              color: Color.lerp(
                                color.withAlpha(0),
                                color,
                                (value / (1 / _kRefreshSizeFactor)).clamp(
                                  0.0,
                                  1.0,
                                ),
                              ),
                              backgroundColor: theme.colors.card,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Consume refresh deltas before setPixels, and suppress the release fling.
/// Clamping boundaries also prevent iOS bouncing from moving the content.
/// Child physics must delegate to their parent (AlwaysScrollable does).
class _RefreshScrollPhysics extends ClampingScrollPhysics {
  final _AppRefreshIndicatorState owner;

  const _RefreshScrollPhysics({required this.owner, super.parent});

  @override
  _RefreshScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _RefreshScrollPhysics(owner: owner, parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      position.axisDirection == AxisDirection.down ||
      super.shouldAcceptUserOffset(position);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      owner._consumeUserOffset(position, offset)
      ? 0
      : super.applyPhysicsToUserOffset(position, offset);

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) =>
      owner._active && position.axisDirection == AxisDirection.down
      ? value - position.pixels
      : super.applyBoundaryConditions(position, value);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => owner._active && position.axisDirection == AxisDirection.down
      ? null
      : super.createBallisticSimulation(position, velocity);
}

class AppContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double topPadding;
  final double bottomPadding;
  final bool safeArea;

  const AppContentFrame({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.contentMaxWidth,
    this.topPadding = AppSpacing.lg,
    this.bottomPadding = AppSpacing.xxl,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppLayout.pageGutter(context);
        final availableWidth = constraints.maxWidth - gutter * 2;
        final width = availableWidth.clamp(0.0, maxWidth).toDouble();
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
            child: SizedBox(width: width, child: child),
          ),
        );
      },
    );
    if (safeArea) content = SafeArea(child: content);
    return content;
  }
}

class AppPageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool safeArea;

  /// Whether to reserve the same horizontal page gutter as [AppPageListView].
  ///
  /// Empty states that share a full-width element (e.g. a header or filter)
  /// with the populated list should enable this so the content width stays the
  /// same across the two states.
  final bool pageGutter;

  /// Wraps the body in a pull-to-refresh viewport. The body keeps the viewport
  /// height (so centered/expanded empty states still work) while remaining
  /// draggable for [AppRefreshIndicator].
  final Future<void> Function()? onRefresh;

  const AppPageBody({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.contentMaxWidth,
    this.safeArea = true,
    this.pageGutter = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final inset = pageGutter ? AppLayout.pageGutter(context) * 2 : 0.0;
        final width = (constraints.maxWidth - inset)
            .clamp(0.0, maxWidth)
            .toDouble();
        final body = SizedBox(
          width: width,
          height: constraints.maxHeight,
          child: child,
        );
        final refresh = onRefresh;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: refresh == null
                ? body
                : AppRefreshIndicator(
                    onRefresh: refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: body,
                    ),
                  ),
          ),
        );
      },
    );
    if (safeArea) content = SafeArea(child: content);
    return content;
  }
}

class AppAdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  const AppAdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 148,
    this.spacing = AppSpacing.md,
    this.maxColumns = 2,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final availableColumns =
          ((constraints.maxWidth + spacing) / (minItemWidth + spacing)).floor();
      final columns = availableColumns.clamp(1, maxColumns);
      final itemWidth =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children)
            SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}

class AppPageListView extends StatefulWidget {
  final List<Widget> children;
  final double maxWidth;
  final double topPadding;
  final double bottomPadding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final bool primary;
  final bool safeArea;

  /// 显示右侧滚动指示条（长文页面默认显示）。
  final bool showScrollbar;

  /// 提供后启用下拉刷新，并强制列表在内容不足一屏时仍可下拉。
  final Future<void> Function()? onRefresh;

  const AppPageListView({
    super.key,
    required this.children,
    this.maxWidth = AppLayout.contentMaxWidth,
    this.topPadding = AppSpacing.lg,
    this.bottomPadding = AppSpacing.xxl,
    this.controller,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.primary = true,
    this.safeArea = true,
    this.showScrollbar = true,
    this.onRefresh,
  });

  @override
  State<AppPageListView> createState() => _AppPageListViewState();
}

class _AppPageListViewState extends State<AppPageListView> {
  // 滚动条需要真实的 controller 才能准确跟踪滚动位置：App 内没有
  // PrimaryScrollController，仅靠滚动通知时滑块不会随内容移动。
  ScrollController? _ownController;

  ScrollController? get _scrollController {
    if (widget.controller != null) return widget.controller;
    if (!widget.showScrollbar) return null;
    return _ownController ??= ScrollController();
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _scrollController;
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppLayout.pageGutter(context);
        final contentWidth = (constraints.maxWidth - gutter * 2)
            .clamp(0.0, widget.maxWidth)
            .toDouble();
        final horizontal = (constraints.maxWidth - contentWidth) / 2;
        Widget list = ListView(
          controller: controller,
          physics: widget.onRefresh != null
              ? const AlwaysScrollableScrollPhysics()
              : widget.physics,
          primary: controller == null ? widget.primary : false,
          keyboardDismissBehavior: widget.keyboardDismissBehavior,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            widget.topPadding,
            horizontal,
            widget.bottomPadding,
          ),
          children: widget.children,
        );
        // 滑动时显示、停止后淡出（不常驻）。
        if (widget.showScrollbar) {
          list = Scrollbar(
            controller: controller,
            thumbVisibility: false,
            child: list,
          );
        }
        final refresh = widget.onRefresh;
        if (refresh != null) {
          list = AppRefreshIndicator(onRefresh: refresh, child: list);
        }
        return list;
      },
    );
    if (widget.safeArea) content = SafeArea(child: content);
    return content;
  }
}

/// Lazy counterpart of [AppPageListView] for long result sets. Keeping this
/// separate preserves the simple `children` API for short static pages while
/// allowing large lists to build only the rows that are visible.
class AppPageListViewBuilder extends StatefulWidget {
  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;
  final double maxWidth;
  final double topPadding;
  final double bottomPadding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final bool primary;
  final bool safeArea;

  /// 显示右侧滚动指示条（长文页面默认显示）。
  final bool showScrollbar;

  /// 提供后启用下拉刷新，并强制列表在内容不足一屏时仍可下拉。
  final Future<void> Function()? onRefresh;

  const AppPageListViewBuilder({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.maxWidth = AppLayout.contentMaxWidth,
    this.topPadding = AppSpacing.lg,
    this.bottomPadding = AppSpacing.xxl,
    this.controller,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.primary = true,
    this.safeArea = true,
    this.showScrollbar = true,
    this.onRefresh,
  }) : assert(itemCount >= 0);

  @override
  State<AppPageListViewBuilder> createState() => _AppPageListViewBuilderState();
}

class _AppPageListViewBuilderState extends State<AppPageListViewBuilder> {
  ScrollController? _ownController;

  ScrollController? get _scrollController {
    if (widget.controller != null) return widget.controller;
    if (!widget.showScrollbar) return null;
    return _ownController ??= ScrollController();
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _scrollController;
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppLayout.pageGutter(context);
        final contentWidth = (constraints.maxWidth - gutter * 2)
            .clamp(0.0, widget.maxWidth)
            .toDouble();
        final horizontal = (constraints.maxWidth - contentWidth) / 2;
        Widget list = ListView.builder(
          controller: controller,
          physics: widget.onRefresh != null
              ? const AlwaysScrollableScrollPhysics()
              : widget.physics,
          primary: controller == null ? widget.primary : false,
          keyboardDismissBehavior: widget.keyboardDismissBehavior,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            widget.topPadding,
            horizontal,
            widget.bottomPadding,
          ),
          itemCount: widget.itemCount,
          itemBuilder: widget.itemBuilder,
        );
        // 滑动时显示、停止后淡出（不常驻）。
        if (widget.showScrollbar) {
          list = Scrollbar(
            controller: controller,
            thumbVisibility: false,
            child: list,
          );
        }
        final refresh = widget.onRefresh;
        if (refresh != null) {
          list = AppRefreshIndicator(onRefresh: refresh, child: list);
        }
        return list;
      },
    );
    if (widget.safeArea) content = SafeArea(child: content);
    return content;
  }
}
