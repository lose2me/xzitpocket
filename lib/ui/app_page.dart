import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'app_tokens.dart';

class AppPage extends StatelessWidget {
  final String? title;
  final List<Widget> actions;
  final Widget child;
  final Widget? footer;
  final bool root;
  final bool childPad;

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
    this.headerStyle,
  });

  @override
  Widget build(BuildContext context) {
    final header = title == null
        ? null
        : root
        ? FHeader(
            title: Center(child: Text(title!)),
            style: headerStyle ?? FHeaderStyleDelta.context(),
            suffixes: actions,
          )
        : FHeader.nested(
            title: Text(title!),
            titleAlignment: Alignment.center,
            prefixes: [
              FHeaderAction.back(onPress: () => Navigator.maybePop(context)),
            ],
            suffixes: actions,
          );

    final content = title == null
        ? child
        : MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.theme.colors.systemOverlayStyle,
      child: FScaffold(
        header: header,
        footer: footer,
        childPad: childPad,
        resizeToAvoidBottomInset: !root,
        child: content,
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

  const AppPageBody({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.contentMaxWidth,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: constraints.maxWidth.clamp(0.0, maxWidth).toDouble(),
          height: constraints.maxHeight,
          child: child,
        ),
      ),
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

class AppPageListView extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final double topPadding;
  final double bottomPadding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final bool primary;
  final bool safeArea;

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
  });

  @override
  Widget build(BuildContext context) {
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppLayout.pageGutter(context);
        final contentWidth = (constraints.maxWidth - gutter * 2)
            .clamp(0.0, maxWidth)
            .toDouble();
        final horizontal = (constraints.maxWidth - contentWidth) / 2;
        return ListView(
          controller: controller,
          physics: physics,
          primary: controller == null ? primary : false,
          keyboardDismissBehavior: keyboardDismissBehavior,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topPadding,
            horizontal,
            bottomPadding,
          ),
          children: children,
        );
      },
    );
    if (safeArea) content = SafeArea(child: content);
    return content;
  }
}
