import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(
      AppTheme.light.colors.semantic.timetableForeground,
      AppTheme.dark.colors.semantic.timetableForeground,
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
