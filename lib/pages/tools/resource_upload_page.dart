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

  const ResourceUploadPage({
    super.key,
    required this.courses,
    this.initialKind = 'textbook',
    this.initialCourseCode,
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
  List<CourseTextbookItem> _textbooks = const [];
  String _selectedTextbookId = '';
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
    unawaited(_loadStats());
    unawaited(_loadTextbooks());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
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

  Future<void> _loadTextbooks() async {
    if (_kind != 'textbook') return;
    if (!_textbooksLoading) setState(() => _textbooksLoading = true);
    try {
      final items = await ControlService.instance.fetchCourseTextbooks(
        _courseCode,
      );
      if (!mounted) return;
      setState(() {
        _textbooks = items;
        if (!items.any((item) => item.id == _selectedTextbookId)) {
          _selectedTextbookId = items.isEmpty ? '' : items.first.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _textbooks = const [];
        _selectedTextbookId = '';
      });
    } finally {
      if (mounted) setState(() => _textbooksLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadStats(), _loadTextbooks()]);
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
    if (_courseCode.isEmpty) {
      showAppSnackBar(context, '请选择课程', severity: ToastSeverity.warning);
      return;
    }
    CourseTextbookItem? target;
    String name;
    String tags = '';
    if (_kind == 'textbook') {
      target = _selectedTextbook;
      if (target == null) {
        showAppSnackBar(context, '请选择教材', severity: ToastSeverity.warning);
        return;
      }
      name = target.name;
      tags = target.tags;
    } else {
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
        courseCode: _courseCode,
        name: name,
        tags: tags,
        targetId: target?.id ?? '',
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

  CourseTextbookItem? get _selectedTextbook {
    for (final item in _textbooks) {
      if (item.id == _selectedTextbookId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final canSubmit =
        !_uploading && (_kind == 'resource' || _selectedTextbookId.isNotEmpty);
    return AppPage(
      title: '上传资源',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _statsLoading || _textbooksLoading
              ? null
              : () => unawaited(_refreshAll()),
          tooltip: '刷新数据',
          loading: _statsLoading || _textbooksLoading,
        ),
      ],
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
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
          Text(
            '课程',
            style: theme.typography.bodySmall.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FSelect<String>.rich(
            control: FSelectControl.lifted(
              value: _courseCode,
              onChange: (value) {
                if (value == null || _uploading || value == _courseCode) return;
                setState(() {
                  _courseCode = value;
                  _selectedTextbookId = '';
                  _textbooks = const [];
                });
                unawaited(_loadTextbooks());
              },
            ),
            format: _courseLabel,
            children: [
              for (final course in widget.courses)
                FSelectItem.item(
                  title: Text(_courseLabel(course.code)),
                  value: course.code,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_kind == 'textbook') ...[
            Text(
              '选择教材',
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_textbooksLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: FCircularProgress(
                    size: FCircularProgressSizeVariant.sm,
                  ),
                ),
              )
            else if (_textbooks.isEmpty)
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  '该课程暂无可上传的教材',
                  style: theme.typography.bodySmall.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              )
            else
              FSelect<String>.rich(
                control: FSelectControl.lifted(
                  value: _selectedTextbookId,
                  onChange: (value) {
                    if (value != null && !_uploading) {
                      setState(() => _selectedTextbookId = value);
                    }
                  },
                ),
                format: _textbookLabel,
                children: [
                  for (final item in _textbooks)
                    FSelectItem.item(
                      title: Text(_textbookLabel(item.id)),
                      value: item.id,
                    ),
                ],
              ),
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

  String _textbookLabel(String id) {
    for (final item in _textbooks) {
      if (item.id != id) continue;
      return item.hasPdf ? '${item.name}（已有 PDF）' : item.name;
    }
    return id;
  }

  String _courseLabel(String code) {
    for (final course in widget.courses) {
      if (course.code != code) continue;
      final name = course.name.trim();
      return name.isEmpty ? code : '$code · $name';
    }
    return code;
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
