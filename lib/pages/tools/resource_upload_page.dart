import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/resource_center.dart';
import '../../services/control_service.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';

const double _maxUploadBytes = 80 * 1024 * 1024;
const int _maxFilesPerUpload = 10;
const XTypeGroup _pdfTypeGroup = XTypeGroup(
  label: 'PDF',
  extensions: ['pdf'],
  mimeTypes: ['application/pdf'],
);
const XTypeGroup _examTypeGroup = XTypeGroup(
  label: '试卷文档',
  extensions: ['pdf', 'docx', 'doc'],
  mimeTypes: [
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/msword',
  ],
);

String _fileFormat(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.docx')) return 'docx';
  if (lower.endsWith('.doc')) return 'doc';
  return 'pdf';
}

String _contentTypeForFormat(String format) => switch (format) {
  'docx' =>
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'doc' => 'application/msword',
  _ => 'application/pdf',
};

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

/// Streams the file so hashing an 80 MB scan does not load it into memory.
Future<String> _fileMd5(String path) async {
  final output = _DigestSink();
  final input = md5.startChunkedConversion(output);
  await for (final chunk in File(path).openRead()) {
    input.add(chunk);
  }
  input.close();
  final digest = output.value;
  if (digest == null) {
    throw StateError('md5 unavailable');
  }
  return digest.toString();
}

class ResourceUploadPage extends StatefulWidget {
  final List<ResourceCourse> courses;
  final String initialKind;
  final String? initialCourseCode;
  final bool courseScoped;

  const ResourceUploadPage({
    super.key,
    required this.courses,
    this.initialKind = 'resource',
    this.initialCourseCode,
    this.courseScoped = false,
  });

  @override
  State<ResourceUploadPage> createState() => _ResourceUploadPageState();
}

class _ResourceUploadPageState extends State<ResourceUploadPage> {
  String _kind = 'resource';
  late String _courseCode = _initialCourseCode();
  final List<_PickedPdf> _files = [];
  bool _uploading = false;
  int _sent = 0;
  int _total = 0;
  int _uploadIndex = 0;
  int _uploadCount = 0;
  UploadStats? _stats;
  bool _statsLoading = true;
  List<UploadTextbook> _textbooks = const [];
  UploadTextbook? _selectedTextbook;
  bool _textbooksLoading = true;

  String _initialCourseCode() {
    final requested = widget.initialCourseCode?.trim() ?? '';
    if (requested.isNotEmpty &&
        widget.courses.any((course) => course.code == requested)) {
      return requested;
    }
    if (widget.courses.isEmpty) return '';
    return widget.courses.first.code;
  }

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind == 'textbook' ? 'textbook' : 'resource';
    _statsLoading = !widget.courseScoped;
    _textbooksLoading = _kind == 'textbook';
    if (!widget.courseScoped) unawaited(_loadStats());
    if (_kind == 'textbook') unawaited(_loadTextbooks());
  }

  Future<void> _loadStats() async {
    if (widget.courseScoped) return;
    if (!_statsLoading) setState(() => _statsLoading = true);
    try {
      final stats = await ControlService.instance.fetchUploadStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (_) {
      // The form still works when the summary endpoint is temporarily down.
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadTextbooks({bool force = false}) async {
    if (_kind != 'textbook') return;
    if (!force && _textbooks.isNotEmpty) return;
    if (!_textbooksLoading) setState(() => _textbooksLoading = true);
    try {
      final items = widget.courseScoped
          ? [
              for (final item
                  in await ControlService.instance.fetchCourseTextbooks(
                    _courseCode,
                  ))
                UploadTextbook.fromCourseTextbook(item, _courseCode),
            ]
          : await ControlService.instance.fetchUploadTextbooks();
      if (!mounted) return;
      setState(() {
        _textbooks = items;
        final current = _selectedTextbook;
        if (current == null || !items.any((book) => book.id == current.id)) {
          _selectedTextbook = items.isEmpty ? null : items.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _textbooks = const [];
        _selectedTextbook = null;
      });
    } finally {
      if (mounted) setState(() => _textbooksLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      if (!widget.courseScoped) _loadStats(),
      if (_kind == 'textbook') _loadTextbooks(force: true),
    ]);
  }

  Future<void> _pickFiles() async {
    if (_uploading) return;
    final multiple = _kind == 'resource';
    final List<XFile> picked;
    try {
      picked = await openFiles(
        acceptedTypeGroups: [multiple ? _examTypeGroup : _pdfTypeGroup],
      );
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          '无法打开文件选择器，请稍后重试',
          severity: ToastSeverity.error,
        );
      }
      return;
    }
    if (!mounted || picked.isEmpty) return;

    final entries = <_PickedPdf>[];
    var oversized = 0;
    var unreadable = 0;
    for (final file in picked) {
      final size = await file.length();
      if (size <= 0) {
        unreadable++;
        continue;
      }
      if (size > _maxUploadBytes) {
        oversized++;
        continue;
      }
      entries.add(_PickedPdf(file, size));
    }
    if (!mounted) return;
    if (oversized > 0) {
      showAppSnackBar(
        context,
        '$oversized 个文件超过 80 MB，已忽略',
        severity: ToastSeverity.warning,
      );
    }
    if (unreadable > 0) {
      showAppSnackBar(
        context,
        '$unreadable 个文件无法读取，已忽略',
        severity: ToastSeverity.warning,
      );
    }
    if (entries.isEmpty) return;

    var overflow = 0;
    setState(() {
      if (!multiple) {
        _files
          ..clear()
          ..add(entries.first);
      } else {
        final known = {for (final item in _files) item.path};
        for (final entry in entries) {
          if (!known.add(entry.path)) continue;
          if (_files.length >= _maxFilesPerUpload) {
            overflow++;
            continue;
          }
          _files.add(entry);
        }
      }
    });
    if (overflow > 0) {
      showAppSnackBar(
        context,
        '一次最多上传 $_maxFilesPerUpload 个文件',
        severity: ToastSeverity.warning,
      );
    }
  }

  void _removeFile(_PickedPdf picked) {
    if (_uploading) return;
    setState(() => _files.remove(picked));
  }

  Future<void> _submit() async {
    if (_uploading) return;
    if (_files.isEmpty) {
      showAppSnackBar(
        context,
        _kind == 'resource' ? '请选择文件' : '请选择 PDF 文件',
        severity: ToastSeverity.warning,
      );
      return;
    }
    String courseCode;
    String name = '';
    String tags = '';
    String targetId = '';
    if (_kind == 'textbook') {
      final book = _selectedTextbook;
      if (book == null) {
        showAppSnackBar(context, '请选择教材', severity: ToastSeverity.warning);
        return;
      }
      courseCode = widget.courseScoped ? _courseCode : book.primaryCourseCode;
      if (courseCode.isEmpty) {
        showAppSnackBar(
          context,
          '该教材未关联课程，暂不能上传',
          severity: ToastSeverity.warning,
        );
        return;
      }
      name = book.name;
      tags = book.tags;
      targetId = book.id;
    } else {
      courseCode = _courseCode;
      if (courseCode.isEmpty) {
        showAppSnackBar(context, '请选择课程', severity: ToastSeverity.warning);
        return;
      }
    }
    final queue = List<_PickedPdf>.of(_files);
    setState(() {
      _uploading = true;
      _uploadIndex = 1;
      _uploadCount = queue.length;
      _sent = 0;
      _total = queue.first.size;
    });
    final failed = <_PickedPdf>[];
    String? firstError;
    for (var index = 0; index < queue.length; index++) {
      final picked = queue[index];
      if (mounted) {
        setState(() {
          _uploadIndex = index + 1;
          _sent = 0;
          _total = picked.size;
        });
      }
      final itemName = _kind == 'resource' ? _nameFromFile(picked.name) : name;
      final error = await _uploadOne(
        picked,
        courseCode: courseCode,
        name: itemName,
        tags: tags,
        targetId: targetId,
      );
      if (error == null) {
        if (mounted) setState(() => _files.remove(picked));
      } else {
        failed.add(picked);
        firstError ??= error;
      }
    }
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (failed.isNotEmpty) {
        _files
          ..clear()
          ..addAll(failed);
      }
    });
    if (failed.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    final message = failed.length == 1
        ? (firstError ?? '上传失败，请稍后重试')
        : '${failed.length} 个文件上传失败，请重试（${firstError ?? '网络异常'}）';
    showAppSnackBar(context, message, severity: ToastSeverity.error);
  }

  Future<String?> _uploadOne(
    _PickedPdf picked, {
    required String courseCode,
    required String name,
    required String tags,
    required String targetId,
  }) async {
    ResourceUploadTicket? ticket;
    var uploaded = false;
    final format = _kind == 'resource' ? _fileFormat(picked.name) : 'pdf';
    try {
      final fileMd5 = await _fileMd5(picked.path);
      ticket = await ControlService.instance.createResourceUploadTicket(
        kind: _kind,
        courseCode: courseCode,
        name: name,
        tags: tags,
        targetId: targetId,
        format: format,
        md5: fileMd5,
        sizeBytes: picked.size,
      );
      await ControlService.instance.uploadToSignedUrl(
        ticket.uploadUrl,
        filePath: picked.path,
        sizeBytes: picked.size,
        contentType: _contentTypeForFormat(format),
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            _sent = sent;
            if (total > 0) _total = total;
          });
        },
      );
      uploaded = true;
      await ControlService.instance.completeResourceUpload(ticket.id);
      return null;
    } on ControlApiException catch (error) {
      if (ticket != null && !uploaded) {
        unawaited(ControlService.instance.abortResourceUpload(ticket.id));
      }
      return error.message;
    } catch (_) {
      if (ticket != null && !uploaded) {
        unawaited(ControlService.instance.abortResourceUpload(ticket.id));
      }
      return '上传失败，请稍后重试';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scoped = widget.courseScoped;
    final title = scoped ? (_kind == 'textbook' ? '上传教材' : '上传试卷') : '上传资源';
    final canSubmit =
        !_uploading &&
        _files.isNotEmpty &&
        (_kind != 'textbook' || _selectedTextbook != null) &&
        (scoped || _kind == 'textbook' || _courseCode.isNotEmpty);
    return AppPage(
      title: title,
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        onRefresh: _refreshAll,
        children: [
          if (!scoped) ...[
            AppAdaptiveGrid(
              children: [
                _buildMetricCell(
                  theme,
                  '贡献数',
                  _stats == null ? '--' : '${_stats!.contributionCount}',
                ),
                _buildMetricCell(
                  theme,
                  '下载量',
                  _stats == null ? '--' : '${_stats!.downloadCount}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                _buildTab(theme, 'resource', '试卷'),
                _buildTab(theme, 'textbook', '教材'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (!scoped && _kind == 'resource') ...[
            _buildCourseSelector(theme),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_kind == 'textbook') ...[
            _buildTextbookField(theme),
            const SizedBox(height: AppSpacing.md),
          ],
          _buildFilePicker(theme),
          if (_uploading) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _total > 0 ? (_sent / _total).clamp(0.0, 1.0) : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _progressLabel,
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FButton(
            variant: FButtonVariant.primary,
            onPress: canSubmit ? () => unawaited(_submit()) : null,
            prefix: const Icon(FLucideIcons.arrowUpToLine),
            child: Text(
              _uploading
                  ? '上传中...'
                  : _files.length > 1
                  ? '提交审核（${_files.length} 个文件）'
                  : '提交审核',
            ),
          ),
        ],
      ),
    );
  }

  String get _progressLabel {
    final percent = _total > 0
        ? '${(_sent * 100 / _total).clamp(0, 100).round()}%'
        : null;
    if (_uploadCount > 1) {
      return percent == null
          ? '正在上传 $_uploadIndex/$_uploadCount'
          : '正在上传 $_uploadIndex/$_uploadCount · $percent';
    }
    return percent == null ? '上传中…' : '上传中 · $percent';
  }

  Widget _buildTextbookField(FThemeData theme) {
    if (_textbooksLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
        ),
      );
    }
    if (_textbooks.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Text(
          widget.courseScoped ? '该课程暂无关联教材' : '暂无可上传的教材',
          style: theme.typography.bodySmall.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      );
    }
    final book = _selectedTextbook;
    if (widget.courseScoped && _textbooks.length == 1 && book != null) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '关联教材',
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              book.name,
              style: theme.typography.body.md.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return _SearchChoiceField<UploadTextbook>(
      label: '选择教材',
      placeholder: '请选择教材',
      searchHint: '搜索教材名称、标签或课程',
      value: book,
      options: _textbooks,
      format: _textbookLabel,
      matches: _textbookMatches,
      enabled: !_uploading,
      onChanged: (value) => setState(() => _selectedTextbook = value),
    );
  }

  Widget _buildCourseSelector(FThemeData theme) {
    return _SearchChoiceField<String>(
      label: '课程',
      placeholder: '请选择课程',
      searchHint: '搜索课程名或编号',
      value: _courseCode.isEmpty ? null : _courseCode,
      options: [for (final course in widget.courses) course.code],
      format: _courseLabel,
      matches: (code, query) =>
          code.toLowerCase().contains(query) ||
          _courseName(code).toLowerCase().contains(query),
      enabled: !_uploading,
      onChanged: (value) => setState(() => _courseCode = value),
    );
  }

  Widget _buildFilePicker(FThemeData theme) {
    final multiple = _kind == 'resource';
    final hasFiles = _files.isNotEmpty;
    final label = hasFiles
        ? (multiple ? '继续添加文件' : '更换 PDF 文件')
        : (multiple ? '选择文件' : '选择 PDF 文件');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasFiles) ...[
          for (final picked in _files) ...[
            _buildFileRow(theme, picked),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.xs),
        ],
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _uploading ? null : () => unawaited(_pickFiles()),
          child: CustomPaint(
            painter: _DashedBorderPainter(color: theme.colors.border),
            child: SizedBox(
              width: double.infinity,
              height: 132,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasFiles ? FLucideIcons.plus : FLucideIcons.arrowUpToLine,
                      size: 20,
                      color: theme.colors.mutedForeground,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _uploading ? '上传中…' : label,
                      style: theme.typography.bodySmall.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      multiple
                          ? '支持 PDF / DOCX / DOC，可多选，单个不超过 80 MB'
                          : '仅支持单个 PDF，不超过 80 MB',
                      style: theme.typography.bodySmall.copyWith(
                        fontSize: 11,
                        color: theme.colors.mutedForeground.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileRow(FThemeData theme, _PickedPdf picked) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            FLucideIcons.fileText,
            size: 18,
            color: theme.colors.mutedForeground,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  picked.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.bodySmall.copyWith(
                    color: theme.colors.foreground,
                  ),
                ),
                Text(
                  _formatSize(picked.size),
                  style: theme.typography.bodySmall.copyWith(
                    fontSize: 11,
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (!_uploading)
            IconButton(
              onPressed: () => _removeFile(picked),
              icon: const Icon(FLucideIcons.x, size: 18),
              color: theme.colors.mutedForeground,
              tooltip: '移除文件',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  bool _textbookMatches(UploadTextbook book, String query) {
    return book.name.toLowerCase().contains(query) ||
        book.tags.toLowerCase().contains(query) ||
        book.courseCodes.any((code) => code.toLowerCase().contains(query)) ||
        _courseName(book.primaryCourseCode).toLowerCase().contains(query);
  }

  Widget _buildTab(FThemeData theme, String kind, String label) {
    final selected = _kind == kind;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _uploading
            ? null
            : () {
                if (_kind == kind) return;
                setState(() {
                  _kind = kind;
                  _files.clear();
                });
                if (kind == 'textbook') unawaited(_loadTextbooks());
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? theme.colors.primary : theme.colors.border,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: theme.typography.body.md.copyWith(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? theme.colors.primary
                    : theme.colors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCell(FThemeData theme, String label, String value) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.typography.bodySmall.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.typography.body.sm.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _textbookLabel(UploadTextbook book) {
    final name = book.name.trim().isEmpty ? book.id : book.name.trim();
    if (widget.courseScoped) return name;
    final courseName = _courseName(book.primaryCourseCode);
    if (courseName.isNotEmpty) return '$name · $courseName';
    final code = book.primaryCourseCode;
    return code.isEmpty ? name : '$name · $code';
  }

  String _courseName(String code) {
    for (final course in widget.courses) {
      if (course.code != code) continue;
      return course.name.trim();
    }
    return '';
  }

  String _courseLabel(String code) {
    final name = _courseName(code);
    if (name.isEmpty) return code;
    return '$code · $name';
  }

  String _nameFromFile(String fileName) {
    final trimmed = fileName.trim();
    final lower = trimmed.toLowerCase();
    for (final extension in const ['.pdf', '.docx', '.doc']) {
      if (lower.endsWith(extension)) {
        return trimmed.substring(0, trimmed.length - extension.length).trim();
      }
    }
    return trimmed;
  }

  String _formatSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

class _PickedPdf {
  final XFile file;
  final int size;

  const _PickedPdf(this.file, this.size);

  String get path => file.path;
  String get name => file.name;
}

/// A single search field that doubles as the selected-value display: focusing
/// it turns the label into a query, and picking an option restores the label.
class _SearchChoiceField<T> extends StatefulWidget {
  final String label;
  final String placeholder;
  final String searchHint;
  final T? value;
  final List<T> options;
  final String Function(T value) format;
  final bool Function(T value, String query) matches;
  final ValueChanged<T> onChanged;
  final bool enabled;

  const _SearchChoiceField({
    required this.label,
    required this.placeholder,
    required this.searchHint,
    required this.value,
    required this.options,
    required this.format,
    required this.matches,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<_SearchChoiceField<T>> createState() => _SearchChoiceFieldState<T>();
}

class _SearchChoiceFieldState<T> extends State<_SearchChoiceField<T>> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _open = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.text = _displayText(widget.value);
    _searchFocus.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _SearchChoiceField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_searchFocus.hasFocus && oldWidget.value != widget.value) {
      _syncDisplay();
    }
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_handleFocusChange);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Focusing the field turns the selected-value label into a search query;
  /// leaving it restores the label, so one field serves as both.
  void _handleFocusChange() {
    if (!mounted) return;
    if (_searchFocus.hasFocus) {
      setState(() {
        _open = true;
        _query = '';
      });
      _searchController.clear();
      _reveal();
      return;
    }
    setState(() {
      _open = false;
      _query = '';
    });
    _syncDisplay();
  }

  String _displayText(T? value) => value == null ? '' : widget.format(value);

  void _syncDisplay() {
    final text = _displayText(widget.value);
    if (_searchController.text != text) _searchController.text = text;
  }

  /// Scrolls the selector up once the keyboard has finished opening so the
  /// result list is not hidden behind it.
  void _reveal() {
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted || !_open) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.03,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _select(T value) {
    widget.onChanged(value);
    _searchFocus.unfocus();
    _searchController.text = widget.format(value);
    if (_open) {
      setState(() {
        _query = '';
        _open = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.options
        : [
            for (final option in widget.options)
              if (widget.matches(option, query)) option,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.typography.bodySmall.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppTextField(
          controller: _searchController,
          focusNode: _searchFocus,
          hint: _open ? widget.searchHint : widget.placeholder,
          prefix: const Icon(FLucideIcons.search, size: 18),
          clearable: _open,
          enabled: widget.enabled,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
        ),
        if (_open) ...[
          const SizedBox(height: AppSpacing.sm),
          TextFieldTapRegion(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 232),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colors.card,
                  border: Border.all(color: theme.colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: matches.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          '未找到匹配项',
                          style: theme.typography.bodySmall.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final option in matches)
                              _buildOption(
                                theme,
                                option,
                                option == widget.value,
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOption(FThemeData theme, T option, bool selected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(option),
      child: Container(
        width: double.infinity,
        color: selected ? theme.colors.secondary : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.format(option),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.md.copyWith(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? theme.colors.primary
                      : theme.colors.foreground,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(FLucideIcons.check, size: 18, color: theme.colors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + dash, metric.length),
          ),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
