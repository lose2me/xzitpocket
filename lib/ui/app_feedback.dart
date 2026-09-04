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
    builder: (context, style, animation) => FDialog(
      animation: animation,
      builder: (context, style) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.theme.typography.pageTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: context.theme.typography.bodySmall.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FButton(
                  variant: FButtonVariant.ghost,
                  size: FButtonSizeVariant.sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => Navigator.pop(context, false),
                  child: Text(cancelLabel),
                ),
                const SizedBox(width: AppSpacing.sm),
                FButton(
                  // Confirmation actions use the active theme color so they
                  // remain consistent with user-selected app themes.
                  variant: FButtonVariant.primary,
                  size: FButtonSizeVariant.sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => Navigator.pop(context, true),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
