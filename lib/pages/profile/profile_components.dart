import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../ui/app_components.dart';

const _profileTileStyle = FItemStyleDelta.delta(
  contentStyle: FItemContentStyleDelta.delta(
    suffixedPadding: EdgeInsetsGeometryDelta.value(
      EdgeInsets.fromLTRB(15, 16.5, 13, 16.5),
    ),
    unsuffixedPadding: EdgeInsetsGeometryDelta.value(
      EdgeInsets.symmetric(horizontal: 15, vertical: 16.5),
    ),
  ),
);

class ProfileSectionLabel extends StatelessWidget {
  final String title;

  const ProfileSectionLabel({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: theme.typography.sectionTitle.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
    );
  }
}

class ProfileSettingsGroup extends StatelessWidget {
  final List<FTileMixin> children;

  const ProfileSettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) =>
      FTileGroup(divider: FItemDivider.full, children: children);
}

class ProfileSettingsTile extends StatelessWidget with FTileMixin {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ProfileSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => FTile(
    style: _profileTileStyle,
    prefix: Icon(icon, size: 20, color: context.theme.colors.primary),
    title: Text(title),
    details: value == null ? null : Text(value!),
    suffix: onTap == null && onLongPress == null
        ? null
        : const Icon(FLucideIcons.chevronRight, size: 18),
    onPress: onTap,
    onLongPress: onLongPress,
  );
}

class ProfileSettingsExpandableTile extends StatelessWidget with FTileMixin {
  final IconData icon;
  final String title;
  final String? value;
  final bool expanded;
  final bool expandable;
  final Widget child;
  final VoidCallback onTap;

  const ProfileSettingsExpandableTile({
    super.key,
    required this.icon,
    required this.title,
    required this.expanded,
    required this.child,
    required this.onTap,
    this.expandable = true,
    this.value,
  });

  @override
  Widget build(BuildContext context) => FTile.raw(
    style: _profileTileStyle,
    semanticsExpanded: expandable ? expanded : null,
    // Keep a non-expandable row visually enabled; a null handler makes
    // Forui apply its disabled icon/text colors even when the row is merely
    // informational.
    onPress: expandable ? onTap : () {},
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: context.theme.colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title)),
            if (value != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(value!),
            ],
            const SizedBox(width: AppSpacing.sm),
            if (expandable)
              Icon(
                expanded ? FLucideIcons.chevronDown : FLucideIcons.chevronRight,
                size: 18,
                color: context.theme.colors.mutedForeground,
              ),
          ],
        ),
        if (expandable && expanded) ...[
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ],
    ),
  );
}

class ProfileSettingsControlTile extends StatelessWidget with FTileMixin {
  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  const ProfileSettingsControlTile({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => FTile.raw(
    prefix: Icon(icon, size: 20, color: context.theme.colors.primary),
    onPress: onTap,
    child: Row(
      children: [
        Expanded(child: Text(title)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: child),
      ],
    ),
  );
}

class ProfileSettingsSliderTile extends StatelessWidget with FTileMixin {
  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String suffix;
  final double displayMultiplier;
  final int displayDecimals;
  final ValueChanged<double> onChanged;

  const ProfileSettingsSliderTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.suffix = '',
    this.displayMultiplier = 1,
    this.displayDecimals = 1,
  });

  @override
  Widget build(BuildContext context) => FTile.raw(
    style: _profileTileStyle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: context.theme.colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title)),
            Text(
              '${(value * displayMultiplier).toStringAsFixed(displayDecimals)}$suffix',
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class ProfileSettingsColorTile extends StatelessWidget with FTileMixin {
  final IconData icon;
  final String title;
  final Color? value;
  final List<Color> colors;
  final ValueChanged<Color?> onChanged;
  final bool allowReset;

  const ProfileSettingsColorTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.colors,
    required this.onChanged,
    this.allowReset = true,
  });

  @override
  Widget build(BuildContext context) => FTile.raw(
    style: _profileTileStyle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: context.theme.colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title)),
            Text(
              value == null
                  ? '跟随主题'
                  : '#${value!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (allowReset)
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.theme.colors.background,
                      border: Border.all(
                        color: value == null
                            ? context.theme.colors.primary
                            : context.theme.colors.border,
                        width: value == null ? 3 : 1,
                      ),
                    ),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.block,
                        size: 30,
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              if (allowReset) const SizedBox(width: AppSpacing.sm),
              for (final color in colors)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () => onChanged(color),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                          color: value?.toARGB32() == color.toARGB32()
                              ? context.theme.colors.primary
                              : context.theme.colors.border,
                          width: value?.toARGB32() == color.toARGB32() ? 3 : 1,
                        ),
                      ),
                      child: const SizedBox(width: 30, height: 30),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ProfileSettingsCheckboxTile extends StatelessWidget with FTileMixin {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChange;

  const ProfileSettingsCheckboxTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    child: FTile(
      style: _profileTileStyle,
      prefix: Icon(icon, size: 20, color: context.theme.colors.primary),
      title: Text(title),
      suffix: ExcludeSemantics(
        // 勾选框自身可点击；点击方框由手势竞技场优先交给子控件处理，
        // 点击其余区域由 tile 的 onPress 处理，不会重复触发。
        child: FCheckbox(value: value, onChange: onChange),
      ),
      onPress: () => onChange(!value),
    ),
  );
}
