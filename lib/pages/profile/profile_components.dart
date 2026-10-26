import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';

import '../../ui/app_components.dart';

const _profileTileContentStyle = FItemContentStyleDelta.delta(
  suffixedPadding: EdgeInsetsGeometryDelta.value(
    EdgeInsets.fromLTRB(16, 12, 12, 12),
  ),
  unsuffixedPadding: EdgeInsetsGeometryDelta.value(
    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
);

const _profileTileStyle = FItemStyleDelta.delta(
  contentStyle: _profileTileContentStyle,
);

const _compactProfileTileStyle = FItemStyleDelta.delta(
  contentStyle: FItemContentStyleDelta.delta(
    suffixedPadding: EdgeInsetsGeometryDelta.value(
      EdgeInsets.fromLTRB(16, 8, 12, 0),
    ),
    unsuffixedPadding: EdgeInsetsGeometryDelta.value(
      EdgeInsets.fromLTRB(16, 8, 16, 0),
    ),
  ),
);

const _compactOptionButtonStyle = FButtonStyleDelta.delta(
  contentStyle: FButtonContentStyleDelta.delta(
    constraints: BoxConstraints(minHeight: 44),
    padding: EdgeInsetsGeometryDelta.value(
      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
  final VoidCallback? onPointerUp;

  const ProfileSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.onLongPress,
    this.onPointerUp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final result = FTile(
      style: _profileTileStyle,
      prefix: Icon(icon, size: 20, color: theme.colors.primary),
      title: Text(title),
      details: value == null ? null : Text(value!),
      suffix: onTap == null && onLongPress == null
          ? null
          : const Icon(FLucideIcons.chevronRight, size: 18),
      onPress: onTap,
      onLongPress: onLongPress,
    );
    if (onPointerUp == null) return result;
    return Listener(
      onPointerUp: (_) => onPointerUp!(),
      onPointerCancel: (_) => onPointerUp!(),
      child: result,
    );
  }
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
    style: _profileTileStyle,
    onPress: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: context.theme.colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}

class ProfileSettingsOption<T> {
  final T value;
  final String label;

  const ProfileSettingsOption({required this.value, required this.label});
}

class ProfileSettingsInlineControlTile extends StatelessWidget with FTileMixin {
  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  const ProfileSettingsInlineControlTile({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => FTile.raw(
    style: _profileTileStyle,
    onPress: onTap,
    child: Row(
      children: [
        Icon(icon, size: 20, color: context.theme.colors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(title)),
        const SizedBox(width: AppSpacing.md),
        child,
      ],
    ),
  );
}

class ProfileSettingsOptionButtons<T> extends StatelessWidget {
  final T value;
  final List<ProfileSettingsOption<T>> options;
  final ValueChanged<T> onChanged;
  final double buttonWidth;

  const ProfileSettingsOptionButtons({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.buttonWidth = 92,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: buttonWidth,
            child: FButton(
              size: FButtonSizeVariant.sm,
              style: _compactOptionButtonStyle,
              variant: options[index].value == value
                  ? FButtonVariant.primary
                  : FButtonVariant.outline,
              onPress: () => onChanged(options[index].value),
              child: Text(
                options[index].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class ProfileSettingsOptionsTile<T> extends StatelessWidget with FTileMixin {
  final IconData icon;
  final String title;
  final T value;
  final List<ProfileSettingsOption<T>> options;
  final ValueChanged<T> onChanged;

  const ProfileSettingsOptionsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
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
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ProfileSettingsOptionButtons<T>(
          value: value,
          options: options,
          onChanged: onChanged,
        ),
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
  final double defaultValue;
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
    required this.defaultValue,
    required this.onChanged,
    this.suffix = '',
    this.displayMultiplier = 1,
    this.displayDecimals = 1,
  });

  /// 默认值在轨道上的比例位置（0~1）。
  double get _defaultFraction =>
      max <= min ? 0 : ((defaultValue - min) / (max - min)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) => FTile.raw(
    style: _compactProfileTileStyle,
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
        SizedBox(
          height: 16,
          child: Transform.translate(
            offset: const Offset(0, 2),
            // Slider 需要 Material 祖先；forui 的 FScaffold 不提供 Material，
            // 缺少它会在 debug 构建触发断言（个性化设置白屏的诱因之一）。
            child: Material(
              color: Colors.transparent,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  // 手柄是一条主题色竖线，指示当前值，可直接拖动。
                  thumbShape: _VerticalLineThumbShape(
                    color: context.theme.colors.primary,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                  // 轨道上的灰色竖线标记默认值的位置。
                  trackShape: _DefaultValueTrackShape(
                    fraction: _defaultFraction,
                    color: context.theme.colors.foreground.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  tickMarkShape: const RoundSliderTickMarkShape(
                    tickMarkRadius: 0.35,
                  ),
                  activeTickMarkColor: context.theme.colors.background
                      .withValues(alpha: 0.9),
                  inactiveTickMarkColor: context.theme.colors.foreground
                      .withValues(alpha: 0.5),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 滑条手柄：一条主题色竖线，其位置即当前值。
class _VerticalLineThumbShape extends SliderComponentShape {
  static const double width = 3;
  static const double height = 14;

  final Color color;

  const _VerticalLineThumbShape({required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(width, height);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(width / 2)),
      Paint()..color = color,
    );
  }
}

/// 轨道：在默认值位置额外画一条灰色基准竖线。
class _DefaultValueTrackShape extends RoundedRectSliderTrackShape {
  final double fraction;
  final Color color;

  const _DefaultValueTrackShape({required this.fraction, required this.color});

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    double additionalActiveTrackHeight = 2,
    required TextDirection textDirection,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
      textDirection: textDirection,
    );
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final dx = textDirection == TextDirection.rtl
        ? rect.right - fraction * rect.width
        : rect.left + fraction * rect.width;
    context.canvas.drawLine(
      Offset(dx, rect.center.dy - 6),
      Offset(dx, rect.center.dy + 6),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
  }
}

class ProfileSettingsColorTile extends StatelessWidget with FTileMixin {
  final IconData icon;
  final String title;
  final Color? value;
  final List<Color> colors;
  final ValueChanged<Color?> onChanged;
  final VoidCallback? onCustomColorPressed;
  final Color? lastCustomColor;
  final bool allowReset;
  final String resetLabel;

  const ProfileSettingsColorTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.colors,
    required this.onChanged,
    this.onCustomColorPressed,
    this.lastCustomColor,
    this.allowReset = true,
    this.resetLabel = '跟随明暗',
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
                  ? resetLabel
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
                            ? context.theme.colors.foreground
                            : context.theme.colors.border,
                        width: value == null ? 2 : 1,
                      ),
                    ),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.block,
                        size: 30,
                        color: value == null
                            ? context.theme.colors.foreground
                            : context.theme.colors.mutedForeground,
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
                    child: Builder(
                      builder: (context) {
                        final selected = value?.toARGB32() == color.toARGB32();
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: selected
                                  ? context.theme.colors.foreground
                                  : context.theme.colors.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: selected
                                ? Icon(
                                    Icons.check,
                                    size: 17,
                                    color: color.computeLuminance() > 0.45
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (onCustomColorPressed != null)
                Tooltip(
                  message: '自定义颜色',
                  child: GestureDetector(
                    onTap: onCustomColorPressed,
                    child: Builder(
                      builder: (context) {
                        final selected =
                            value != null &&
                            !colors.any(
                              (color) => color.toARGB32() == value!.toARGB32(),
                            );
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lastCustomColor,
                            gradient: lastCustomColor == null
                                ? const SweepGradient(
                                    colors: [
                                      Color(0xFFE53935),
                                      Color(0xFFFDD835),
                                      Color(0xFF43A047),
                                      Color(0xFF00ACC1),
                                      Color(0xFF3949AB),
                                      Color(0xFF8E24AA),
                                      Color(0xFFE53935),
                                    ],
                                  )
                                : null,
                            border: Border.all(
                              color: selected
                                  ? context.theme.colors.foreground
                                  : context.theme.colors.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: const SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(
                              FLucideIcons.palette,
                              size: 16,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 2),
                              ],
                            ),
                          ),
                        );
                      },
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

Future<Color?> showProfileColorPicker({
  required BuildContext context,
  required Color initialColor,
}) => showFDialog<Color>(
  context: context,
  routeStyle: appDialogRouteStyle(),
  style: appDialogStyle(context),
  builder: (context, style, animation) => FDialog(
    animation: animation,
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(
      minWidth: 280,
      maxWidth: AppDialogMetrics.maxWidth,
    ),
    builder: (context, style) =>
        _ProfileColorPickerDialog(initialColor: initialColor),
  ),
);

class _ProfileColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _ProfileColorPickerDialog({required this.initialColor});

  @override
  State<_ProfileColorPickerDialog> createState() =>
      _ProfileColorPickerDialogState();
}

class _ProfileColorPickerDialogState extends State<_ProfileColorPickerDialog> {
  // Keep the picker thumb at a useful, visible default brightness. The
  // selected hue/saturation still come from the color passed by the caller.
  late HSVColor _color = HSVColor.fromColor(widget.initialColor)
      .withValue(0.75);

  Color get _selectedColor => _color.toColor();

  void _updateWheel(Offset position, Size size) {
    final center = size.center(Offset.zero);
    final delta = position - center;
    final radius = math.min(size.width, size.height) / 2;
    final saturation = (delta.distance / radius).clamp(0.0, 1.0);
    final hue = (math.atan2(delta.dy, delta.dx) * 180 / math.pi + 360) % 360;
    setState(() {
      _color = _color.withHue(hue).withSaturation(saturation);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppDialogMetrics.maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppDialogHeader(title: '自定义颜色'),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: SizedBox.square(
                    dimension: 220,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        return GestureDetector(
                          onPanDown: (details) =>
                              _updateWheel(details.localPosition, size),
                          onPanUpdate: (details) =>
                              _updateWheel(details.localPosition, size),
                          child: CustomPaint(
                            painter: _ColorWheelPainter(color: _color),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Text('明度'),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            value: _color.value,
                            onChanged: (value) => setState(
                              () => _color = _color.withValue(value),
                            ),
                          ),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colors.border),
                      ),
                      child: const SizedBox.square(dimension: 26),
                    ),
                  ],
                ),
                Text(
                  '#${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: theme.typography.bodySmall.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const AppDialogDivider(),
          AppDialogFooter(
            cancelLabel: '取消',
            confirmLabel: '确定',
            onCancel: () => Navigator.pop(context),
            onConfirm: () => Navigator.pop(context, _selectedColor),
          ),
        ],
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final HSVColor color;

  const _ColorWheelPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final huePaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, huePaint);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    if (color.value < 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withValues(alpha: 1 - color.value),
      );
    }

    final angle = color.hue * math.pi / 180;
    final selected =
        center +
        Offset(math.cos(angle), math.sin(angle)) * radius * color.saturation;
    canvas.drawCircle(selected, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      selected,
      6,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) =>
      oldDelegate.color != color;
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

class ProfileSettingsHint extends StatelessWidget {
  final String text;

  const ProfileSettingsHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    child: Text(
      text,
      style: context.theme.typography.caption.copyWith(
        color: context.theme.colors.mutedForeground,
      ),
    ),
  );
}
