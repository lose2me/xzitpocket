import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

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
/// [RefreshIndicator] freezes the indicator as soon as the pull is armed and
/// keeps it there when the finger moves back up, so a pull can only be
/// cancelled by releasing. Here the indicator tracks the drag in both
/// directions and only refreshes when it is released fully extended.
class AppRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
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
  bool _refreshing = false;

  @override
  void dispose() {
    _position.dispose();
    _scale.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || _refreshing) return false;
    if (notification is ScrollStartNotification) {
      _dragging =
          notification.dragDetails != null &&
          notification.metrics.extentBefore == 0 &&
          notification.metrics.axisDirection == AxisDirection.down;
      _dragOffset = 0;
      return false;
    }
    if (!_dragging) return false;

    if (notification is ScrollEndNotification) {
      _dragging = false;
      if (_position.value >= 1.0) {
        unawaited(_refresh());
      } else {
        unawaited(
          _position.animateTo(
            0.0,
            duration: _kRefreshFadeDuration,
            curve: Curves.easeOut,
          ),
        );
      }
      return false;
    }

    final double delta;
    if (notification is ScrollUpdateNotification) {
      // Ballistic updates after the finger lifts must not retract the pull.
      if (notification.dragDetails == null) return false;
      delta = -notification.scrollDelta!;
    } else if (notification is OverscrollNotification) {
      delta = -notification.overscroll;
    } else {
      return false;
    }

    // Pulling further only makes sense while the list is at its top. Moving
    // back up always retracts the pull: by then the list itself is scrolling
    // back to the top and must not wipe the indicator in one frame.
    if (delta > 0 && notification.metrics.extentBefore > 0) return false;

    _dragOffset += delta;
    if (_dragOffset <= 0) {
      _dragOffset = 0;
      _position.value = 0;
    } else {
      _position.value =
          (_dragOffset /
                  (notification.metrics.viewportDimension *
                      _kRefreshDragExtent))
              .clamp(0.0, 1.0)
              .toDouble();
    }
    return false;
  }

  Future<void> _refresh() async {
    _refreshing = true;
    await _position.animateTo(
      1 / _kRefreshSizeFactor,
      duration: _kRefreshSnapDuration,
    );
    if (!mounted) return;
    setState(() {});
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        await _scale.animateTo(1.0, duration: _kRefreshFadeDuration);
        _position.value = 0;
        _scale.value = 0;
        _refreshing = false;
        setState(() {});
      }
    }
  }

  bool _handleIndicatorNotification(
    OverscrollIndicatorNotification notification,
  ) {
    if (notification.depth == 0 && _position.value > 0) {
      notification.disallowIndicator();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = theme.colors.primary;
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: _handleIndicatorNotification,
        child: AnimatedBuilder(
          animation: Listenable.merge([_position, _scale]),
          child: widget.child,
          builder: (context, child) {
            final value = _position.value;
            return Stack(
              children: [
                child!,
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
    this.topPadding = AppSpacing.md,
    this.bottomPadding = AppSpacing.xl,
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
    this.topPadding = AppSpacing.md,
    this.bottomPadding = AppSpacing.xl,
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
    this.topPadding = AppSpacing.md,
    this.bottomPadding = AppSpacing.xl,
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
