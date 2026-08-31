import 'package:flutter/widgets.dart';
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

  const ProfileSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => FTile(
    style: _profileTileStyle,
    prefix: Icon(icon, size: 20),
    title: Text(title),
    details: value == null ? null : Text(value!),
    suffix: onTap == null
        ? null
        : const Icon(FLucideIcons.chevronRight, size: 18),
    onPress: onTap,
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
    prefix: Icon(icon, size: 20),
    onPress: onTap,
    child: Row(
      children: [
        Expanded(child: Text(title)),
        const SizedBox(width: AppSpacing.sm),
        child,
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
      prefix: Icon(icon, size: 20),
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
