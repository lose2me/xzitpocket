import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../models/book_list.dart';
import '../../services/auth_service.dart';
import '../../services/cas_service.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';

class BookListPage extends StatefulWidget {
  final String studentId;
  final String password;

  const BookListPage({
    super.key,
    required this.studentId,
    required this.password,
  });

  @override
  State<BookListPage> createState() => _BookListPageState();
}

class _BookListPageState extends State<BookListPage> {
  BookListResult? _result;
  bool _loading = false;
  bool _refreshSucceeded = false;
  List<BookListSemesterOption> _semesterOptions = const [];
  BookListSemesterOption? _selectedSemester;

  @override
  void initState() {
    super.initState();
    unawaited(_load(showError: false));
  }

  String _optionLabel(String key) {
    for (final option in _semesterOptions) {
      if (option.key == key) return option.label;
    }
    return _semesterOptions.first.label;
  }

  Future<void> _selectSemester(String? key) async {
    if (key == null || _loading) return;
    for (final option in _semesterOptions) {
      if (option.key != key) continue;
      if (option.key == _selectedSemester?.key) return;
      setState(() {
        _selectedSemester = option;
        _result = null;
        _refreshSucceeded = false;
      });
      await _load();
      return;
    }
  }

  Future<void> _load({bool showError = true}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _refreshSucceeded = false;
    });
    try {
      late final BookListResult result;
      BookListPageResult? initial;
      final selected = _selectedSemester;
      if (selected == null) {
        initial = await AuthService().fetchBookListPage(
          widget.studentId,
          widget.password,
        );
        result = initial.books;
      } else {
        result = await AuthService().fetchBookList(
          widget.studentId,
          widget.password,
          academicYear: selected.academicYear,
          termCode: selected.termCode,
        );
      }
      if (!mounted) return;
      setState(() {
        if (initial != null) {
          _semesterOptions = initial.semesters;
          _selectedSemester = initial.selectedSemester;
        }
        _result = result;
        _refreshSucceeded = true;
      });
    } on AuthException catch (error, stackTrace) {
      talker.error('书单查询失败', error, stackTrace);
      if (mounted && showError) {
        showAppSnackBar(context, error.message, severity: ToastSeverity.error);
      }
    } catch (error, stackTrace) {
      talker.error('书单查询异常', error, stackTrace);
      if (mounted && showError) {
        showAppSnackBar(context, '书单加载失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return AppPage(
      title: '书单查询',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _loading ? null : _load,
          tooltip: '刷新书单',
          loading: _loading,
          completed: _refreshSucceeded,
        ),
      ],
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.xs,
        bottomPadding: AppSpacing.xxl,
        children: [
          if (_selectedSemester != null) ...[
            _buildSemesterSelector(),
            const SizedBox(height: AppSpacing.md),
          ],
          if (result == null && _loading)
            const SizedBox(
              height: 200,
              child: Center(child: FCircularProgress()),
            )
          else if (result == null)
            const SizedBox(
              height: 200,
              child: AppStateView(icon: FLucideIcons.bookOpen, title: '书单加载失败'),
            )
          else if (result.isEmpty)
            const SizedBox(
              height: 200,
              child: AppStateView(
                icon: FLucideIcons.bookOpen,
                title: '该学期暂无书单',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                '共 ${result.items.length} 本教材',
                textAlign: TextAlign.center,
                style: context.theme.typography.bodySmall.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ),
            for (final item in result.items) _buildBookCard(item),
          ],
        ],
      ),
    );
  }

  Widget _buildSemesterSelector() {
    final selectedKey = _selectedSemester!.key;
    return SizedBox(
      width: double.infinity,
      child: FSelect<String>.rich(
        control: FSelectControl.lifted(
          value: selectedKey,
          onChange: _selectSemester,
        ),
        format: _optionLabel,
        children: [
          for (final option in _semesterOptions)
            FSelectItem.item(title: Text(option.label), value: option.key),
        ],
      ),
    );
  }

  Widget _buildBookCard(BookListItem item) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('《${item.textbookName}》', style: theme.typography.tileTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.courseName,
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            if (item.textbookTags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final tag in item.textbookTags) _TextbookTag(label: tag),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TextbookTag extends StatelessWidget {
  final String label;

  const _TextbookTag({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colors.muted,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: theme.typography.caption.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
    );
  }
}
