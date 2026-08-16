import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'app_tokens.dart';

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPress;
  final String tooltip;
  final FButtonVariant variant;
  final FButtonSizeVariant size;
  final bool loading;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPress,
    required this.tooltip,
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
          : Icon(icon),
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

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onPress;

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
