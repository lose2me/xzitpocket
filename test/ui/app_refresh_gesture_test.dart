import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xzitpocket/ui/app_page.dart';
import 'package:xzitpocket/ui/app_theme.dart';

const _marker = ValueKey('stationary-refresh-content');

void main() {
  for (final armed in [false, true]) {
    testWidgets(
      'locks PageView through ${armed ? 'refresh' : 'cancellation'}',
      (tester) async {
        final pages = PageController();
        final scroll = ScrollController();
        final gate = Completer<void>();
        addTearDown(pages.dispose);
        addTearDown(scroll.dispose);
        var active = false;
        var refreshes = 0;
        await _pump(
          tester,
          StatefulBuilder(
            builder: (context, setState) => PageView(
              controller: pages,
              physics: active ? const NeverScrollableScrollPhysics() : null,
              children: [
                AppRefreshIndicator(
                  onRefreshingChanged: (value) =>
                      setState(() => active = value),
                  onRefresh: () {
                    refreshes++;
                    return gate.future;
                  },
                  child: _content(scroll),
                ),
                const ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        );

        Future<void> expectBlocked() async {
          final second = await tester.startGesture(
            const Offset(320, 350),
            pointer: 2,
          );
          await second.moveBy(const Offset(-240, 0));
          await tester.pump();
          await second.up();
          await tester.pump();
          expect(pages.page, 0);
          expect(scroll.offset, 0);
          expect(active, isTrue);
        }

        final drag = await tester.startGesture(const Offset(195, 150));
        for (var i = 0; i < (armed ? 50 : 20); i++) {
          await drag.moveBy(const Offset(0, 6));
          await tester.pump();
        }
        await expectBlocked();
        await drag.up();
        await tester.pump();

        if (armed) {
          await tester.pump(const Duration(milliseconds: 160));
          expect(refreshes, 1);
          await expectBlocked();
          gate.complete();
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 60));
        await expectBlocked();
        await tester.pumpAndSettle();
        expect(active, isFalse);
        expect(find.byType(RefreshProgressIndicator), findsNothing);
        expect(refreshes, armed ? 1 : 0);

        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(pages.page, 1);
      },
    );
  }

  testWidgets('pointer cancellation never refreshes an armed pull', (
    tester,
  ) async {
    var refreshes = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      AppRefreshIndicator(
        onRefresh: () async => refreshes++,
        child: _content(controller),
      ),
    );
    final gesture = await tester.startGesture(const Offset(195, 150));
    await gesture.moveBy(const Offset(0, 320));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(refreshes, 0);
    expect(controller.offset, 0);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });
}

Widget _content(ScrollController controller) => SingleChildScrollView(
  controller: controller,
  physics: const AlwaysScrollableScrollPhysics(),
  child: const SizedBox(
    key: _marker,
    width: double.infinity,
    height: 2400,
    child: ColoredBox(color: Colors.orange),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    FTheme(
      data: AppTheme.light,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(body: child),
      ),
    ),
  );
}
