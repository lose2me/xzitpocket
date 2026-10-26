import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPress;
  final String tooltip;
  final Color? iconColor;
  final FButtonVariant variant;
  final FButtonSizeVariant size;
  final bool loading;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPress,
    required this.tooltip,
    this.iconColor,
    this.variant = FButtonVariant.ghost,
    this.size = FButtonSizeVariant.sm,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = FButton.icon(
      onPress: loading ? null : onPress,
      variant: variant,
      size: size,
      semanticsLabel: tooltip,
      child: loading
          ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
          : Icon(icon, color: iconColor),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: FTooltip(
        tipBuilder: (context, controller) => Text(tooltip),
        child: button,
      ),
    );
  }
}

/// 状态标签：小号深色/浅色字 + 语义底色（暗色模式自动跟随）。
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.status,
    this.suffix,
    this.color,
  });

  final String status;
  final String? suffix;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = appStatusStyle(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: color ?? style.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        suffix == null || suffix!.isEmpty ? status : '$status $suffix',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.badge.copyWith(color: style.foreground),
      ),
    );
  }
}

/// 状态色：绿=完成，黄=处理中/进行中，灰=待处理，红=其他。
/// 统一走语义色，保证亮/暗色对比度与列表、详情一致。
({Color background, Color foreground}) appStatusStyle(
  BuildContext context,
  String status,
) {
  final colors = context.theme.colors;
  final semantic = colors.semantic;
  return switch (status) {
    '已完工' || '已关闭' || '已评价' || '已完成' || '已结束' || '已截止' => (
      background: semantic.successContainer,
      foreground: semantic.onSuccessContainer,
    ),
    '已接单' || '已转单' || '处理中' || '维修中' || '进行中' => (
      background: semantic.warningContainer,
      foreground: semantic.onWarningContainer,
    ),
    '已上报' ||
    '已提交' ||
    '提交报修' ||
    '报修' ||
    '已上传照片' ||
    '已上传图片' ||
    '待接单' ||
    '未开始' => (background: colors.muted, foreground: colors.mutedForeground),
    _ => (
      background: colors.destructive,
      foreground: colors.destructiveForeground,
    ),
  };
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onPress;

  /// 内容卡（16）。紧凑行卡/指标卡请显式传
  /// `EdgeInsets.all(AppSpacing.md)`（12）。
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = FCard(
      child: Padding(padding: padding, child: child),
    );
    if (onPress != null) {
      card = FTappable(
        onPress: onPress,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }
    return card;
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? description;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final bool expands;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool clearable;
  final FTextFieldSizeVariant size;
  final FTextFieldStyleDelta style;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.description,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.expands = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.clearable = false,
    this.size = FTextFieldSizeVariant.md,
    this.style = const FTextFieldStyleDelta.context(),
  });

  @override
  Widget build(BuildContext context) => FTextField(
    size: size,
    style: style,
    control: FTextFieldControl.managed(
      controller: controller,
      onChange: onChanged == null ? null : (value) => onChanged!(value.text),
    ),
    label: label == null ? null : Text(label!),
    hint: hint,
    description: description == null ? null : Text(description!),
    prefixBuilder: _iconBuilder(prefix),
    suffixBuilder: _iconBuilder(suffix),
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    inputFormatters: inputFormatters,
    textCapitalization: textCapitalization,
    textAlign: textAlign,
    focusNode: focusNode,
    onSubmit: onSubmitted,
    onTap: onTap,
    readOnly: readOnly,
    enabled: enabled,
    obscureText: obscureText,
    expands: expands,
    minLines: minLines,
    maxLines: maxLines,
    maxLength: maxLength,
    clearable: clearable
        ? (value) => value.text.isNotEmpty
        : FTextField.defaultClearable,
  );
}

class AppTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? description;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final bool expands;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool clearable;
  final FTextFieldSizeVariant size;
  final FTextFieldStyleDelta style;

  const AppTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.description,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.expands = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.clearable = false,
    this.size = FTextFieldSizeVariant.md,
    this.style = const FTextFieldStyleDelta.context(),
  });

  @override
  Widget build(BuildContext context) => FTextFormField(
    size: size,
    style: style,
    control: FTextFieldControl.managed(
      controller: controller,
      onChange: onChanged == null ? null : (value) => onChanged!(value.text),
    ),
    label: label == null ? null : Text(label!),
    hint: hint,
    description: description == null ? null : Text(description!),
    prefixBuilder: _iconBuilder(prefix),
    suffixBuilder: _iconBuilder(suffix),
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    inputFormatters: inputFormatters,
    textCapitalization: textCapitalization,
    textAlign: textAlign,
    focusNode: focusNode,
    onSubmit: onSubmitted,
    validator: validator,
    onTap: onTap,
    readOnly: readOnly,
    enabled: enabled,
    obscureText: obscureText,
    expands: expands,
    minLines: minLines,
    maxLines: maxLines,
    maxLength: maxLength,
    clearable: clearable
        ? (value) => value.text.isNotEmpty
        : FTextField.defaultClearable,
  );
}

FFieldIconBuilder<FTextFieldStyle>? _iconBuilder(Widget? icon) => icon == null
    ? null
    : (context, style, variants) =>
          FTextField.prefixIconBuilder(context, style, variants, icon);

/// 用于底部选项弹窗的单个选项：值、标题、可选副标题与图标。
class AppOption<T> {
  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;

  const AppOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
  });
}

/// 美观的选项选择弹窗内容：标题 + 可点选的卡片（图标 / 副标题 / 选中态）。
class AppOptionSheet<T> extends StatelessWidget {
  final String title;
  final T? value;
  final List<AppOption<T>> options;

  const AppOptionSheet({
    super.key,
    required this.title,
    required this.options,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.typography.tileTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final option in options) ...[
              _AppOptionTile<T>(
                theme: theme,
                option: option,
                selected: option.value == value,
                onTap: () => Navigator.pop(context, option.value),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppOptionTile<T> extends StatelessWidget {
  final FThemeData theme;
  final AppOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  const _AppOptionTile({
    required this.theme,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? theme.colors.secondary : theme.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colors.primary : theme.colors.border,
          ),
        ),
        child: Row(
          children: [
            if (option.leading != null || option.icon != null) ...[
              option.leading ??
                  Icon(
                    option.icon,
                    size: 22,
                    color: selected
                        ? theme.colors.primary
                        : theme.colors.mutedForeground,
                  ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (option.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle!,
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? FLucideIcons.check : FLucideIcons.circle,
              size: 20,
              color: selected ? theme.colors.primary : theme.colors.border,
            ),
          ],
        ),
      ),
    );
  }
}
