import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/pages/profile/profile_components.dart';
import 'package:xzitpocket/ui/app_controls.dart';
import 'package:xzitpocket/ui/app_page.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  testWidgets('standard profile setting rows keep a consistent height', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        ProfileSettingsGroup(
          children: [
            const ProfileSettingsTile(
              icon: FLucideIcons.badge,
              title: '学号',
              value: '20260001',
            ),
            ProfileSettingsCheckboxTile(
              icon: FLucideIcons.eye,
              title: '显示非本周课程',
              value: true,
              onChange: (_) {},
            ),
          ],
        ),
      ),
    );

    final tiles = find.byType(FTile);
    expect(tiles, findsNWidgets(2));

    final heights = [
      for (var index = 0; index < 2; index++)
        tester.getSize(tiles.at(index)).height,
    ];
    final minHeight = heights.reduce((a, b) => a < b ? a : b);
    final maxHeight = heights.reduce((a, b) => a > b ? a : b);
    expect(maxHeight - minHeight, lessThanOrEqualTo(1), reason: '$heights');
  });

  testWidgets('profile control buttons sit beneath their label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        ProfileSettingsGroup(
          children: [
            ProfileSettingsControlTile(
              icon: FLucideIcons.bellOff,
              title: '课堂勿扰',
              child: ProfileSettingsOptionButtons<String>(
                value: '关闭',
                options: const [
                  ProfileSettingsOption(value: '关闭', label: '关闭'),
                  ProfileSettingsOption(value: '上课恢复', label: '上课恢复'),
                  ProfileSettingsOption(value: '保持勿扰', label: '保持勿扰'),
                ],
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    );

    final title = tester.getRect(find.text('课堂勿扰'));
    final button = tester.getRect(find.text('上课恢复'));
    expect(button.top, greaterThan(title.bottom));
    expect(button.width, greaterThan(60));
    expect(tester.getSize(find.byType(FButton).first).height, 28);
  });

  testWidgets('profile sliders use compact discrete controls', (tester) async {
    await tester.pumpWidget(
      _testApp(
        Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Material(
                color: Colors.transparent,
                child: ProfileSettingsGroup(
                  children: [
                    ProfileSettingsSliderTile(
                      icon: FLucideIcons.rows3,
                      title: '课节高度',
                      value: 80,
                      min: 40,
                      max: 140,
                      divisions: 100,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final theme = tester.widget<SliderTheme>(find.byType(SliderTheme));
    final thumb = theme.data.thumbShape! as RoundSliderThumbShape;
    final tick = theme.data.tickMarkShape! as RoundSliderTickMarkShape;
    expect(thumb.enabledThumbRadius, 6);
    expect(tick.tickMarkRadius, 0.35);
    expect(theme.data.trackHeight, 2);
    expect(tester.getSize(find.byType(Slider)).height, 16);
  });

  testWidgets('custom color picker opens and returns its selected color', (
    tester,
  ) async {
    const initialColor = Color(0xFF336699);
    Color? selectedColor;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: FLocalizations.localizationsDelegates,
        supportedLocales: FLocalizations.supportedLocales,
        builder: (context, child) => FTheme(
          data: AppTheme.light,
          child: FTooltipGroup(child: child!),
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selectedColor = await showProfileColorPicker(
                context: context,
                initialColor: initialColor,
              );
            },
            child: const Text('选择颜色'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择颜色'));
    await tester.pumpAndSettle();
    expect(find.byType(FDialog), findsOneWidget);
    expect(find.text('自定义颜色'), findsOneWidget);
    expect(find.text('明度'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(HSVColor.fromColor(selectedColor!).value, closeTo(0.75, 0.001));
  });

  testWidgets('inline profile control stays on one row', (tester) async {
    await tester.pumpWidget(
      _testApp(
        ProfileSettingsGroup(
          children: [
            const ProfileSettingsInlineControlTile(
              icon: FLucideIcons.building2,
              title: '宿舍号',
              child: SizedBox(width: 112, height: 32, child: Text('7B216')),
            ),
          ],
        ),
      ),
    );

    final title = tester.getRect(find.text('宿舍号'));
    final value = tester.getRect(find.text('7B216'));
    expect(value.center.dy, closeTo(title.center.dy, 1));
    expect(value.left, greaterThan(title.right));
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
