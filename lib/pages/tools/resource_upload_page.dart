import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/resource_center.dart';
import '../../services/control_service.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';

const double _maxUploadBytes = 80 * 1024 * 1024;
const XTypeGroup _pdfTypeGroup = XTypeGroup(
  label: 'PDF',
  extensions: ['pdf'],
  mimeTypes: ['application/pdf'],
);

class ResourceUploadPage extends StatefulWidget {
  final List<ResourceCourse> courses;
  final String initialKind;
  final String? initialCourseCode;
  final bool courseScoped;

  const ResourceUploadPage({
    super.key,
    required this.courses,
    this.initialKind = 'textbook',
    this.initialCourseCode,
    this.courseScoped = false,
  });

  @override
  State<ResourceUploadPage> createState() => _ResourceUploadPageState();
}

class _ResourceUploadPageState extends State<ResourceUploadPage> {
  final _nameController = TextEditingController();
  String _kind = 'textbook';
  late String _courseCode = _initialCourseCode();
  XFile? _file;
  int _fileSize = 0;
  bool _uploading = false;
  int _sent = 0;
  int _total = 0;
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
    return widget.courses.first.code;
  }

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind == 'resource' ? 'resource' : 'textbook';
    _statsLoading = !widget.courseScoped;
    _textbooksLoading = _kind == 'textbook';
    if (!widget.courseScoped) unawaited(_loadStats());
    if (_kind == 'textbook') unawaited(_loadTextbooks());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  Future<void> _pickFile() async {
    final file = await openFile(acceptedTypeGroups: const [_pdfTypeGroup]);
    if (file == null || !mounted) return;
    final size = await file.length();
    if (!mounted) return;
    if (size <= 0) {
      showAppSnackBar(context, '无法读取该文件', severity: ToastSeverity.warning);
      return;
    }
    if (size > _maxUploadBytes) {
      showAppSnackBar(
        context,
        'PDF 不能超过 80 MB',
        severity: ToastSeverity.warning,
      );
      return;
    }
    setState(() {
      _file = file;
      _fileSize = size;
      if (_kind == 'resource' && _nameController.text.trim().isEmpty) {
        _nameController.text = _nameFromFile(file.name);
      }
    });
  }

  Future<void> _submit() async {
    if (_uploading) return;
    final file = _file;
    if (file == null) {
      showAppSnackBar(context, '请选择 PDF 文件', severity: ToastSeverity.warning);
      return;
    }
    String courseCode;
    String name;
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
      name = _nameController.text.trim();
      if (name.isEmpty) {
        showAppSnackBar(context, '请输入试卷名称', severity: ToastSeverity.warning);
        return;
      }
    }
    setState(() {
      _uploading = true;
      _sent = 0;
      _total = _fileSize;
    });
    ResourceUploadTicket? ticket;
    var uploaded = false;
    try {
      ticket = await ControlService.instance.createResourceUploadTicket(
        kind: _kind,
        courseCode: courseCode,
        name: name,
        tags: tags,
        targetId: targetId,
        sizeBytes: _fileSize,
      );
      await ControlService.instance.uploadToSignedUrl(
        ticket.uploadUrl,
        filePath: file.path,
        sizeBytes: _fileSize,
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
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ControlApiException catch (error) {
      if (ticket != null && !uploaded) {
        unawaited(ControlService.instance.abortResourceUpload(ticket.id));
      }
      if (mounted) {
        showAppSnackBar(context, error.message, severity: ToastSeverity.error);
      }
    } catch (_) {
      if (ticket != null && !uploaded) {
        unawaited(ControlService.instance.abortResourceUpload(ticket.id));
      }
      if (mounted) {
        showAppSnackBar(context, '上传失败，请稍后重试', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scoped = widget.courseScoped;
    final title = scoped ? (_kind == 'textbook' ? '上传教材' : '上传试卷') : '上传资源';
    final showRefresh = !scoped || _kind == 'textbook';
    final refreshLoading = !scoped
        ? (_statsLoading || _textbooksLoading)
        : _textbooksLoading;
    final canSubmit =
        !_uploading &&
        (_kind != 'textbook' || _selectedTextbook != null) &&
        (scoped || _kind == 'textbook' || _courseCode.isNotEmpty);
    return AppPage(
      title: title,
      actions: showRefresh
          ? [
              AppIconButton(
                icon: FLucideIcons.refreshCw,
                onPress: refreshLoading ? null : () => unawaited(_refreshAll()),
                tooltip: scoped ? '刷新教材' : '刷新数据',
                loading: refreshLoading,
              ),
            ]
          : const [],
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
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
                _buildTab(theme, 'textbook', '教材'),
                _buildTab(theme, 'resource', '试卷'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (!scoped && _kind == 'resource') ...[
            Text(
              '课程',
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildCourseSelector(theme),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_kind == 'textbook') ...[
            _buildTextbookField(theme),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            AppTextField(
              controller: _nameController,
              label: '试卷名称',
              hint: '默认使用 PDF 文件名',
              enabled: !_uploading,
              maxLength: 256,
              clearable: true,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  FLucideIcons.fileText,
                  color: theme.colors.mutedForeground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _file == null
                        ? '未选择 PDF 文件'
                        : '${_file!.name} · ${_formatSize(_fileSize)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.bodySmall.copyWith(
                      color: _file == null
                          ? theme.colors.mutedForeground
                          : theme.colors.foreground,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FButton(
                  variant: FButtonVariant.outline,
                  size: FButtonSizeVariant.sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: _uploading ? null : () => unawaited(_pickFile()),
                  child: Text(_file == null ? '选择' : '更换'),
                ),
              ],
            ),
          ),
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
              _total > 0
                  ? '上传中 ${(_sent * 100 / _total).clamp(0, 100).round()}%'
                  : '上传中…',
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
            child: Text(_uploading ? '上传中...' : '提交审核'),
          ),
        ],
      ),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择教材',
          style: theme.typography.bodySmall.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        FSelect<UploadTextbook>.searchBuilder(
          control: FSelectControl.lifted(
            value: _selectedTextbook,
            onChange: (value) {
              if (value != null && !_uploading) {
                setState(() => _selectedTextbook = value);
              }
            },
          ),
          format: _textbookLabel,
          filter: _filterTextbooks,
          contentBuilder: (context, query, values) => [
            for (final item in values)
              FSelectItem.item(title: Text(_textbookLabel(item)), value: item),
          ],
          hint: '输入教材名搜索',
        ),
      ],
    );
  }

  Widget _buildCourseSelector(FThemeData theme) {
    return FSelect<String>.searchBuilder(
      control: FSelectControl.lifted(
        value: _courseCode,
        onChange: (value) {
          if (value == null || _uploading || value == _courseCode) return;
          setState(() => _courseCode = value);
        },
      ),
      format: _courseLabel,
      filter: (query) {
        final q = query.trim().toLowerCase();
        if (q.isEmpty) {
          return [for (final course in widget.courses) course.code];
        }
        return [
          for (final course in widget.courses)
            if (course.code.toLowerCase().contains(q) ||
                course.name.toLowerCase().contains(q))
              course.code,
        ];
      },
      contentBuilder: (context, query, values) => [
        for (final code in values)
          FSelectItem.item(title: Text(_courseLabel(code)), value: code),
      ],
      hint: '输入课程名或编号搜索',
    );
  }

  Iterable<UploadTextbook> _filterTextbooks(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _textbooks;
    return _textbooks.where(
      (book) =>
          book.name.toLowerCase().contains(q) ||
          book.tags.toLowerCase().contains(q) ||
          book.courseCodes.any((code) => code.toLowerCase().contains(q)) ||
          _courseName(book.primaryCourseCode).toLowerCase().contains(q),
    );
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
                  if (kind == 'textbook') unawaited(_loadTextbooks());
                });
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
    if (trimmed.length > 4 &&
        trimmed.substring(trimmed.length - 4).toLowerCase() == '.pdf') {
      return trimmed.substring(0, trimmed.length - 4).trim();
    }
    return trimmed;
  }

  String _formatSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
