# Vendored `talker_flutter`

- Base: upstream `talker_flutter` 5.1.21 from pub.dev. Its `lib/` is identical
  to 5.1.20; 5.1.21 only bumps the `talker` dependency.
- Local changes on top of upstream:
  - Chinese UI strings in the screen, actions, settings, monitor and copy
    snackbars.
  - `TalkerViewAppBar`: compute the filter-bar height once after the first
    frame instead of re-registering the post-frame callback from
    `didChangeMetrics`.
  - `run_talker_zoned_guarded`: dump the full Flutter error (including source
    location) in debug builds.
- Why vendored: upstream has no localized strings and does not contain the
  height fix, so the package cannot be replaced with the pub dependency yet.
- It still imports `package:flutter/material.dart`; `app.dart` wraps the app in
  `MaterialUiCompatibilityBridge` so the legacy Material widgets resolve the
  `material_ui` theme and localizations.
- Updating:
  1. Download the new pub.dev archive and diff its `lib/` against this copy.
  2. Re-apply the local changes above.
  3. Bump the `talker` dependency range here, run `flutter pub get` and
     `flutter test`.
  4. Also update `talker` / `talker_dio_logger` in the app `pubspec.yaml` so the
     vendored package and the app stay on the same release line.
