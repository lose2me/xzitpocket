import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../constants/network_config.dart';
import 'dio_factory.dart';
import 'notice_service.dart';
import 'talker.dart';

/// 后勤处公告详情：正文为「内嵌 PDF」，另有若干附件文件链接。
class HqglDetailResult {
  final String title;
  final String date;
  final String content;
  final List<NoticeAttachment> bodyPdfs;
  final List<NoticeAttachment> attachments;

  const HqglDetailResult({
    required this.title,
    required this.date,
    this.content = '',
    this.bodyPdfs = const [],
    this.attachments = const [],
  });
}

/// 后勤管理处「通知公告」抓取服务。
///
/// 站点同为苏迪 WebPlus 建站系统（与教务处类似但用 `simpleNews` 插件）：
/// - 列表页：https://hqglc.xzit.edu.cn/3585/list.htm（第 N 页为 listN.htm，每页 14 条）
///   列表项：<li class="liebiao"><a href="/.."> 标题 </a> <span>2026-07-28</span>
/// - 详情页：https://hqglc.xzit.edu.cn/{path}/page.htm，正文在 `.wp_articlecontent`，
///   PDF 以 <span class="wp_pdf_player" pdfsrc="..."> 内嵌，附件是 /_upload 链接。
class HqglService {
  static const baseUrl = 'https://hqglc.xzit.edu.cn';
  static const listColumnPath = '/3585';

  static final _attachmentExtensionReg = RegExp(
    r'\.(docx?|xlsx?|pptx?|pdf|zip|rar|7z|txt|wps|et)$',
    caseSensitive: false,
  );
  static final _sudyTitleReg = RegExp(
    r'''(?:["']?title["']?)\s*:\s*(?:"([^"]*)"|'([^']*)')''',
    caseSensitive: false,
  );
  static final _attachmentLabelReg = RegExp(r'^附件\s*[一二三四五六七八九十\d]*\s*[：:]?$');

  Dio? _dio;

  Dio _client() => _dio ??= DioFactory.createNaked(
    cookieJar: CookieJar(),
    connectTimeout: requestTimeout,
    receiveTimeout: requestTimeout,
    userAgent: kUserAgent,
  );

  static String _resolveUrl(String href, Uri base) =>
      base.resolve(href.trim()).toString();

  /// 抓取指定页码的后勤处公告列表（页码从 1 开始）。
  Future<NoticePage> fetchList({int page = 1}) async {
    final path = page <= 1 ? 'list' : 'list$page';
    final url = '$baseUrl$listColumnPath/$path.htm';
    talker.debug('[NET] 后勤公告列表\n$url');

    final resp = await _client().get<String>(url);
    final html = resp.data ?? '';
    if (html.isEmpty) {
      throw const NoticeException('后勤公告页面为空');
    }

    return parseListHtml(html, pageUrl: url, page: page);
  }

  /// Parses a server-rendered list page without performing network I/O.
  static NoticePage parseListHtml(
    String html, {
    required String pageUrl,
    required int page,
  }) {
    final pageUri = Uri.parse(pageUrl);
    final doc = html_parser.parse(html);
    final items = <NoticeItem>[];
    for (final li in doc.querySelectorAll('li.liebiao')) {
      final a = li.querySelector('a[href]');
      final href = a?.attributes['href']?.trim() ?? '';
      final title = a?.text.trim() ?? '';
      final date =
          RegExp(r'\d{4}-\d{1,2}-\d{1,2}')
              .firstMatch(li.querySelector('span')?.text ?? li.text)
              ?.group(0) ??
          '';
      if (href.isEmpty || title.isEmpty) continue;
      items.add(
        NoticeItem(title: title, url: _resolveUrl(href, pageUri), date: date),
      );
    }

    final perPage = _parseCount(doc.querySelector('.per_count'), 14);
    final total = _parseCount(doc.querySelector('.all_count'), items.length);

    return NoticePage(items: items, page: page, perPage: perPage, total: total);
  }

  static int _parseCount(html_dom.Element? element, int fallback) {
    final value = RegExp(r'\d+').firstMatch(element?.text ?? '')?.group(0);
    return int.tryParse(value ?? '') ?? fallback;
  }

  /// 抓取后勤处公告详情：正文 = 内嵌 PDF（bodyPdfs），其余 /upload 链接为附件。
  Future<HqglDetailResult> fetchDetail(String url) async {
    talker.debug('[NET] 后勤公告详情\n$url');
    final resp = await _client().get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final html = resp.data ?? '';
    if (html.isEmpty) {
      throw const NoticeException('后勤公告页面为空');
    }

    return parseDetailHtml(html, pageUrl: url);
  }

  /// 解析 WebPlus 详情页。独立于网络请求，便于覆盖不同编辑器生成的 PDF 结构。
  static HqglDetailResult parseDetailHtml(
    String html, {
    required String pageUrl,
  }) {
    final pageUri = Uri.parse(pageUrl);

    final doc = html_parser.parse(html);
    final title =
        doc.querySelector('title')?.text.trim() ??
        RegExp(
          r'<title>\s*(.*?)\s*</title>',
          dotAll: true,
        ).firstMatch(html)?.group(1)?.trim() ??
        '';
    final date =
        RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(html)?.group(1) ?? '';

    final bodyPdfs = <NoticeAttachment>[];
    final attachments = <NoticeAttachment>[];
    final seen = <String>{};

    // 新版 WebPlus 使用 [pdfsrc]，旧模板也可能输出 object/embed/iframe。
    for (final element in doc.querySelectorAll(
      '[pdfsrc], [data-pdfsrc], object[data], embed[src], iframe[src]',
    )) {
      final src = _embeddedPdfSource(element);
      if (src == null) continue;
      final resolved = _resolveUrl(src, pageUri);
      if (!seen.add(resolved)) continue;
      bodyPdfs.add(
        NoticeAttachment(name: _fileName(element, resolved), url: resolved),
      );
    }

    // 普通文件链接作为附件；与内嵌正文 PDF URL 相同时不重复展示。
    for (final a in doc.querySelectorAll('a[href]')) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty || !_isAttachmentHref(href)) continue;
      final resolved = _resolveUrl(href, pageUri);
      if (!seen.add(resolved)) continue;
      attachments.add(
        NoticeAttachment(
          name: _stripAttachmentPrefix(_fileName(a, resolved)),
          url: resolved,
        ),
      );
    }

    final root =
        doc.querySelector('.wp_articlecontent') ??
        doc.querySelector('.con_content') ??
        doc.querySelector('.content_Main');

    return HqglDetailResult(
      title: title,
      date: date,
      content: root == null ? '' : _extractBodyText(root),
      bodyPdfs: bodyPdfs,
      attachments: attachments,
    );
  }

  /// 下载附件到本地指定路径。
  Future<void> downloadAttachment(String url, String savePath) async {
    talker.debug('[NET] 后勤附件下载\n$url');
    await _client().download(
      url,
      savePath,
      deleteOnError: true,
      options: Options(headers: const {'Referer': '$baseUrl/'}),
    );
  }

  static String? _embeddedPdfSource(html_dom.Element element) {
    for (final attribute in const ['pdfsrc', 'data-pdfsrc']) {
      final value = element.attributes[attribute]?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final sourceAttribute = element.localName == 'object' ? 'data' : 'src';
    final value = element.attributes[sourceAttribute]?.trim() ?? '';
    return value.isNotEmpty && _isPdfHref(value) ? value : null;
  }

  static bool _isAttachmentHref(String href) {
    final normalized = href.toLowerCase();
    if (normalized.contains('/_upload/') || normalized.contains('/upload/')) {
      return true;
    }
    return _isPdfHref(href) || _attachmentExtensionReg.hasMatch(_uriPath(href));
  }

  static bool _isPdfHref(String href) =>
      RegExp(r'\.pdf$', caseSensitive: false).hasMatch(_uriPath(href));

  static String _uriPath(String value) {
    try {
      return Uri.parse(value).path;
    } on FormatException {
      return value.split(RegExp(r'[?#]')).first;
    }
  }

  static String _fileName(html_dom.Element element, String resolvedUrl) {
    final sudyAttributes = element.attributes['sudyfile-attr'];
    if (sudyAttributes != null) {
      final match = _sudyTitleReg.firstMatch(sudyAttributes);
      final title = (match?.group(1) ?? match?.group(2) ?? '').trim();
      if (title.isNotEmpty) return title;
    }

    for (final candidate in [
      element.attributes['title'],
      element.attributes['download'],
      element.text,
      element.id,
    ]) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final path = Uri.parse(resolvedUrl).pathSegments;
    final encoded = path.isEmpty ? 'document.pdf' : path.last;
    try {
      return Uri.decodeComponent(encoded);
    } on FormatException {
      return encoded;
    }
  }

  static String _extractBodyText(html_dom.Element root) {
    final out = StringBuffer();
    const blockElements = {
      'address',
      'article',
      'div',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'li',
      'p',
      'section',
      'tr',
    };

    void walk(html_dom.Node node) {
      if (node is html_dom.Text) {
        out.write(node.data);
        return;
      }
      if (node is! html_dom.Element) return;

      final name = node.localName ?? '';
      if (name == 'script' ||
          name == 'style' ||
          _embeddedPdfSource(node) != null) {
        return;
      }
      if (name == 'a' && _isAttachmentHref(node.attributes['href'] ?? '')) {
        return;
      }
      if (name == 'br') {
        out.write('\n');
        return;
      }

      final block = blockElements.contains(name);
      if (block) out.write('\n');
      for (final child in node.nodes) {
        walk(child);
      }
      if (block) out.write('\n');
    }

    walk(root);
    final normalized = out
        .toString()
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return normalized
        .split('\n')
        .where((line) => !_attachmentLabelReg.hasMatch(line.trim()))
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// 附件名格式化：删除“文件后缀说明:/冒号”前缀（复用教务处同款逻辑）。
  static String _stripAttachmentPrefix(String name) {
    for (var i = 0; i < name.length; i++) {
      final ch = name[i];
      if (ch == '.' || ch == ':' || ch == '：') {
        if (ch == '.' && _isExtensionDot(name, i)) continue;
        final rest = name.substring(i + 1).trim();
        return rest.isEmpty ? name : rest;
      }
    }
    return name;
  }

  static bool _isExtensionDot(String name, int i) {
    final after = name.substring(i + 1);
    return !after.contains('.') && after.isNotEmpty;
  }
}
