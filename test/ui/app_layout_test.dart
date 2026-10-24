import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
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

  group('AppPageBody', () {
    testWidgets('reserves the page gutter when requested', (tester) async {
      await _pumpBody(tester, width: 390, pageGutter: true);

      expect(tester.getSize(find.byKey(_bodyChildKey)).width, 390 - 16 * 2);
    });

    testWidgets('skips the page gutter by default', (tester) async {
      await _pumpBody(tester, width: 390, pageGutter: false);

      expect(tester.getSize(find.byKey(_bodyChildKey)).width, 390);
    });
  });

  group('pull-to-refresh', () {
    testWidgets('AppPageListView refreshes on pull', (tester) async {
      var refreshed = 0;
      await _pumpRefresh(
        tester,
        AppPageListView(
          onRefresh: () async => refreshed++,
          children: const [SizedBox(height: 1)],
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, 320));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(refreshed, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('AppPageBody refreshes on pull', (tester) async {
      var refreshed = 0;
      await _pumpRefresh(
        tester,
        AppPageBody(
          onRefresh: () async => refreshed++,
          child: const SizedBox.expand(key: _bodyChildKey),
        ),
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 320),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(refreshed, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('indicator follows the pull back up and cancels', (
      tester,
    ) async {
      var refreshed = 0;
      await _pumpRefresh(
        tester,
        AppPageListView(
          onRefresh: () async => refreshed++,
          children: [for (var i = 0; i < 60; i++) const SizedBox(height: 100)],
        ),
      );

      final gesture = await tester.startGesture(const Offset(195, 400));
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
      }
      final pulled = tester
          .getTopLeft(find.byType(RefreshProgressIndicator))
          .dy;

      // Dragging back up without releasing must retract the indicator instead
      // of leaving it stuck at the armed position or wiping it out at once
      // when the list itself starts scrolling back to the top.
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -5));
        await tester.pump();
      }
      final partiallyRetracted = tester
          .getTopLeft(find.byType(RefreshProgressIndicator))
          .dy;
      expect(partiallyRetracted, lessThan(pulled));

      for (var i = 0; i < 18; i++) {
        await gesture.moveBy(const Offset(0, -5));
        await tester.pump();
      }
      final retracted = tester
          .getTopLeft(find.byType(RefreshProgressIndicator))
          .dy;
      expect(retracted, lessThan(partiallyRetracted - 20));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(refreshed, 0);
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });

    testWidgets('locks the page until the indicator retracts', (tester) async {
      final gate = Completer<void>();
      final states = <bool>[];
      await _pumpRefresh(
        tester,
        AppRefreshIndicator(
          onRefresh: () => gate.future,
          onRefreshingChanged: states.add,
          child: ListView(
            children: [
              for (var i = 0; i < 60; i++) const SizedBox(height: 100),
            ],
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, 320));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(states, [true]);
      final locked = tester.widget<IgnorePointer>(
        find
            .descendant(
              of: find.byType(AppRefreshIndicator),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(locked.ignoring, isTrue);

      gate.complete();
      await tester.pumpAndSettle();

      expect(states, [true, false]);
      final unlocked = tester.widget<IgnorePointer>(
        find
            .descendant(
              of: find.byType(AppRefreshIndicator),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(unlocked.ignoring, isFalse);
    });

    testWidgets('stays locked while a cancelled pull retracts', (tester) async {
      await _pumpRefresh(
        tester,
        AppPageListView(
          onRefresh: () async {},
          children: [for (var i = 0; i < 60; i++) const SizedBox(height: 100)],
        ),
      );

      bool locked() => tester
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byType(AppRefreshIndicator),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring;

      final gesture = await tester.startGesture(const Offset(195, 400));
      await tester.pump();
      // 100px < the 200px trigger threshold: this pull will be cancelled.
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
      }
      expect(locked(), isFalse);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(locked(), isTrue);

      // Swiping up while the indicator retracts must not scroll the page.
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      final offset = position.pixels;
      await tester.drag(
        find.byType(ListView),
        const Offset(0, -80),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(position.pixels, offset);

      await tester.pumpAndSettle();
      expect(locked(), isFalse);
    });

    testWidgets('disables the platform overscroll stretch', (tester) async {
      await _pumpRefresh(
        tester,
        ListView(
          children: [for (var i = 0; i < 10; i++) const SizedBox(height: 100)],
        ),
      );
      expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);

      await _pumpRefresh(
        tester,
        AppRefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            children: [
              for (var i = 0; i < 10; i++) const SizedBox(height: 100),
            ],
          ),
        ),
      );
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
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

Future<void> _pumpRefresh(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    FTheme(
      data: AppTheme.light,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
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

const _bodyChildKey = ValueKey('app-page-body-child');

Future<void> _pumpBody(
  WidgetTester tester, {
  required double width,
  required bool pageGutter,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: AppPageBody(
          pageGutter: pageGutter,
          child: const SizedBox.expand(key: _bodyChildKey),
        ),
      ),
    ),
  );
}
