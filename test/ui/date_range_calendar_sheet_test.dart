import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/ui/app_theme.dart';
import 'package:xzitpocket/ui/date_range_calendar_sheet.dart';

void main() {
  test('student history starts on June 1 of the admission year', () {
    expect(
      studentHistoryStartDate('25070100246', today: DateTime(2026, 9, 13)),
      DateTime(2025, 6, 1),
    );
  });

  test('student history never starts in the future', () {
    expect(
      studentHistoryStartDate('26000000000', today: DateTime(2026, 3, 1)),
      DateTime(2026, 3, 1),
    );
  });

  testWidgets('date-range picker opens as a full page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: FLocalizations.localizationsDelegates,
        supportedLocales: FLocalizations.supportedLocales,
        builder: (context, child) =>
            FTheme(data: AppTheme.light, child: child!),
        home: AppDateRangeCalendarPage(
          initial: (DateTime(2026, 9, 1), DateTime(2026, 10, 5)),
          minDate: DateTime(2026, 6, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FScaffold), findsOneWidget);
    expect(find.text('选择日期范围'), findsOneWidget);
    expect(find.text('选择全部'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.textContaining('~'), findsNothing);
    expect(find.text('1日'), findsNothing);
    expect(find.text('5日'), findsNothing);
  });
}
