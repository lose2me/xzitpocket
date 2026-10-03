import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/app_settings.dart';
import 'package:xzitpocket/ui/app_components.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  group('AppLayout', () {
    testWidgets('uses compact page gutter below 600dp', (tester) async {
      await _pumpList(tester, width: 390);

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding, const EdgeInsets.fromLTRB(16, 12, 16, 20));
    });

    testWidgets('uses medium page gutter from 600dp', (tester) async {
      await _pumpList(tester, width: 700);

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding, const EdgeInsets.fromLTRB(24, 12, 24, 20));
    });

    testWidgets('centers expanded content at its maximum width', (
      tester,
    ) async {
      await _pumpList(tester, width: 1200);

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding, const EdgeInsets.fromLTRB(120, 12, 120, 20));
    });
  });

  test('appRoute stores a stable route name', () {
    final route = appRoute<void>(
      name: AppRouteNames.campusCard,
      builder: (_) => const SizedBox.shrink(),
    );

    expect(route.settings.name, '/tools/campus-card');
  });

  test('light and dark themes expose semantic colors', () {
    expect(AppTheme.light.colors.semantic.success, isNotNull);
    expect(AppTheme.dark.colors.semantic.warning, isNotNull);
    expect(AppTheme.light.colors.semantic.timetableForeground, isNotNull);
    expect(AppTheme.dark.colors.semantic.timetableForeground, isNotNull);
    expect(
      AppTheme.light.colors.semantic.timetableForeground,
      isNot(AppTheme.dark.colors.semantic.timetableForeground),
    );
  });

  test('global page background color harmonizes surfaces in both themes', () {
    final light = AppTheme.lightFor(
      AppThemeColor.rose,
      pageBackgroundColor: AppPageBackgroundColor.teal,
    );
    final dark = AppTheme.darkFor(
      AppThemeColor.rose,
      pageBackgroundColor: AppPageBackgroundColor.teal,
    );

    expect(light.colors.background, AppPageBackgroundColor.teal.lightColor);
    expect(dark.colors.background, AppPageBackgroundColor.teal.darkColor);
    expect(light.colors.card, isNot(AppTheme.light.colors.card));
    expect(light.colors.muted, isNot(AppTheme.light.colors.muted));
    expect(light.colors.border, isNot(AppTheme.light.colors.border));
    expect(
      light.colors.semantic.controlBorder,
      isNot(AppTheme.light.colors.semantic.controlBorder),
    );
    expect(dark.colors.card, isNot(AppTheme.dark.colors.card));
    expect(dark.colors.muted, isNot(AppTheme.dark.colors.muted));
    expect(dark.colors.border, isNot(AppTheme.dark.colors.border));
    expect(
      dark.colors.semantic.controlBorder,
      isNot(AppTheme.dark.colors.semantic.controlBorder),
    );
  });
}

Future<void> _pumpList(WidgetTester tester, {required double width}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: AppPageListView(children: [SizedBox(height: 1)]),
      ),
    ),
  );
}
