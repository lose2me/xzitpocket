import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xzitpocket/ui/app_page.dart';
import 'package:xzitpocket/ui/app_theme.dart';

const _marker = ValueKey('stationary-refresh-content');

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform keeps content still through pull and reversal', (
      tester,
    ) async {
      var refreshes = 0;
      final states = <bool>[];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        AppRefreshIndicator(
          onRefresh: () async => refreshes++,
          onRefreshingChanged: states.add,
          child: _content(controller),
        ),
        platform: platform,
      );

      final initialRect = tester.getRect(find.byKey(_marker));
      void expectStill() {
        expect(controller.offset, 0);
        expect(tester.getRect(find.byKey(_marker)), initialRect);
      }

      final gesture = await tester.startGesture(const Offset(195, 300));
      for (var i = 0; i < 25; i++) {
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump();
        expectStill();
      }
      final pulled = tester.getTopLeft(find.byType(RefreshProgressIndicator));

      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, -6));
        await tester.pump();
        expectStill();
      }
      expect(
        tester.getTopLeft(find.byType(RefreshProgressIndicator)).dy,
        lessThan(pulled.dy),
      );

      // Go well beyond the original touch point without lifting. A zero
      // indicator extent must not hand the same gesture back to the list.
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(0, -6));
        await tester.pump();
        expectStill();
      }
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(states, [true]);

      await gesture.up();
      await tester.pumpAndSettle();
      expectStill();
      expect(refreshes, 0);
      expect(states, [true, false]);

      // A new upward gesture retains ordinary scrolling and fling behavior.
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, -160),
        800,
      );
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(160));
    });
  }

  testWidgets('normal scrolling from the middle does not start refresh', (
    tester,
  ) async {
    final controller = ScrollController(initialScrollOffset: 240);
    addTearDown(controller.dispose);
    final states = <bool>[];
    await _pump(
      tester,
      AppRefreshIndicator(
        onRefresh: () async {},
        onRefreshingChanged: states.add,
        child: _content(controller),
      ),
    );
    final gesture = await tester.startGesture(const Offset(195, 200));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(controller.offset, lessThan(240));
    expect(controller.offset, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(states, isEmpty);
  });

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
