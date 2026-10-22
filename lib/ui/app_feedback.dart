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

/// Shared surface for centered dialogs: flat, border-led and airy.
FDialogStyleDelta appDialogStyle(BuildContext context) {
  final colors = context.theme.colors;
  return FDialogStyleDelta.delta(
    insetPadding: const EdgeInsetsGeometryDelta.value(
      EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    ),
    decoration: DecorationDelta.shapeDelta(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDialogMetrics.radius),
        side: BorderSide(color: colors.border.withValues(alpha: 0.6)),
      ),
    ),
  );
}

/// Lighter barrier so the page behind a dialog stays readable.
FDialogRouteStyleDelta appDialogRouteStyle(BuildContext context) {
  final barrier = context.theme.colors.barrier;
  return FDialogRouteStyleDelta.delta(
    barrierFilter: () =>
        (context, animation) => ImageFilter.compose(
          outer: ImageFilter.blur(sigmaX: animation * 2, sigmaY: animation * 2),
          inner: ColorFilter.mode(
            barrier.withValues(alpha: animation * 0.30),
            BlendMode.srcOver,
          ),
        ),
  );
}

abstract final class AppDialogMetrics {
  static const double radius = 16;
  static const double maxWidth = 300;
}

/// A text-only dialog action. Keeps the dialog flat and quiet.
class AppDialogTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPress;
  final Color? color;
  final bool emphasized;

  const AppDialogTextAction({
    super.key,
    required this.label,
    required this.onPress,
    this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FTappable(
      onPress: onPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          label,
          style: theme.typography.label.copyWith(
            color: color ?? theme.colors.primary,
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Right-aligned text actions shared by every centered dialog.
class AppDialogActions extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool destructive;

  const AppDialogActions({
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppDialogTextAction(
          label: cancelLabel,
          onPress: onCancel,
          color: colors.mutedForeground,
        ),
        const SizedBox(width: 4),
        AppDialogTextAction(
          label: confirmLabel,
          onPress: onConfirm,
          emphasized: true,
          color: destructive ? colors.destructive : colors.primary,
        ),
      ],
    );
  }
}

/// Confirmation dialog.
///
/// Benign confirmations use the minimal layout (A); destructive ones add a
/// tinted warning badge (B) and ignore taps on the barrier so an irreversible
/// action always needs an explicit choice.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final colors = context.theme.colors;
  final result = await showFDialog<bool>(
    context: context,
    barrierDismissible: !destructive,
    routeStyle: appDialogRouteStyle(context),
    style: appDialogStyle(context),
    builder: (context, style, animation) => FDialog(
      animation: animation,
      constraints: const BoxConstraints(
        minWidth: 280,
        maxWidth: AppDialogMetrics.maxWidth,
      ),
      builder: (context, style) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.theme.typography.body.lg.copyWith(
                fontSize: 16,
                height: 22 / 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: context.theme.typography.bodySmall.copyWith(
                height: 20 / 14,
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            AppDialogActions(
              cancelLabel: cancelLabel,
              confirmLabel: confirmLabel,
              destructive: destructive,
              onCancel: () => Navigator.pop(context, false),
              onConfirm: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
