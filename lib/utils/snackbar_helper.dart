import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..removeCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      content: SizedBox(
        width: double.infinity,
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}
