import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  testWidgets('keeps log records visible after the app bar settles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final talker = Talker(settings: TalkerSettings(useConsoleLogs: false))
      ..debug('visible debug record');

    await tester.pumpWidget(
      MaterialApp(home: TalkerScreen(talker: talker, isLogsExpanded: false)),
    );
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final record = find.text('visible debug record');
    expect(record, findsOneWidget);
    expect(tester.getTopLeft(record).dy, lessThan(844));
    expect(
      tester.widget<SliverAppBar>(find.byType(SliverAppBar)).expandedHeight,
      lessThan(300),
    );
  });
}
