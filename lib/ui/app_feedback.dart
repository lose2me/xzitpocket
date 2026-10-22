import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'app_tokens.dart';

class AppStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final bool destructive;

  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final color = destructive ? colors.destructive : colors.mutedForeground;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.theme.typography.tileTitle.copyWith(
                color: destructive ? colors.destructive : colors.foreground,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: context.theme.typography.bodySmall.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppSheetSurface extends StatelessWidget {
  final Widget child;

  const AppSheetSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.theme.colors.card,
        border: Border(top: BorderSide(color: context.theme.colors.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: child,
    ),
  );
}

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double? maxHeightRatio,
}) => showFSheet<T>(
  context: context,
  side: FLayout.btt,
  style: const FModalSheetStyleDelta.delta(
    barrierFilter: FModalSheetStyle.defaultBarrierFilter,
  ),
  useSafeArea: true,
  mainAxisMaxRatio: maxHeightRatio,
  builder: (context) => AppSheetSurface(child: builder(context)),
);

/// Shared white card used by every centered dialog.
FDialogStyleDelta appDialogStyle(BuildContext context) {
  final colors = context.theme.colors;
  return FDialogStyleDelta.delta(
    insetPadding: const EdgeInsetsGeometryDelta.value(
      EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    ),
    decoration: DecorationDelta.shapeDelta(
      color: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

/// Soft blurred scrim behind every centered dialog.
FDialogRouteStyleDelta appDialogRouteStyle() => FDialogRouteStyleDelta.delta(
  barrierFilter: () =>
      (context, animation) => ImageFilter.compose(
        outer: ImageFilter.blur(sigmaX: animation * 4, sigmaY: animation * 4),
        inner: ColorFilter.mode(
          context.theme.colors.barrier.withValues(alpha: animation * 0.30),
          BlendMode.srcOver,
        ),
      ),
);

abstract final class AppDialogMetrics {
  static const double maxWidth = 320;
  static const double actionHeight = 50;
}

class AppDialogDivider extends StatelessWidget {
  final bool vertical;

  const AppDialogDivider({super.key, this.vertical = false});

  @override
  Widget build(BuildContext context) => Container(
    width: vertical ? 1 : null,
    height: vertical ? null : 1,
    color: context.theme.colors.border.withValues(alpha: 0.55),
  );
}

/// Text action used by the split footer of a confirmation dialog.
class AppDialogTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPress;
  final Color? color;
  final Color? background;
  final bool emphasized;

  const AppDialogTextAction({
    super.key,
    required this.label,
    required this.onPress,
    this.color,
    this.background,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final background = this.background;
    return FTappable(
      onPress: onPress,
      child: Center(
        child: Container(
          padding: background == null
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: background == null
              ? null
              : BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
          child: Text(
            label,
            style: theme.typography.label.copyWith(
              fontSize: 16,
              color: color ?? theme.colors.primary,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered title + optional description shared by every dialog.
class AppDialogHeader extends StatelessWidget {
  final String title;
  final String? message;

  const AppDialogHeader({super.key, required this.title, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final message = this.message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.typography.pageTitle.copyWith(height: 1.3),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.typography.bodySmall.copyWith(
              height: 20 / 14,
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}

/// Split text footer shared by every dialog.
class AppDialogFooter extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool destructive;

  const AppDialogFooter({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return SizedBox(
      height: AppDialogMetrics.actionHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppDialogTextAction(
              label: cancelLabel,
              color: colors.mutedForeground,
              onPress: onCancel,
            ),
          ),
          const AppDialogDivider(vertical: true),
          Expanded(
            child: AppDialogTextAction(
              label: confirmLabel,
              emphasized: true,
              color: destructive ? colors.destructive : colors.primary,
              background: (destructive ? colors.destructive : colors.primary)
                  .withValues(alpha: 0.12),
              onPress: onConfirm,
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation dialog with a split text footer.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final result = await showFDialog<bool>(
    context: context,
    barrierDismissible: !destructive,
    routeStyle: appDialogRouteStyle(),
    style: appDialogStyle(context),
    builder: (context, style, animation) => FDialog(
      animation: animation,
      constraints: const BoxConstraints(
        minWidth: 280,
        maxWidth: AppDialogMetrics.maxWidth,
      ),
      builder: (context, style) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: AppDialogHeader(title: title, message: message),
          ),
          const AppDialogDivider(),
          AppDialogFooter(
            cancelLabel: cancelLabel,
            confirmLabel: confirmLabel,
            destructive: destructive,
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
