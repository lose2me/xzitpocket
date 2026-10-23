import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/ui/app_skeleton.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  testWidgets('pulses a skeleton group and exposes one loading label', (
    tester,
  ) async {
    await tester.pumpWidget(
      FTheme(
        data: AppTheme.light,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: AppSkeleton(
            label: '正在加载报修进度',
            child: Column(
              children: [
                AppSkeletonBox(width: 120, height: 12),
                AppSkeletonBox(width: 10, height: 10, circle: true),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AppSkeletonBox), findsNWidgets(2));
    expect(find.bySemanticsLabel('正在加载报修进度'), findsOneWidget);

    final before = tester
        .widget<FadeTransition>(find.byType(FadeTransition))
        .opacity
        .value;
    await tester.pump(const Duration(milliseconds: 450));
    final after = tester
        .widget<FadeTransition>(find.byType(FadeTransition))
        .opacity
        .value;
    expect(after, isNot(before));
  });

  testWidgets('stays static when the platform disables animations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: FTheme(
          data: AppTheme.light,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: AppSkeleton(child: AppSkeletonBox(width: 80, height: 12)),
          ),
        ),
      ),
    );

    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
    expect(fade.opacity.value, 1);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}
