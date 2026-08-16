import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  if (!context.mounted) return;
  showFToast(
    context: context,
    title: Text(message),
    alignment: FToastAlignment.bottomCenter,
    duration: duration,
  );
}
