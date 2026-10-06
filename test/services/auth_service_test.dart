import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/services/auth_service.dart';

void main() {
  test('academic cache accepts the current format', () {
    const status = AcademicStatus(
      gpa: 3.2,
      totalRequired: 160,
      totalEarned: 80,
      categories: [],
    );

    final restored = AcademicStatus.fromJson(
      jsonDecode(jsonEncode(status.toJson())) as Map<String, dynamic>,
    );

    expect(restored.gpa, 3.2);
    expect(restored.parserVersion, AcademicStatus.currentParserVersion);
  });

  test('academic cache rejects a payload without the current version', () {
    expect(
      () => AcademicStatus.fromJson({
        'gpa': 3.2,
        'totalRequired': 160,
        'totalEarned': 80,
        'categories': const [],
      }),
      throwsFormatException,
    );
  });
}
