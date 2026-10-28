import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/app_settings.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  test('system font mode replaces the bundled Forui typeface', () {
    final bundled = AppTheme.lightFor(AppThemeColor.teal);
    final system = AppTheme.lightFor(AppThemeColor.teal, useSystemFont: true);
    expect(bundled.typography.body.sm.fontFamily, isNot('sans-serif'));
    expect(system.typography.body.sm.fontFamily, 'sans-serif');
    expect(system.typography.body.xs2.fontFamily, 'sans-serif');
    expect(system.typography.display.xl.fontFamily, 'sans-serif');
    // The custom sizes are preserved, only the family changes.
    expect(system.typography.body.sm.fontSize, 16);
    expect(system.typography.body.sm.height, 1.5);
  });

  test('dark theme honours the same switch', () {
    final system = AppTheme.darkFor(AppThemeColor.teal, useSystemFont: true);
    expect(system.typography.body.md.fontFamily, 'sans-serif');
  });
}
