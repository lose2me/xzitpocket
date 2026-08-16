import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/pages/profile/profile_components.dart';
import 'package:xzitpocket/ui/app_controls.dart';
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

  testWidgets('routed AppPage resizes to keep fields above the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const AppPage(child: SizedBox.shrink())));

    final scaffold = tester.widget<FScaffold>(find.byType(FScaffold));
    expect(scaffold.resizeToAvoidBottomInset, isTrue);
  });

  testWidgets('root AppPage delegates keyboard insets to the home shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const AppPage(root: true, child: SizedBox.shrink())),
    );

    final scaffold = tester.widget<FScaffold>(find.byType(FScaffold));
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
  });

  testWidgets('AppTextField keeps Forui keyboard scroll padding', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const AppTextField()));

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.scrollPadding, const EdgeInsets.all(20));
  });

  testWidgets('focused field scrolls only far enough to clear the keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);

    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    final overlayEntry = OverlayEntry(
      builder: (_) => _testApp(
        SizedBox(
          height: 640,
          child: FScaffold(
            childPad: false,
            footer: const SizedBox(height: 64),
            child: AppPage(
              root: true,
              child: AppPageListView(
                controller: scrollController,
                topPadding: 0,
                children: const [
                  SizedBox(height: 520),
                  AppTextField(label: '测试输入框'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    addTearDown(() {
      if (overlayEntry.mounted) overlayEntry.remove();
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(initialEntries: [overlayEntry]),
      ),
    );

    await tester.showKeyboard(find.byType(EditableText));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(scrollController.offset, greaterThan(0));
    final editable = find.byType(EditableText, skipOffstage: false);
    expect(editable, findsOneWidget);
    expect(tester.getBottomRight(editable).dy, lessThanOrEqualTo(340));
  });
}

Widget _testApp(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FTheme(
    data: AppTheme.light,
    child: Center(child: SizedBox(width: 360, child: child)),
  ),
);
