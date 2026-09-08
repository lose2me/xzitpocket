import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/in_flight_operation.dart';

void main() {
  test('concurrent callers share the active operation', () async {
    final operation = InFlightOperation<int>();
    final completer = Completer<int>();
    var calls = 0;

    Future<int> run() {
      calls++;
      return completer.future;
    }

    final first = operation.run(run);
    final second = operation.run(run);

    expect(identical(first, second), isTrue);
    expect(calls, 1);

    completer.complete(42);
    expect(await first, 42);
    expect(await second, 42);
  });

  test('a completed operation can be started again', () async {
    final operation = InFlightOperation<int>();
    var calls = 0;

    Future<int> run() async => ++calls;

    expect(await operation.run(run), 1);
    expect(await operation.run(run), 2);
  });

  test('an invalidated operation cannot clear its replacement', () async {
    final operation = InFlightOperation<int>();
    final oldCompleter = Completer<int>();
    final newCompleter = Completer<int>();
    var calls = 0;

    Future<int> run() {
      calls++;
      return calls == 1 ? oldCompleter.future : newCompleter.future;
    }

    final oldFuture = operation.run(run);
    operation.invalidate();
    final newFuture = operation.run(run);

    oldCompleter.complete(1);
    expect(await oldFuture, 1);

    final sharedReplacement = operation.run(run);
    expect(identical(newFuture, sharedReplacement), isTrue);
    expect(calls, 2);

    newCompleter.complete(2);
    expect(await newFuture, 2);
  });

  test('runAfterCurrent always starts after the active operation', () async {
    final operation = InFlightOperation<int>();
    final activeCompleter = Completer<int>();
    var calls = 0;

    final active = operation.run(() {
      calls++;
      return activeCompleter.future;
    });
    final fresh = operation.runAfterCurrent(() async => ++calls);

    expect(calls, 1);
    activeCompleter.complete(1);
    expect(await active, 1);
    expect(await fresh, 2);
    expect(calls, 2);
  });

  test('runAfterCurrent proceeds after a failed active operation', () async {
    final operation = InFlightOperation<int>();
    final activeCompleter = Completer<int>();

    final active = operation.run(() => activeCompleter.future);
    final fresh = operation.runAfterCurrent(() async => 2);

    activeCompleter.completeError(StateError('failed'));
    await expectLater(active, throwsStateError);
    expect(await fresh, 2);
  });
}
