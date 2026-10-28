import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xzitpocket/services/power_service.dart';
import 'package:xzitpocket/ui/app_theme.dart';
import 'package:xzitpocket/widgets/power_usage_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: FLocalizations.localizationsDelegates,
    supportedLocales: FLocalizations.supportedLocales,
    builder: (context, content) =>
        FTheme(data: AppTheme.light, child: content!),
    home: Scaffold(body: child),
  );

  String iso(DateTime date) => date.toIso8601String();

  testWidgets('shows a hint when there is no drawable usage', (tester) async {
    await tester.pumpWidget(
      wrap(const PowerUsageChart(usage: [], showMoney: false, price: '0.54')),
    );
    expect(find.text('暂无可绘制的用电记录'), findsOneWidget);
  });

  testWidgets('ignores unusable rows and draws the valid series', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      wrap(
        PowerUsageChart(
          usage: [
            PowerDailyUsage(date: iso(now), usage: '1.5', isoDate: iso(now)),
            const PowerDailyUsage(date: 'bad', usage: 'not-a-number'),
            PowerDailyUsage(
              date: iso(now.subtract(const Duration(days: 2))),
              usage: '2',
              isoDate: iso(now.subtract(const Duration(days: 2))),
            ),
            PowerDailyUsage(
              date: iso(now.subtract(const Duration(days: 40))),
              usage: '9',
              isoDate: iso(now.subtract(const Duration(days: 40))),
            ),
          ],
          showMoney: false,
          price: '0.54',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('暂无可绘制的用电记录'), findsNothing);
    expect(find.byType(PowerUsageChart), findsOneWidget);
  });

  testWidgets('multiplies usage by a parsed price', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      wrap(
        PowerUsageChart(
          usage: [
            PowerDailyUsage(date: iso(now), usage: '10', isoDate: iso(now)),
          ],
          showMoney: true,
          price: 'not-a-price',
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PowerUsageChart), findsOneWidget);
  });
}
