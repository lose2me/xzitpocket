import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/ui/scroll_debug_probe.dart';

void main() {
  testWidgets('scroll geometry sampling respects its compile-time flag', (
    tester,
  ) async {
    final controller = ScrollController();
    final contentKey = GlobalKey();
    final messages = <String?>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => messages.add(message);
    addTearDown(() {
      debugPrint = previousDebugPrint;
      controller.dispose();
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScrollDebugProbe(
          controller: controller,
          contentKey: contentKey,
          label: 'test',
          child: SingleChildScrollView(
            controller: controller,
            child: SizedBox(key: contentKey, height: 2000),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (ScrollDebugProbe.enabled) {
      expect(messages, isNotEmpty);
      expect(messages.last, contains('pixels=0.000'));
      expect(messages.last, contains('relative='));
      expect(messages.last, contains('screen='));
      expect(messages.last, contains('viewport=[0.0, 0.0,'));
      expect(messages.last, contains('content=[0.0, 0.0,'));
      expect(messages.last, contains('stretch=[]'));
      controller.jumpTo(60);
      await tester.pump(const Duration(milliseconds: 20));
      expect(messages.last, contains('pixels=60.000'));
    } else {
      expect(messages, isEmpty);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugPrint = previousDebugPrint;
  });
}
