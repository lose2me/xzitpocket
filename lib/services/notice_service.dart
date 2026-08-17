import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../constants/network_config.dart';
import 'dio_factory.dart';
import 'talker.dart';

/// 一条学生公告。
class NoticeItem {
  final String title;
  final String url;
  final String date;

  const NoticeItem({required this.title, required this.url, required this.date});
}

/// 一页公告列表的解析结果。
class NoticePage {
  final List<NoticeItem> items;
  final int page;
  final int perPage;
  final int total;

  const NoticePage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  int get totalPages => perPage <= 0 ? 0 : (total / perPage).ceil();
}

/// 公告附件。
class NoticeAttachment {
  final String name;
  final String url;

  const NoticeAttachment({required this.name, required this.url});
}

/// 公告详情（正文为 Markdown 文本，由 flutter_markdown_plus 渲染）。
class NoticeDetail {
  final String title;
  final String date;

  /// 通知文号，如「教务通知[2026]59号」，无则 null。
  final String? documentNo;

  /// 正文 Markdown（保留加粗、列表、表格等）。
  final String content;
  final List<NoticeAttachment> attachments;

  const NoticeDetail({
    required this.title,
    required this.date,
    required this.content,
    this.documentNo,
    this.attachments = const [],
  });
}

/// 教务处「学生公告」抓取服务。
///
/// 站点为苏迪 WebPlus 建站系统，无公开 JSON API（已探测确认），
/// 列表为服务端渲染 HTML，直接解析即可：
/// - 列表页：https://jwc.xzit.edu.cn/6057/list.htm（第 N 页为 listN.htm，每页 14 条）
/// - 详情页：https://jwc.xzit.edu.cn/{path}/page.htm，正文在 `.wp_articlecontent`，
///   解析为 Markdown 后交给 MarkdownBody 渲染（加粗/列表/表格）。
class NoticeService {
  static const baseUrl = 'https://jwc.xzit.edu.cn';
  static const listColumnPath = '/6057';

  static final _listItemReg = RegExp(
    "<li class=\"list_item[^\"]*\">\\s*<a href='([^']+)'[^>]*title='([^']*)'",
  );
  static final _itemDateReg = RegExp(r'<span>([\d-]+)</span>');
  static final _perCountReg = RegExp(r'class="per_count"[^>]*>(\d+)</em>');
  static final _allCountReg = RegExp(r'class="all_count"[^>]*>(\d+)</em>');

  /// 判断是否附件链接（/upload 路径或常见文件后缀）。
  static final _attachmentHrefReg = RegExp(
    r'/_?upload/|\.(docx?|xlsx?|pptx?|pdf|zip|rar|7z|txt|wps|et)$',
    caseSensitive: false,
  );
  static final _headingLevelReg = RegExp(r'^h([1-6])$');

  Dio? _dio;

  Dio _client() =>
      _dio ??= DioFactory.createNaked(
        cookieJar: CookieJar(),
        connectTimeout: requestTimeout,
        receiveTimeout: requestTimeout,
        userAgent: kUserAgent,
      );

  /// 抓取指定页码的公告列表（页码从 1 开始）。
  Future<NoticePage> fetchList({int page = 1}) async {
    final path = page <= 1 ? 'list' : 'list$page';
    final url = '$baseUrl$listColumnPath/$path.htm';
    talker.debug('[NET] 公告列表\n$url');

    final resp = await _client().get<String>(url);
    final html = resp.data ?? '';
    if (html.isEmpty) {
      throw const NoticeException('公告页面为空');
    }

    final items = <NoticeItem>[];
    for (final m in _listItemReg.allMatches(html)) {
      final href = m.group(1)?.trim() ?? '';
      final title = m.group(2)?.trim() ?? '';
      if (href.isEmpty || title.isEmpty) continue;

      final tail = html.substring(m.end, (m.end + 200).clamp(0, html.length));
      final date = _itemDateReg.firstMatch(tail)?.group(1)?.trim() ?? '';

      items.add(
        NoticeItem(
          title: title,
          url: href.startsWith('http') ? href : '$baseUrl$href',
          date: date,
        ),
      );
    }

    final perPage =
        int.tryParse(_perCountReg.firstMatch(html)?.group(1) ?? '') ?? 14;
    final total =
        int.tryParse(_allCountReg.firstMatch(html)?.group(1) ?? '') ??
        items.length;

    return NoticePage(items: items, page: page, perPage: perPage, total: total);
  }

  /// 抓取公告详情：正文 HTML 解析为 Markdown。
  Future<NoticeDetail> fetchDetail(String url) async {
    talker.debug('[NET] 公告详情\n$url');
    final resp = await _client().get<String>(url);
    final html = resp.data ?? '';
    if (html.isEmpty) {
      throw const NoticeException('公告页面为空');
    }

    final doc = html_parser.parse(html);
    final title =
        doc.querySelector('title')?.text.trim() ??
        RegExp(r'<title>\s*(.*?)\s*</title>', dotAll: true)
            .firstMatch(html)
            ?.group(1)
            ?.trim() ??
        '';

    final date =
        RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(html)?.group(1) ?? '';

    // 正文容器：优先 wp_articlecontent，回退 .content
    final root =
        doc.querySelector('.wp_articlecontent') ?? doc.querySelector('.content');

    final attachments = <NoticeAttachment>[];
    if (root != null) {
      for (final a in root.querySelectorAll('a')) {
        final href = a.attributes['href'] ?? '';
        if (href.isEmpty || !_attachmentHrefReg.hasMatch(href)) continue;
        var name = a.text.trim();
        // 跳过编辑器残留的空链接（无显示文本的 <a>，浏览器不渲染）。
        if (name.isEmpty) continue;
        name = _stripAttachmentPrefix(name);
        attachments.add(
          NoticeAttachment(
            name: name,
            url: href.startsWith('http') ? href : '$baseUrl$href',
          ),
        );
      }
    }

    final markdown =
        root == null ? '' : _htmlToMarkdown(root, attachments);
    final (cleanedMarkdown, documentNo) = _extractDocumentNo(markdown);

    return NoticeDetail(
      title: title,
      date: date,
      content: cleanedMarkdown,
      documentNo: documentNo,
      attachments: attachments,
    );
  }

  /// 从 Markdown 正文中提取通知文号（如「教务通知[2026]59号」），并移除所在段落。
  (String, String?) _extractDocumentNo(String markdown) {
    final docNoReg = RegExp(r'教务通知\[\d{4}\]\d+号');
    final paragraphs = markdown.split('\n\n');
    for (final paragraph in paragraphs) {
      final match = docNoReg.firstMatch(paragraph);
      if (match != null) {
        return (paragraphs.where((p) => p != paragraph).join('\n\n'),
            match.group(0));
      }
    }
    return (markdown, null);
  }

  /// 下载附件到本地指定路径。
  Future<void> downloadAttachment(String url, String savePath) async {
    talker.debug('[NET] 公告附件下载\n$url');
    await _client().download(
      url,
      savePath,
      deleteOnError: true,
    );
  }

  /// 附件名格式化：从头数，找到第一个点（.）或冒号（: 或 ：）
  /// （扩展名前的点除外），删除包括该符号在内的前缀。
  String _stripAttachmentPrefix(String name) {
    for (var i = 0; i < name.length; i++) {
      final ch = name[i];
      if (ch == '.' || ch == ':' || ch == '：') {
        // 扩展名前的点（最后一个点，且后面是非空扩展名）不算符号。
        if (ch == '.' && _isExtensionDot(name, i)) continue;
        final rest = name.substring(i + 1).trim();
        return rest.isEmpty ? name : rest;
      }
    }
    return name;
  }

  /// 判断位置 [i] 的点是否为扩展名前分隔符（最后一个点，且其后有内容）。
  bool _isExtensionDot(String name, int i) {
    final after = name.substring(i + 1);
    return !after.contains('.') && after.isNotEmpty;
  }

  /// 将正文 HTML（.wp_articlecontent）转换为 Markdown：
  /// 段落/标题/加粗/斜体/列表/表格/链接，附件链接跳过，<br> 保留换行。
  String _htmlToMarkdown(
    html_dom.Element root,
    List<NoticeAttachment> attachments,
  ) {
    final out = StringBuffer();

    void walk(html_dom.Node node) {
      if (node is html_dom.Text) {
        out.write(_escapeEmails(node.text));
        return;
      }
      if (node is! html_dom.Element) return;

      final name = node.localName ?? '';
      if (name == 'table') {
        out.write('\n\n${_tableToMarkdown(node)}\n\n');
        return;
      }
      if (name == 'br') {
        out.write('\n');
        return;
      }
      if (name == 'strong' || name == 'b' || name == 'i' || name == 'em') {
        // 不渲染加粗/斜体，内容按普通文本输出。
        for (final child in node.nodes) {
          walk(child);
        }
        return;
      }
      if (name == 'a') {
        final href = node.attributes['href'] ?? '';
        if (attachments.any((a) => a.url == '$baseUrl$href' || a.url == href)) {
          return; // 附件链接已单独列出，正文中跳过
        }
        final text = _nodePlainText(node);
        if (text.isNotEmpty) {
          out.write('[$text]($href)');
        }
        return;
      }
      if (_headingLevelReg.hasMatch(name)) {
        // 标题不渲染为 Markdown 标题，按普通段落文本输出。
        out.write('\n\n');
        for (final child in node.nodes) {
          walk(child);
        }
        out.write('\n\n');
        return;
      }
      if (name == 'li') {
        out.write('\n- ');
        for (final child in node.nodes) {
          walk(child);
        }
        out.write('\n');
        return;
      }
      if (name == 'p' || name == 'div') {
        out.write('\n\n');
        for (final child in node.nodes) {
          walk(child);
        }
        out.write('\n\n');
        return;
      }
      for (final child in node.nodes) {
        walk(child);
      }
    }

    for (final child in root.nodes) {
      walk(child);
    }

    return out
        .toString()
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// 将 <table> 转换为 Markdown 表格（首行为表头）。
  String _tableToMarkdown(html_dom.Element table) {
    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) return '';
    final lines = <String>[];
    for (final (i, tr) in rows.indexed) {
      final cells = <String>[];
      for (final cell in tr.querySelectorAll('td, th')) {
        cells.add(_nodePlainText(cell).replaceAll('|', '\\|'));
      }
      if (cells.isEmpty) continue;
      lines.add('| ${cells.join(' | ')} |');
      if (i == 0) {
        lines.add('| ${List.filled(cells.length, '---').join(' | ')} |');
      }
    }
    return lines.join('\n');
  }


  static final _emailReg = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  /// 将文本中的邮箱地址的 @ 转义为 \@，避免被 Markdown 渲染成超链接。
  String _escapeEmails(String text) => text.replaceAllMapped(
        _emailReg,
        (m) => m.group(0)!.replaceAll('@', r'\@'),
      );

  /// 提取元素的纯文本（清理空白，并转义邮箱避免渲染为链接）。
  String _nodePlainText(html_dom.Element element) => _escapeEmails(
    element.text
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim(),
  );

}

class NoticeException implements Exception {
  final String message;

  const NoticeException(this.message);

  @override
  String toString() => message;
}
