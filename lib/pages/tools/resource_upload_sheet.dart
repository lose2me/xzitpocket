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

/// Opens the upload sheet. Returns true when a PDF was submitted for review.
Future<bool?> showResourceUploadSheet({
  required BuildContext context,
  required List<ResourceCourse> courses,
}) => showAppSheet<bool>(
  context: context,
  maxHeightRatio: 0.92,
  builder: (_) => _ResourceUploadSheet(courses: courses),
);

class _ResourceUploadSheet extends StatefulWidget {
  final List<ResourceCourse> courses;

  const _ResourceUploadSheet({required this.courses});

  @override
  State<_ResourceUploadSheet> createState() => _ResourceUploadSheetState();
}

class _ResourceUploadSheetState extends State<_ResourceUploadSheet> {
  final _nameController = TextEditingController();
  final _tagsController = TextEditingController();
  String _kind = 'textbook';
  late String _courseCode = widget.courses.first.code;
  XFile? _file;
  int _fileSize = 0;
  bool _uploading = false;
  int _sent = 0;
  int _total = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _tagsController.dispose();
    super.dispose();
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
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = _nameFromFile(file.name);
      }
    });
  }

  Future<void> _submit() async {
    if (_uploading) return;
    final file = _file;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, '请输入资料名称', severity: ToastSeverity.warning);
      return;
    }
    if (file == null) {
      showAppSnackBar(context, '请选择 PDF 文件', severity: ToastSeverity.warning);
      return;
    }
    if (_courseCode.isEmpty) {
      showAppSnackBar(context, '请选择课程', severity: ToastSeverity.warning);
      return;
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
        tags: _tagsController.text,
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(FLucideIcons.arrowUpToLine, color: theme.colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '上传教材或试卷',
                    style: theme.typography.pageTitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AppIconButton(
                  icon: FLucideIcons.chevronDown,
                  onPress: _uploading
                      ? null
                      : () => Navigator.of(context).pop(),
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '提交后由管理员审核，通过后会出现在对应课程的资源中心。',
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FButton(
                    variant: _kind == 'textbook'
                        ? FButtonVariant.primary
                        : FButtonVariant.outline,
                    onPress: _uploading
                        ? null
                        : () => setState(() => _kind = 'textbook'),
                    child: const Text('教材'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FButton(
                    variant: _kind == 'resource'
                        ? FButtonVariant.primary
                        : FButtonVariant.outline,
                    onPress: _uploading
                        ? null
                        : () => setState(() => _kind = 'resource'),
                    child: const Text('试卷'),
                  ),
                ),
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
                  if (value != null && !_uploading) {
                    setState(() => _courseCode = value);
                  }
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
            AppTextField(
              controller: _nameController,
              label: _kind == 'textbook' ? '教材名称' : '试卷名称',
              hint: '默认使用 PDF 文件名',
              enabled: !_uploading,
              maxLength: 256,
              clearable: true,
            ),
            if (_kind == 'textbook') ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _tagsController,
                label: '标签（作者、出版社等，可选）',
                enabled: !_uploading,
                maxLength: 1024,
                clearable: true,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
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
              onPress: _uploading ? null : () => unawaited(_submit()),
              prefix: const Icon(FLucideIcons.arrowUpToLine),
              child: Text(_uploading ? '上传中...' : '提交审核'),
            ),
          ],
        ),
      ),
    );
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
