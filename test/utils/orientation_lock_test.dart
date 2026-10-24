import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/orientation_lock.dart';

void main() {
  test('locks portrait below the tablet breakpoint in both orientations', () {
    expect(shouldLockPortrait(const Size(390, 844)), isTrue);
    expect(shouldLockPortrait(const Size(844, 390)), isTrue);
  });

  test('keeps rotation on tablets', () {
    expect(shouldLockPortrait(const Size(600, 960)), isFalse);
    expect(shouldLockPortrait(const Size(960, 600)), isFalse);
  });
}
