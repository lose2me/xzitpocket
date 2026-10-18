import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/learning_question.dart';
import '../../models/resource_center.dart';
import '../../services/control_service.dart';
import '../../services/learning_repository.dart';
import '../../services/resource_download_service.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../ui/resource_tag.dart';
import '../../utils/snackbar_helper.dart';
import 'learning_question_list_page.dart';
import 'learning_quiz_page.dart';

class LearningCenterPage extends StatefulWidget {
  final LearningRepository repository;
  final ResourceCourse course;

  const LearningCenterPage({
    super.key,
    required this.repository,
    required this.course,
  });

  @override
  State<LearningCenterPage> createState() => _LearningCenterPageState();
}

class _LearningCenterPageState extends State<LearningCenterPage> {
  LearningRepository get repository => widget.repository;
  ResourceCourse get course => widget.course;

  bool _refreshing = false;
  bool _bankSelectionMode = false;
  final List<bool> _expandedSections = [true, true, true];
  bool _detailsLoading = true;
  final Set<String> _selectedBankKeys = {};
  List<CourseResourceItem> _resources = const [];
  List<CourseTextbookItem> _textbooks = const [];
  final Set<String> _downloadedIds = {};
  final Set<String> _downloadingIds = {};
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    repository.addListener(_onRepositoryUpdate);
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    await repository.load();
    if (!mounted) return;
    try {
      // Version compare happens inside sync; only changed banks are downloaded.
      await repository.sync();
    } catch (error, stackTrace) {
      talker.warning('题库同步失败', error, stackTrace);
    }
    await _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    if (!mounted) return;
    setState(() => _detailsLoading = true);
    try {
      final control = ControlService.instance;
      final results = await Future.wait([
        control.fetchCourseResources(course.code),
        control.fetchCourseTextbooks(course.code),
      ]);
      if (!mounted) return;
      setState(() {
        _resources = results[0] as List<CourseResourceItem>;
        _textbooks = results[1] as List<CourseTextbookItem>;
      });
      unawaited(_refreshDownloadedStatuses());
    } catch (error, stackTrace) {
      talker.warning('课程资源加载失败', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _resources = const [];
        _textbooks = const [];
      });
    } finally {
      if (mounted) setState(() => _detailsLoading = false);
    }
  }

  @override
  void dispose() {
    repository.removeListener(_onRepositoryUpdate);
    super.dispose();
  }

  void _onRepositoryUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshLibrary({bool showToast = true}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await repository.refresh();
      await _loadCourseDetails();
      if (mounted && showToast) {
        showAppSnackBar(context, '资源已刷新', severity: ToastSeverity.success);
      }
    } on ControlApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, severity: ToastSeverity.error);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, '刷新资源失败，请稍后重试', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _bankSelectionKey(_QuestionBankGroup bank) {
    final id = bank.id.trim();
    return id.isNotEmpty ? id : bank.name;
  }

  void _enterBankSelectionMode([_QuestionBankGroup? bank]) {
    setState(() {
      _bankSelectionMode = true;
      if (bank != null && bank.questions.isNotEmpty) {
        _selectedBankKeys.add(_bankSelectionKey(bank));
      }
    });
  }

  void _toggleBankSelection(_QuestionBankGroup bank) {
    if (bank.questions.isEmpty) return;
    final key = _bankSelectionKey(bank);
    setState(() {
      if (!_selectedBankKeys.add(key)) _selectedBankKeys.remove(key);
      _bankSelectionMode = _selectedBankKeys.isNotEmpty;
    });
  }

  void _exitBankSelectionMode() {
    setState(() {
      _bankSelectionMode = false;
      _selectedBankKeys.clear();
    });
  }

  Future<void> _clearSelectedBankProgress() async {
    final selectedBanks = [
      for (final bank in _allBankGroups())
        if (_selectedBankKeys.contains(_bankSelectionKey(bank))) bank,
    ];
    final questionIds = {
      for (final bank in selectedBanks)
        for (final question in bank.questions) question.id,
    };
    if (questionIds.isEmpty) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '清空做题进度',
      message: '将清空已选 ${selectedBanks.length} 个题库的答题进度，错题集和收藏集会保留。',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed) return;
    await repository.resetProgress(questionIds);
    if (mounted) _exitBankSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final loading = !repository.isLoaded;
    return AppPage(
      title: '',
      actions: loading
          ? const [
              AppIconButton(
                icon: FLucideIcons.refreshCw,
                onPress: null,
                tooltip: '正在加载资源',
                loading: true,
              ),
            ]
          : _bankSelectionMode
          ? [
              AppIconButton(
                icon: FLucideIcons.trash2,
                onPress: _selectedBankKeys.isEmpty
                    ? null
                    : _clearSelectedBankProgress,
                tooltip: '清空已选题库进度',
              ),
            ]
          : [
              AppIconButton(
                icon: FLucideIcons.circleAlert,
                onPress: () => _openCollection(LearningListKind.wrong),
                tooltip: '错题集',
              ),
              AppIconButton(
                icon: FLucideIcons.bookmark,
                onPress: () => _openCollection(LearningListKind.favorite),
                tooltip: '收藏集',
              ),
              AppIconButton(
                icon: FLucideIcons.refreshCw,
                onPress: _refreshing ? null : _refreshLibrary,
                tooltip: '刷新资源',
                loading: _refreshing,
              ),
            ],
      child: loading
          ? const AppStateView(icon: FLucideIcons.library, title: '正在加载资源')
          : repository.libraryUnavailable
          ? const AppPageBody(
              maxWidth: AppLayout.resultMaxWidth,
              child: AppStateView(
                icon: FLucideIcons.shieldAlert,
                title: '风险控制',
                description: '您的账户被暂时禁用',
              ),
            )
          : _buildCourseBody(context),
    );
  }

  Widget _buildCourseBody(BuildContext context) {
    final theme = context.theme;
    final banks = _courseBanks();
    final textbookLoading = _detailsLoading && _textbooks.isEmpty;
    final bankLoading = _detailsLoading && banks.isEmpty;
    final resourceLoading = _detailsLoading && _resources.isEmpty;
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.sm,
      bottomPadding: AppSpacing.xxl,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: _buildCourseHeader(theme),
        ),
        _buildSectionHeader(theme, 0, '教材', _expandedSections[0]),
        if (_expandedSections[0]) ...[
          const SizedBox(height: AppSpacing.sm),
          if (_textbooks.isNotEmpty)
            for (final item in _textbooks) ...[
              _buildPdfTile(
                theme,
                _PdfEntry(
                  id: item.id,
                  title: item.name,
                  sizeBytes: item.sizeBytes,
                  hasPdf: item.hasPdf,
                  urlLoader: () =>
                      ControlService.instance.fetchTextbookURL(item.id),
                ),
                color: theme.colors.destructive,
              ),
              const SizedBox(height: AppSpacing.sm),
            ]
          else if (textbookLoading)
            _buildLoading(theme)
          else
            _buildUploadEmpty(theme, label: '暂无资源'),
          const SizedBox(height: AppSpacing.md),
        ],
        _buildSectionHeader(theme, 1, '题库', _expandedSections[1]),
        if (_expandedSections[1]) ...[
          const SizedBox(height: AppSpacing.sm),
          if (banks.isNotEmpty)
            for (final bank in banks) ...[
              _buildBankCard(theme, bank),
              const SizedBox(height: AppSpacing.sm),
            ]
          else if (bankLoading)
            _buildLoading(theme)
          else
            _buildUploadEmpty(theme, label: '暂无题库', icon: FLucideIcons.library),
          const SizedBox(height: AppSpacing.md),
        ],
        _buildSectionHeader(theme, 2, '试卷', _expandedSections[2]),
        if (_expandedSections[2]) ...[
          const SizedBox(height: AppSpacing.sm),
          if (_resources.isNotEmpty)
            for (final item in _resources) ...[
              _buildPdfTile(
                theme,
                _PdfEntry(
                  id: item.id,
                  title: item.name,
                  sizeBytes: item.sizeBytes,
                  hasPdf: item.hasPdf,
                  urlLoader: () =>
                      ControlService.instance.fetchResourceURL(item.id),
                ),
                color: theme.colors.semantic.info,
              ),
              const SizedBox(height: AppSpacing.sm),
            ]
          else if (resourceLoading)
            _buildLoading(theme)
          else
            _buildUploadEmpty(theme, label: '暂无资源'),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    FThemeData theme,
    int index,
    String label,
    bool expanded,
  ) {
    final (background, foreground) = switch (index) {
      0 => (
        theme.colors.destructive.withValues(alpha: 0.12),
        theme.colors.destructive,
      ),
      1 => (
        theme.colors.semantic.warning.withValues(alpha: 0.14),
        theme.colors.semantic.warning,
      ),
      _ => (
        theme.colors.semantic.info.withValues(alpha: 0.12),
        theme.colors.semantic.info,
      ),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _expandedSections[index] = !_expandedSections[index]);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResourceTag(
              label: label,
              background: background,
              foreground: foreground,
            ),
            Container(
              width: double.infinity,
              height: expanded ? 2 : 1,
              color: foreground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadEmpty(
    FThemeData theme, {
    required String label,
    IconData icon = FLucideIcons.arrowUpToLine,
  }) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: theme.colors.border),
      child: SizedBox(
        width: double.infinity,
        height: 112,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.colors.mutedForeground),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: theme.typography.bodySmall.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(FThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Center(
      child: Text(
        '正在加载…',
        style: theme.typography.bodySmall.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
    ),
  );

  Widget _buildCourseHeader(FThemeData theme) {
    final name = course.name.trim();
    final code = shortCourseCode(course.code);
    final title = name.isNotEmpty ? name : (code.isNotEmpty ? code : '课程');
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.body.lg.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  List<_QuestionBankGroup> _courseBanks() {
    if (course.code.isEmpty) return _allBankGroups();
    return [
      for (final bank in _allBankGroups())
        if (bank.courseCodes.contains(course.code)) bank,
    ];
  }

  Widget _buildPdfTile(
    FThemeData theme,
    _PdfEntry entry, {
    required Color color,
  }) {
    final downloaded = _downloadedIds.contains(entry.id);
    final downloading = _downloadingIds.contains(entry.id);
    final progress = _downloadProgress[entry.id] ?? 0;
    final size = _formatFileSize(entry.sizeBytes);
    final meta = downloading
        ? (progress > 0 ? '下载中 ${(progress * 100).round()}%' : '下载中…')
        : [if (size.isNotEmpty) size, downloaded ? '已下载' : '未下载'].join('  ');
    return Material(
      color: theme.colors.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: entry.hasPdf && !downloading
            ? () => unawaited(_handlePdf(entry))
            : null,
        onLongPress: entry.hasPdf && downloaded && !downloading
            ? () => unawaited(_reExportPdf(entry))
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colors.border.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pdfFileName(entry.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.md.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: theme.typography.bodySmall.copyWith(
                        color: theme.colors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (downloading)
                SizedBox(
                  width: 42,
                  height: 54,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              else
                _DocumentIcon(color: color, label: 'PDF'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshDownloadedStatuses() async {
    final ids = <String>[
      for (final item in _resources) item.id,
      for (final item in _textbooks) item.id,
    ];
    final downloaded = <String>{};
    for (final id in ids) {
      if (await ResourceDownloadService.instance.isDownloaded(id)) {
        downloaded.add(id);
      }
    }
    if (!mounted) return;
    setState(() {
      _downloadedIds
        ..clear()
        ..addAll(downloaded);
    });
  }

  Future<void> _handlePdf(_PdfEntry entry) async {
    if (_downloadingIds.contains(entry.id)) return;
    try {
      if (_downloadedIds.contains(entry.id)) {
        final file = await ResourceDownloadService.instance.fileFor(entry.id);
        if (await file.exists()) {
          await ResourceDownloadService.instance.open(file);
          return;
        }
        if (mounted) setState(() => _downloadedIds.remove(entry.id));
      }
      setState(() {
        _downloadingIds.add(entry.id);
        _downloadProgress[entry.id] = 0;
      });
      final url = await entry.urlLoader();
      if (url.isEmpty) throw StateError('empty url');
      final file = await ResourceDownloadService.instance.download(
        entry.id,
        url,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress[entry.id] = total > 0 ? received / total : 0;
          });
        },
      );
      if (!mounted) return;
      setState(() => _downloadedIds.add(entry.id));
      await _exportPdf(file, entry.title, firstDownload: true);
    } catch (error, stackTrace) {
      talker.warning('下载资源失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '下载失败，请稍后重试', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(entry.id);
          _downloadProgress.remove(entry.id);
        });
      }
    }
  }

  Future<void> _reExportPdf(_PdfEntry entry) async {
    final file = await ResourceDownloadService.instance.fileFor(entry.id);
    if (!await file.exists()) {
      if (mounted) setState(() => _downloadedIds.remove(entry.id));
      return;
    }
    await _exportPdf(file, entry.title);
  }

  Future<void> _exportPdf(
    File file,
    String title, {
    bool firstDownload = false,
  }) async {
    try {
      final saved = await ResourceDownloadService.instance.saveToDocuments(
        file,
        _pdfFileName(title),
      );
      if (!mounted) return;
      if (saved) {
        showAppSnackBar(context, '已保存', severity: ToastSeverity.success);
      } else {
        showAppSnackBar(
          context,
          firstDownload ? '已下载，未另存' : '已取消保存',
          severity: ToastSeverity.warning,
        );
      }
    } catch (error, stackTrace) {
      talker.warning('保存 PDF 失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '保存失败，请稍后重试', severity: ToastSeverity.warning);
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _pdfFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.toLowerCase().endsWith('.pdf')) return trimmed;
    return '$trimmed.pdf';
  }

  List<_QuestionBankGroup> _allBankGroups() {
    final groups = <String, _QuestionBankGroup>{};
    for (final source in repository.banks) {
      final key = source.id.trim().isNotEmpty ? source.id.trim() : source.name;
      groups[key] = _QuestionBankGroup(
        id: source.id,
        name: source.name,
        requiresCDK: source.requiresCDK,
        locked: source.locked,
        courseCodes: source.courseCodes,
        questions: source.questions,
      );
    }
    if (groups.isEmpty) {
      for (final question in repository.questions) {
        final key = _bankKey(question);
        final bank = groups.putIfAbsent(
          key,
          () =>
              _QuestionBankGroup(id: question.bankId, name: question.bankName),
        );
        bank.questions.add(question);
      }
    }
    final result = groups.values.toList()..sort(_compareBanks);
    return result;
  }

  int _compareBanks(_QuestionBankGroup a, _QuestionBankGroup b) =>
      a.name.compareTo(b.name);

  String _bankKey(LearningQuestion question) {
    final bankId = question.bankId.trim();
    return bankId.isEmpty ? question.bankName : bankId;
  }

  Widget _buildBankCard(FThemeData theme, _QuestionBankGroup bank) {
    final selectingBanks = _bankSelectionMode;
    final selected =
        selectingBanks && _selectedBankKeys.contains(_bankSelectionKey(bank));
    final name = bank.name.trim().isEmpty ? '题库' : bank.name.trim();
    final progress = _bankProgressPercent(bank);
    final meta = bank.locked
        ? '需要 CDK 解锁'
        : '${bank.questions.length} 道题  ·  进度 $progress%';
    final onPress = selectingBanks
        ? (bank.questions.isEmpty ? null : () => _toggleBankSelection(bank))
        : bank.locked
        ? () => unawaited(_openCdkRedeem(bank))
        : bank.questions.isEmpty
        ? null
        : () => unawaited(_openQuestions(bank.questions, pageTitle: name));
    return Material(
      color: theme.colors.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPress,
        onLongPress: bank.questions.isEmpty
            ? null
            : () => _enterBankSelectionMode(bank),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colors.primary
                  : theme.colors.border.withValues(alpha: 0.55),
              width: selected ? 1.5 : 1,
            ),
            color: selected
                ? theme.colors.primary.withValues(alpha: 0.06)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.md.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: theme.typography.bodySmall.copyWith(
                        color: theme.colors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _DocumentIcon(color: theme.colors.primary, label: 'EXAM'),
            ],
          ),
        ),
      ),
    );
  }

  void _openCollection(LearningListKind kind) {
    _exitBankSelectionMode();
    unawaited(
      Navigator.of(context).push(
        appRoute(
          name: kind == LearningListKind.wrong
              ? AppRouteNames.learningWrongQuestions
              : AppRouteNames.learningFavorites,
          builder: (_) => LearningQuestionListPage(
            repository: repository,
            kind: kind,
            courseCode: course.code,
          ),
        ),
      ),
    );
  }

  int _bankProgressPercent(_QuestionBankGroup bank) {
    if (bank.questions.isEmpty) return 0;
    final judged = bank.questions
        .where((q) => repository.isJudged(q.id))
        .length;
    return (judged * 100 / bank.questions.length).round();
  }

  Future<void> _openCdkRedeem(_QuestionBankGroup bank) async {
    final name = bank.name.trim().isEmpty ? '题库' : bank.name.trim();
    if (!repository.canRedeemCdk || bank.id.trim().isEmpty) {
      showAppSnackBar(context, '此题库需要 CDK 解锁', severity: ToastSeverity.warning);
      return;
    }
    final redeemed = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        animation: animation,
        builder: (context, style) => _CdkRedeemSheet(
          bankName: name,
          onRedeem: (code) => repository.redeemCdk(code, bank.id),
        ),
      ),
    );
    if (redeemed != true || !mounted) return;
    showAppSnackBar(context, '题库兑换成功', severity: ToastSeverity.success);
    final updated = _findBank(id: bank.id, name: bank.name);
    if (updated != null && !updated.locked && updated.questions.isNotEmpty) {
      unawaited(_openQuestions(updated.questions, pageTitle: name));
    }
  }

  _QuestionBankGroup? _findBank({required String id, required String name}) {
    for (final bank in _allBankGroups()) {
      final idMatch = id.trim().isNotEmpty && bank.id.trim() == id.trim();
      final nameMatch = bank.name == name;
      if (idMatch || nameMatch) return bank;
    }
    return null;
  }

  Future<void> _openQuestions(
    List<LearningQuestion> questions, {
    String pageTitle = '题库',
    LearningQuizMode mode = LearningQuizMode.normal,
    bool retryIncorrect = false,
    bool lockMode = false,
  }) async {
    final questionIds = [for (final question in questions) question.id];
    if (questionIds.isEmpty) return;
    if (retryIncorrect) {
      // Wrong-question practice is a retry flow. Clear only the judged state
      // and answer draft; the repository keeps wrongIds until a correct answer.
      await repository.resetProgress(questionIds);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.learningQuiz,
        builder: (_) => LearningQuizPage(
          repository: repository,
          questionIds: questionIds,
          pageTitle: pageTitle,
          mode: mode,
          lockMode: lockMode,
        ),
      ),
    );
  }
}

class _PdfEntry {
  final String id;
  final String title;
  final int sizeBytes;
  final bool hasPdf;
  final Future<String> Function() urlLoader;

  const _PdfEntry({
    required this.id,
    required this.title,
    required this.sizeBytes,
    required this.hasPdf,
    required this.urlLoader,
  });
}

class _DocumentIcon extends StatelessWidget {
  final Color color;
  final String label;

  const _DocumentIcon({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(42, 54),
    painter: _PdfIconPainter(color: color, label: label),
  );
}

class _PdfIconPainter extends CustomPainter {
  final Color color;
  final String label;

  const _PdfIconPainter({required this.color, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    const fold = 11.0;
    final w = size.width;
    final h = size.height;
    final doc = Path()
      ..moveTo(1, 1)
      ..lineTo(w - fold, 1)
      ..lineTo(w - 1, fold)
      ..lineTo(w - 1, h - 1)
      ..lineTo(1, h - 1)
      ..close();
    canvas.drawPath(doc, Paint()..color = color.withValues(alpha: 0.08));

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _drawDashed(canvas, doc, stroke);
    _drawDashed(
      canvas,
      Path()
        ..moveTo(w - fold, 1)
        ..lineTo(w - fold, fold)
        ..lineTo(w - 1, fold),
      stroke,
    );

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: label == 'EXAM' ? 9 : 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset((w - labelPainter.width) / 2, (h - labelPainter.height) / 2 + 4),
    );
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 4.5;
    const gap = 3.5;
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
  bool shouldRepaint(covariant _PdfIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.label != label;
}

class _QuestionBankGroup {
  final String id;
  final String name;
  final bool requiresCDK;
  final bool locked;
  final List<String> courseCodes;
  final List<LearningQuestion> questions;

  _QuestionBankGroup({
    required this.id,
    required this.name,
    this.requiresCDK = false,
    this.locked = false,
    this.courseCodes = const [],
    List<LearningQuestion>? questions,
  }) : questions = questions ?? [];
}

class _CdkRedeemSheet extends StatefulWidget {
  final String bankName;
  final Future<void> Function(String code) onRedeem;

  const _CdkRedeemSheet({required this.bankName, required this.onRedeem});

  @override
  State<_CdkRedeemSheet> createState() => _CdkRedeemSheetState();
}

class _CdkRedeemSheetState extends State<_CdkRedeemSheet> {
  final _controller = TextEditingController();
  bool _redeeming = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_redeeming) return;
    final code = _controller.text.trim();
    if (code.isEmpty) {
      showAppSnackBar(context, '请输入 CDK', severity: ToastSeverity.warning);
      return;
    }
    setState(() => _redeeming = true);
    try {
      await widget.onRedeem(code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ControlApiException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.message, severity: ToastSeverity.error);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '题库兑换失败，请稍后重试', severity: ToastSeverity.error);
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Center(
              child: Text(
                '解锁题库',
                textAlign: TextAlign.center,
                style: theme.typography.pageTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '「${widget.bankName}」需要 CDK 解锁后才能练习',
            style: theme.typography.bodySmall.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _controller,
            hint: '输入 CDK',
            prefix: const Icon(FLucideIcons.keyRound),
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => unawaited(_submit()),
            enabled: !_redeeming,
            clearable: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FButton(
              variant: FButtonVariant.primary,
              onPress: _redeeming ? null : () => unawaited(_submit()),
              prefix: const Icon(FLucideIcons.unlock),
              child: Text(_redeeming ? '兑换中...' : '兑换'),
            ),
          ),
        ],
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
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
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
