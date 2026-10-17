import 'dart:async';
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
import '../../utils/snackbar_helper.dart';
import 'learning_question_list_page.dart';
import 'learning_quiz_page.dart';

class LearningCenterPage extends StatefulWidget {
  final LearningRepository repository;
  final ResourceCourse course;
  final String coverUrl;

  const LearningCenterPage({
    super.key,
    required this.repository,
    required this.course,
    this.coverUrl = '',
  });

  @override
  State<LearningCenterPage> createState() => _LearningCenterPageState();
}

class _LearningCenterPageState extends State<LearningCenterPage> {
  LearningRepository get repository => widget.repository;
  ResourceCourse get course => widget.course;

  bool _refreshing = false;
  bool _bankSelectionMode = false;
  LearningListKind _bankListKind = LearningListKind.bank;
  final Set<String> _selectedBankKeys = {};
  List<CourseResourceItem> _resources = const [];
  List<CourseTextbookItem> _textbooks = const [];
  bool _detailsLoading = true;
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
    return id.isNotEmpty
        ? id
        : '${bank.name}\u0000${bank.isNew == true ? 'new' : 'old'}';
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

  Future<void> _clearCurrentCollection() async {
    if (_bankListKind == LearningListKind.bank) return;
    final isWrong = _bankListKind == LearningListKind.wrong;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: isWrong ? '清空错题集' : '清空收藏集',
      message: isWrong ? '确定清空全部错题记录吗？' : '确定取消全部收藏吗？',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed) return;
    if (isWrong) {
      await repository.clearWrongQuestions();
    } else {
      await repository.clearFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = !repository.isLoaded;
    return AppPage(
      title: '课程资源',
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
          : _bankListKind != LearningListKind.bank
          ? [
              AppIconButton(
                icon: FLucideIcons.trash2,
                onPress: _clearCurrentCollection,
                tooltip: _bankListKind == LearningListKind.wrong
                    ? '清空错题集'
                    : '清空收藏集',
              ),
            ]
          : [
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
    return AppPageBody(
      maxWidth: AppLayout.resultMaxWidth,
      child: Column(
        children: [
          _buildCourseHeader(theme),
          Expanded(
            child: FTabs(
              expands: true,
              // 只允许点击切换 Tab，不支持左右滑动（保留切换动画）。
              contentPhysics: const NeverScrollableScrollPhysics(),
              children: [
                FTabEntry(
                  label: const Text('题库'),
                  child: _buildBankTab(theme, banks),
                ),
                FTabEntry(
                  label: const Text('试卷'),
                  child: _detailsLoading
                      ? _buildDetailsLoading()
                      : _buildResourceTab(theme),
                ),
                FTabEntry(
                  label: const Text('教材'),
                  child: _detailsLoading
                      ? _buildDetailsLoading()
                      : _buildTextbookTab(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseHeader(FThemeData theme) {
    final name = course.name.trim().isEmpty ? course.code : course.name.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCover(theme, width: 86, height: 116),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.typography.body.lg.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (course.code.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '课程号 ${course.code}',
                      style: theme.typography.bodySmall.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(
    FThemeData theme, {
    required double width,
    required double height,
  }) {
    final radius = BorderRadius.circular(12);
    final placeholder = CustomPaint(
      painter: _DashedBorderPainter(color: theme.colors.border),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Icon(
            FLucideIcons.bookOpen,
            size: 22,
            color: theme.colors.mutedForeground,
          ),
        ),
      ),
    );
    final url = widget.coverUrl.trim();
    if (url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }

  Widget _buildDetailsLoading() => const Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: CircularProgressIndicator.adaptive(),
    ),
  );

  Widget _buildEmpty(FThemeData theme, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        message,
        style: theme.typography.bodySmall.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
    ),
  );

  List<_QuestionBankGroup> _courseBanks() {
    if (course.code.isEmpty) return _allBankGroups();
    return [
      for (final bank in _allBankGroups())
        if (bank.courseCodes.contains(course.code)) bank,
    ];
  }

  Widget _buildBankTab(FThemeData theme, List<_QuestionBankGroup> banks) {
    return Column(
      children: [
        Expanded(
          child: switch (_bankListKind) {
            LearningListKind.bank =>
              banks.isEmpty
                  ? _buildEmpty(theme, '该课程暂无关联题库')
                  : _buildBankList(theme, banks),
            LearningListKind.wrong => _buildCollectionList(
              theme,
              LearningListKind.wrong,
            ),
            LearningListKind.favorite => _buildCollectionList(
              theme,
              LearningListKind.favorite,
            ),
          },
        ),
        FBottomNavigationBar(
          index: _bankListKind.index,
          onChange: (index) {
            if (index < 0 || index >= LearningListKind.values.length) return;
            setState(() {
              _bankListKind = LearningListKind.values[index];
              if (_bankListKind != LearningListKind.bank) {
                _bankSelectionMode = false;
                _selectedBankKeys.clear();
              }
            });
          },
          children: const [
            FBottomNavigationBarItem(
              icon: Icon(FLucideIcons.library),
              label: Text('题库'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FLucideIcons.circleAlert),
              label: Text('错题集'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FLucideIcons.bookmark),
              label: Text('收藏集'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollectionList(FThemeData theme, LearningListKind kind) {
    final groups = _groupedQuestions(kind);
    if (groups.isEmpty) {
      return _buildEmpty(
        theme,
        kind == LearningListKind.wrong ? '这里还没有题目' : '这里还没有题目',
      );
    }
    final showHeadings = groups.length > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.xs,
        AppSpacing.xxl,
      ),
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          if (showHeadings)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Text(
                groups[index].name,
                style: theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          _buildBankTile(theme, groups[index], collectionKind: kind),
          if (index != groups.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  List<_QuestionBankGroup> _groupedQuestions(LearningListKind kind) {
    final questions = [
      for (final question in repository.questions)
        if (kind == LearningListKind.wrong
            ? repository.wrongIds.contains(question.id)
            : repository.favoriteIds.contains(question.id))
          question,
    ];
    final groups = <String, _QuestionBankGroup>{};
    for (final question in questions) {
      final key = _bankKey(question);
      final group = groups.putIfAbsent(
        key,
        () => _QuestionBankGroup(
          id: question.bankId,
          name: question.bankName,
          orderId: question.bankOrderId,
          isNew: question.bankIsNew,
        ),
      );
      group.questions.add(question);
    }
    final result = groups.values.toList()..sort(_compareBanks);
    return result;
  }

  Widget _buildBankList(FThemeData theme, List<_QuestionBankGroup> banks) {
    final latest = banks.where((bank) => bank.isNew == true).toList();
    final older = banks.where((bank) => bank.isNew != true).toList();
    final showHeadings = latest.isNotEmpty && older.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.xs,
        AppSpacing.xxl,
      ),
      children: [
        if (latest.isNotEmpty)
          ..._buildBankSection(
            theme,
            '最新题库',
            latest,
            showHeading: showHeadings,
          ),
        if (older.isNotEmpty)
          ..._buildBankSection(theme, '往年题库', older, showHeading: showHeadings),
      ],
    );
  }

  List<Widget> _buildBankSection(
    FThemeData theme,
    String label,
    List<_QuestionBankGroup> banks, {
    required bool showHeading,
  }) {
    return [
      if (showHeading)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Text(
            label,
            style: theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      for (var index = 0; index < banks.length; index++) ...[
        _buildBankTile(theme, banks[index]),
        if (index != banks.length - 1) const SizedBox(height: AppSpacing.md),
      ],
    ];
  }

  Widget _buildResourceTab(FThemeData theme) {
    if (_resources.isEmpty) return _buildEmpty(theme, '该课程暂无试卷');
    return _buildPdfList(theme, [
      for (final item in _resources)
        _PdfEntry(
          id: item.id,
          title: item.name,
          sizeBytes: item.sizeBytes,
          hasPdf: item.hasPdf,
          urlLoader: () => ControlService.instance.fetchResourceURL(item.id),
        ),
    ]);
  }

  Widget _buildTextbookTab(FThemeData theme) {
    if (_textbooks.isEmpty) return _buildEmpty(theme, '该课程暂无教材');
    return _buildPdfList(theme, [
      for (final item in _textbooks)
        _PdfEntry(
          id: item.id,
          title: item.name,
          sizeBytes: item.sizeBytes,
          hasPdf: item.hasPdf,
          urlLoader: () => ControlService.instance.fetchTextbookURL(item.id),
        ),
    ]);
  }

  Widget _buildPdfList(FThemeData theme, List<_PdfEntry> entries) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xxl,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => _buildPdfTile(theme, entries[index]),
    );
  }

  Widget _buildPdfTile(FThemeData theme, _PdfEntry entry) {
    final downloaded = _downloadedIds.contains(entry.id);
    final downloading = _downloadingIds.contains(entry.id);
    final progress = _downloadProgress[entry.id] ?? 0;
    final size = _formatFileSize(entry.sizeBytes);
    final meta = downloading
        ? (progress > 0 ? '下载中 ${(progress * 100).round()}%' : '下载中…')
        : [if (size.isNotEmpty) size, downloaded ? '已下载' : '未下载'].join('  ');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: entry.hasPdf && !downloading
          ? () => unawaited(_handlePdf(entry))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                width: 44,
                height: 56,
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
              _PdfIcon(color: theme.colors.destructive),
          ],
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
      showAppSnackBar(context, '已下载', severity: ToastSeverity.success);
      await ResourceDownloadService.instance.open(file);
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
      final key = source.id.trim().isNotEmpty
          ? source.id.trim()
          : '${source.name}\u0000${source.isNew == true ? 'new' : 'old'}';
      groups[key] = _QuestionBankGroup(
        id: source.id,
        name: source.name,
        orderId: source.orderId,
        isNew: source.isNew,
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
          () => _QuestionBankGroup(
            id: question.bankId,
            name: question.bankName,
            orderId: question.bankOrderId,
            isNew: question.bankIsNew,
          ),
        );
        bank.questions.add(question);
      }
    }
    final result = groups.values.toList()..sort(_compareBanks);
    return result;
  }

  int _compareBanks(_QuestionBankGroup a, _QuestionBankGroup b) {
    final aOrder = a.orderId;
    final bOrder = b.orderId;
    if (aOrder != null && bOrder != null && aOrder != bOrder) {
      return aOrder.compareTo(bOrder);
    }
    if (aOrder != null && bOrder == null) return -1;
    if (aOrder == null && bOrder != null) return 1;
    return a.name.compareTo(b.name);
  }

  String _bankKey(LearningQuestion question) {
    final bankId = question.bankId.trim();
    return bankId.isEmpty
        ? '${question.bankName}\u0000${question.bankIsNew == true ? 'new' : 'old'}'
        : bankId;
  }

  FTile _buildBankTile(
    FThemeData theme,
    _QuestionBankGroup bank, {
    LearningListKind? collectionKind,
  }) {
    final selectingBanks = collectionKind == null && _bankSelectionMode;
    final selected =
        selectingBanks && _selectedBankKeys.contains(_bankSelectionKey(bank));
    final name = bank.name.trim().isEmpty ? '题库' : bank.name.trim();
    final onPress = bank.locked
        ? () => unawaited(_openCdkRedeem(bank))
        : bank.questions.isEmpty
        ? null
        : () => unawaited(
            _openQuestions(
              bank.questions,
              pageTitle: name,
              mode: collectionKind == LearningListKind.favorite
                  ? LearningQuizMode.memorizeFlow
                  : LearningQuizMode.normal,
              retryIncorrect: collectionKind == LearningListKind.wrong,
              lockMode: collectionKind == LearningListKind.favorite,
            ),
          );
    final needsCdk = bank.locked;
    final unlockedWithCdk = bank.requiresCDK && !bank.locked;
    final details = switch (collectionKind) {
      LearningListKind.wrong => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: _CountBadge(theme: theme, count: bank.questions.length),
      ),
      LearningListKind.favorite => AppIconButton(
        icon: FLucideIcons.x,
        onPress: () => unawaited(_removeFavoriteBank(bank)),
        tooltip: '删除此收藏题库',
        size: FButtonSizeVariant.sm,
      ),
      _ => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (needsCdk)
            _CdkBadge(
              theme: theme,
              label: 'CDK',
              foreground: theme.colors.semantic.onWarningContainer,
              background: theme.colors.semantic.warningContainer,
            )
          else if (unlockedWithCdk)
            _CdkBadge(
              theme: theme,
              label: '已解锁',
              foreground: theme.colors.semantic.onSuccessContainer,
              background: theme.colors.semantic.successContainer,
            ),
          if (needsCdk || unlockedWithCdk) const SizedBox(width: AppSpacing.sm),
          Text(
            '${_bankProgressPercent(bank)}%',
            style: theme.typography.bodySmall.copyWith(
              color: theme.colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    };

    return FTile(
      selected: selected,
      style: FItemStyleDelta.delta(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        backgroundColor: FVariantsValueDelta.delta([
          FVariantValueDeltaOperation.base(Colors.transparent),
        ]),
        contentDecoration: FVariantsDelta.delta([
          FVariantOperation.all(
            DecorationDelta.value(
              ShapeDecoration(
                color: selected
                    ? theme.colors.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selected
                        ? theme.colors.primary
                        : theme.colors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
              ),
            ),
          ),
        ]),
        contentStyle: FItemContentStyleDelta.delta(
          suffixedPadding: const EdgeInsetsGeometryDelta.value(
            EdgeInsetsDirectional.fromSTEB(0, 0, 12, 0),
          ),
          unsuffixedPadding: const EdgeInsetsGeometryDelta.value(
            EdgeInsetsDirectional.fromSTEB(0, 0, 12, 0),
          ),
          prefixIconSpacing: 8,
        ),
      ),
      prefix: _BankInitial(
        initial: _bankInitial(name),
        outerColor: selected
            ? theme.colors.primary.withValues(alpha: 0.3)
            : Color.lerp(theme.colors.primary, Colors.white, 0.55)!,
        innerColor: Color.lerp(theme.colors.primary, Colors.black, 0.2)!,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.body.md.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      details: details,
      onPress: selectingBanks
          ? bank.questions.isEmpty
                ? null
                : () => _toggleBankSelection(bank)
          : onPress,
      onLongPress: collectionKind != null || bank.questions.isEmpty
          ? null
          : () => _enterBankSelectionMode(bank),
    );
  }

  Future<void> _removeFavoriteBank(_QuestionBankGroup bank) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除收藏题库',
      message: '确定取消收藏「${bank.name}」中的全部题目吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (confirmed) {
      await repository.removeFavorites(bank.questions.map((q) => q.id));
    }
  }

  int _bankProgressPercent(_QuestionBankGroup bank) {
    if (bank.questions.isEmpty) return 0;
    final judged = bank.questions
        .where((q) => repository.isJudged(q.id))
        .length;
    return (judged * 100 / bank.questions.length).round();
  }

  static String _bankInitial(String name) {
    final match = RegExp(r'[一-龥]').firstMatch(name);
    if (match != null) return match.group(0)!;
    final first = name.runes.firstOrNull;
    return first == null ? '题' : String.fromCharCode(first);
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
    final updated = _findBank(id: bank.id, name: bank.name, isNew: bank.isNew);
    if (updated != null && !updated.locked && updated.questions.isNotEmpty) {
      unawaited(_openQuestions(updated.questions, pageTitle: name));
    }
  }

  _QuestionBankGroup? _findBank({
    required String id,
    required String name,
    required bool? isNew,
  }) {
    for (final bank in _allBankGroups()) {
      final idMatch = id.trim().isNotEmpty && bank.id.trim() == id.trim();
      final nameMatch = bank.name == name && bank.isNew == isNew;
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

class _PdfIcon extends StatelessWidget {
  final Color color;

  const _PdfIcon({required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorderPainter(color: color),
    child: SizedBox(
      width: 44,
      height: 56,
      child: Center(
        child: Text(
          'PDF',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ),
  );
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

class _BankInitial extends StatelessWidget {
  final String initial;
  final Color outerColor;
  final Color innerColor;

  const _BankInitial({
    required this.initial,
    required this.outerColor,
    required this.innerColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: outerColor,
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: TextStyle(
        color: innerColor,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CdkBadge extends StatelessWidget {
  final FThemeData theme;
  final String label;
  final Color foreground;
  final Color background;

  const _CdkBadge({
    required this.theme,
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.typography.bodySmall.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final FThemeData theme;
  final int count;

  const _CountBadge({required this.theme, required this.count});

  @override
  Widget build(BuildContext context) => Text(
    '$count',
    style: theme.typography.bodySmall.copyWith(
      color: theme.colors.mutedForeground,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _QuestionBankGroup {
  final String id;
  final String name;
  final int? orderId;
  final bool? isNew;
  final bool requiresCDK;
  final bool locked;
  final List<String> courseCodes;
  final List<LearningQuestion> questions;

  _QuestionBankGroup({
    required this.id,
    required this.name,
    required this.orderId,
    required this.isNew,
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
