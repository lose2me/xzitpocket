/// Compares dotted numeric version names such as `2.2.0` and `2.3.0`.
///
/// Returns true only when [current] is newer than [previous]. A missing or
/// unparsable [previous] value is treated as "no known previous version", so a
/// fresh install never counts as an upgrade.
bool isVersionUpgrade(String? previous, String current) {
  final before = _parts(previous);
  final after = _parts(current);
  if (before == null || after == null) return false;
  final length = before.length > after.length ? before.length : after.length;
  for (var i = 0; i < length; i++) {
    final left = i < before.length ? before[i] : 0;
    final right = i < after.length ? after[i] : 0;
    if (right > left) return true;
    if (right < left) return false;
  }
  return false;
}

List<int>? _parts(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  // Versions may carry a suffix (`2.3.0-beta`); only the numeric prefix is
  // compared, which is enough to order released app versions.
  final numeric = RegExp(r'^\d+(?:\.\d+)*').stringMatch(text);
  if (numeric == null) return null;
  final parts = numeric.split('.').map(int.tryParse).toList();
  if (parts.any((part) => part == null)) return null;
  return parts.cast<int>();
}

/// Whether a launch should sign the account out because the build changed.
///
/// Builds that predate version tracking have no [previous] value; when such a
/// build is replaced, an existing signed-in account means it is an upgrade
/// (a fresh install has no account yet). Downgrades keep the session.
bool shouldLogoutAfterUpgrade({
  required String? previous,
  required String current,
  required bool loggedIn,
}) {
  if (!loggedIn) return false;
  if (previous == null || previous.trim().isEmpty) return true;
  return isVersionUpgrade(previous, current);
}
