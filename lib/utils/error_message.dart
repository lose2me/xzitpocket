/// Formats [error] for display without the Dart type prefix that
/// `toString()` adds (e.g. `FormatException: `, `DioException [bad response]: `).
///
/// The app's own exceptions (`ControlApiException`, `WidgetSyncException`,
/// `AuthException`, ...) already override `toString()` to return a clean
/// message, so those pass through unchanged.
String describeError(Object error) {
  if (error is FormatException) return error.message;
  final text = error.toString();
  final match = RegExp(
    r'^(?:[A-Za-z_][A-Za-z0-9_]*)?Exception(\s*\[[^\]]*\])?:\s+',
  ).firstMatch(text);
  return match == null ? text : text.substring(match.end);
}
