import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/pages/profile/profile_components.dart';
import 'package:xzitpocket/ui/app_page.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  testWidgets('profile setting rows keep a consistent height', (tester) async {
    await tester.pumpWidget(
      _testApp(
        ProfileSettingsGroup(
          children: [
            const ProfileSettingsTile(
              icon: FLucideIcons.badge,
              title: '学号',
              value: '20260001',
            ),
            ProfileSettingsToggleTile(
              icon: FLucideIcons.eye,
              title: '显示非本周课程',
              value: true,
              onChange: (_) {},
            ),
            const ProfileSettingsControlTile(
              icon: FLucideIcons.building2,
              title: '宿舍号',
              child: SizedBox(width: 112, height: 24),
            ),
          ],
        ),
      ),
    );

    final tiles = find.byType(FTile);
    expect(tiles, findsNWidgets(3));

    final heights = [
      for (var index = 0; index < 3; index++)
        tester.getSize(tiles.at(index)).height,
    ];
    final minHeight = heights.reduce((a, b) => a < b ? a : b);
    final maxHeight = heights.reduce((a, b) => a > b ? a : b);
    expect(maxHeight - minHeight, lessThanOrEqualTo(1), reason: '$heights');
  });

  testWidgets('AppPage does not resize for the keyboard', (tester) async {
    await tester.pumpWidget(_testApp(const AppPage(child: SizedBox.shrink())));

    final scaffold = tester.widget<FScaffold>(find.byType(FScaffold));
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
  });
}

Widget _testApp(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FTheme(
    data: AppTheme.light,
    child: Center(child: SizedBox(width: 360, child: child)),
  ),
);
