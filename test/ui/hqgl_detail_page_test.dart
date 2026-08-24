import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/pages/notices/hqgl_detail_page.dart';
import 'package:xzitpocket/services/hqgl_service.dart';
import 'package:xzitpocket/services/notice_service.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  testWidgets('shows parsed attachments before they are downloaded', (
    tester,
  ) async {
    var downloadCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: FTheme(
          data: AppTheme.light,
          child: HqglDetailPage(
            item: const NoticeItem(
              title: '后勤公告',
              url: 'https://example.test/page.htm',
              date: '2026-07-28',
            ),
            fetchDetail: (_) async => const HqglDetailResult(
              title: '后勤公告详情',
              date: '2026-07-28',
              attachments: [
                NoticeAttachment(
                  name: '附件一.pdf',
                  url: 'https://example.test/attachment.pdf',
                ),
              ],
            ),
            downloadAttachment: (_, _) async => downloadCalled = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('附件一.pdf'), findsOneWidget);
    expect(find.text('该公告暂无可见内容'), findsNothing);
    expect(downloadCalled, isFalse);
  });
}
