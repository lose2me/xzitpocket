import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/services/hqgl_service.dart';

void main() {
  test('parseListHtml accepts flexible WebPlus list markup', () {
    const html = '''
      <ul>
        <li class="foo liebiao bar">
          <span class="date">2026-08-24</span>
          <a title="公告标题" href="../news/page.htm"><strong>公告标题</strong></a>
        </li>
      </ul>
      <em class="per_count">每页 14 条</em>
      <em class="all_count">共 29 条</em>
    ''';

    final page = HqglService.parseListHtml(
      html,
      pageUrl: 'https://hqglc.xzit.edu.cn/3585/list.htm',
      page: 2,
    );

    expect(page.page, 2);
    expect(page.perPage, 14);
    expect(page.total, 29);
    expect(page.totalPages, 3);
    expect(page.items.single.title, '公告标题');
    expect(page.items.single.date, '2026-08-24');
    expect(page.items.single.url, 'https://hqglc.xzit.edu.cn/news/page.htm');
  });

  group('HqglService.parseDetailHtml', () {
    test('parses WebPlus pdf player and attachment markup', () {
      const html = '''
        <html>
          <head><title>关于收费标准的公示</title></head>
          <body>
            <time>2026-07-28</time>
            <div class="content_Main"><div class="con_content">
              <div class="wp_articlecontent">
                <p>
                  <span id="正文.pdf" class="wp_pdf_player disabled"
                    pdfsrc="/_upload/article/files/body.pdf"
                    sudyfile-attr="{'title':'关于收费标准的公示.pdf'}"></span>
                  附件一：
                  <a href="/_upload/article/files/attachment.pdf"
                    sudyfile-attr="{'title':'相关文件.pdf'}">相关文件.pdf</a>
                </p>
              </div>
            </div></div>
          </body>
        </html>
      ''';

      final detail = HqglService.parseDetailHtml(
        html,
        pageUrl: 'https://hqglc.xzit.edu.cn/28/0f/article/page.htm',
      );

      expect(detail.title, '关于收费标准的公示');
      expect(detail.date, '2026-07-28');
      expect(detail.content, isEmpty);
      expect(detail.bodyPdfs, hasLength(1));
      expect(detail.bodyPdfs.single.name, '关于收费标准的公示.pdf');
      expect(
        detail.bodyPdfs.single.url,
        'https://hqglc.xzit.edu.cn/_upload/article/files/body.pdf',
      );
      expect(detail.attachments, hasLength(1));
      expect(detail.attachments.single.name, '相关文件.pdf');
    });

    test('supports alternate embedded PDF elements and relative URLs', () {
      const html = '''
        <html><head><title>PDF variants</title></head><body>
          <div class="con_content">
            <div data-pdfsrc="files/first.pdf?download=1"
              sudyfile-attr='{"title":"First.pdf"}'></div>
            <object data="//files.example.edu/second.PDF#page=1"
              title="Second.pdf"></object>
            <embed src="../third.pdf" />
            <iframe src="viewer.html"></iframe>
            <a href="files/first.pdf?download=1">duplicate.pdf</a>
            <a href="downloads/form.docx?download=1">附件：form.docx</a>
          </div>
        </body></html>
      ''';

      final detail = HqglService.parseDetailHtml(
        html,
        pageUrl: 'https://hqglc.xzit.edu.cn/news/item/page.htm',
      );

      expect(detail.bodyPdfs, hasLength(3));
      expect(detail.bodyPdfs.map((pdf) => pdf.name), [
        'First.pdf',
        'Second.pdf',
        'third.pdf',
      ]);
      expect(
        detail.bodyPdfs[0].url,
        endsWith('/news/item/files/first.pdf?download=1'),
      );
      expect(detail.bodyPdfs[1].url, startsWith('https://files.example.edu/'));
      expect(detail.attachments, hasLength(1));
      expect(detail.attachments.single.name, 'form.docx');
      expect(
        detail.attachments.single.url,
        'https://hqglc.xzit.edu.cn/news/item/downloads/form.docx?download=1',
      );
    });

    test('keeps ordinary article text while excluding file labels', () {
      const html = '''
        <html><head><title>Text notice</title></head><body>
          <div class="wp_articlecontent">
            <p>各部门、各学院：</p>
            <p>现将安排通知如下。</p>
            <p>附件二：<a href="report.pdf">检测报告.pdf</a></p>
          </div>
        </body></html>
      ''';

      final detail = HqglService.parseDetailHtml(
        html,
        pageUrl: 'https://hqglc.xzit.edu.cn/news/page.htm',
      );

      expect(detail.content, contains('各部门、各学院：'));
      expect(detail.content, contains('现将安排通知如下。'));
      expect(detail.content, isNot(contains('附件二')));
      expect(detail.content, isNot(contains('检测报告.pdf')));
      expect(detail.attachments.single.name, '检测报告.pdf');
    });
  });
}
