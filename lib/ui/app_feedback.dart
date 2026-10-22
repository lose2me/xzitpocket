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

/// Shared surface for centered dialogs: rounded, airy and softly elevated.
FDialogStyleDelta appDialogStyle(BuildContext context) {
  final colors = context.theme.colors;
  final dark = colors.brightness == Brightness.dark;
  return FDialogStyleDelta.delta(
    insetPadding: const EdgeInsetsGeometryDelta.value(
      EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    ),
    decoration: DecorationDelta.shapeDelta(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDialogMetrics.radius),
        side: BorderSide(color: colors.border.withValues(alpha: 0.7)),
      ),
      shadows: [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: dark ? 0.42 : 0.10),
          blurRadius: 40,
          offset: const Offset(0, 16),
        ),
      ],
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
  static const double radius = 20;
  static const double maxWidth = 340;
  static const double actionHeight = 44;
  static const double actionGap = 10;
}

class AppDialogIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const AppDialogIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 20, color: color),
  );
}

/// Two equal-width actions shared by every centered dialog.
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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: AppDialogMetrics.actionHeight,
          child: FButton(
            variant: FButtonVariant.secondary,
            onPress: onCancel,
            child: Text(cancelLabel),
          ),
        ),
      ),
      const SizedBox(width: AppDialogMetrics.actionGap),
      Expanded(
        child: SizedBox(
          height: AppDialogMetrics.actionHeight,
          child: FButton(
            variant: destructive
                ? FButtonVariant.destructive
                : FButtonVariant.primary,
            onPress: onConfirm,
            child: Text(confirmLabel),
          ),
        ),
      ),
    ],
  );
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
  IconData? icon,
}) async {
  final colors = context.theme.colors;
  final result = await showFDialog<bool>(
    context: context,
    barrierDismissible: !destructive,
    routeStyle: appDialogRouteStyle(context),
    style: appDialogStyle(context),
    builder: (context, style, animation) => FDialog(
      animation: animation,
      builder: (context, style) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDialogMetrics.maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (destructive || icon != null) ...[
                AppDialogIcon(
                  icon: icon ?? FLucideIcons.triangleAlert,
                  color: destructive ? colors.destructive : colors.primary,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.theme.typography.body.lg.copyWith(
                  fontSize: 17,
                  height: 24 / 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.theme.typography.bodySmall.copyWith(
                  height: 21 / 14,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
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
    ),
  );
  return result ?? false;
}
