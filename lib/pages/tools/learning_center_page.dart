import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';

import '../../models/learning_question.dart';
import '../../models/resource_center.dart';
import '../../services/control_service.dart';
import '../../services/learning_repository.dart';
import '../../services/preferences_storage.dart';
import '../../services/resource_center_cache.dart';
import '../../services/resource_download_service.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../ui/resource_tag.dart';
import '../../utils/snackbar_helper.dart';
import 'learning_quiz_page.dart';

class LearningCenterPage extends StatefulWidget {
  final LearningRepository repository;
  final ResourceCourse course;
  final PreferencesStorage preferencesStorage;

  const LearningCenterPage({
    super.key,
    required this.repository,
    required this.course,
    required this.preferencesStorage,
  });

  @override
  State<LearningCenterPage> createState() => _LearningCenterPageState();
}

class _LearningCenterPageState extends State<LearningCenterPage> {
  LearningRepository get repository => widget.repository;
  ResourceCourse get course => widget.course;

  bool _refreshing = false;
  bool _banksLoading = true;
  bool _bankSelectionMode = false;
  final List<bool> _expandedSections = [true, true, true];
  bool _detailsLoading = true;
  final Set<String> _selectedBankKeys = {};
  List<CourseResourceItem> _resources = const [];
  List<CourseTextbookItem> _textbooks = const [];
  final Set<String> _downloadedIds = {};
  final Set<String> _downloadingIds = {};
  final Map<String, double> _downloadProgress = {};
  final Set<String> _aiDownloading = {};

  @override
  void initState() {
    super.initState();
    // Restore synchronously so the first frame already has the cached rows;
    // waiting for repository.load() used to flash the skeleton first.
    _restoreCourseCache();
    repository.addListener(_onRepositoryUpdate);
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    // Question banks and course files are independent; neither should delay
    // the other's first paint.
    unawaited(_loadBanks());
    await _loadCourseDetails();
  }

  Future<void> _loadBanks() async {
    try {
      await repository.load();
      if (!mounted) return;
      // Version compare happens inside sync; only changed banks are downloaded.
      // load() already syncs on a cold cache, so only follow up on a cache hit.
      if (repository.loadedFromCache) await repository.sync();
    } catch (error, stackTrace) {
      talker.warning('题库同步失败', error, stackTrace);
    } finally {
      if (mounted && _banksLoading) setState(() => _banksLoading = false);
    }
  }

  void _restoreCourseCache() {
    final snapshot = ResourceCourseSnapshot.decode(
      widget.preferencesStorage.getResourceCourseCache(course.code),
    );
    if (snapshot == null) return;
    _resources = snapshot.resources;
    _textbooks = snapshot.textbooks;
    _detailsLoading = false;
    unawaited(_refreshDownloadedStatuses());
  }

  /// Loads resources and textbooks unless the cached rows already match the
  /// course version returned by control. Failures keep whatever is on screen.
  Future<void> _loadCourseDetails({bool force = false}) async {
    if (!mounted) return;
    if (!force) {
      final cached = ResourceCourseSnapshot.decode(
        widget.preferencesStorage.getResourceCourseCache(course.code),
      );
      if (cached != null &&
          cached.version.isNotEmpty &&
          cached.version == course.version) {
        setState(() {
          _resources = cached.resources;
          _textbooks = cached.textbooks;
          _detailsLoading = false;
        });
        unawaited(_refreshDownloadedStatuses());
        return;
      }
    }
    setState(() => _detailsLoading = true);
    try {
      final control = ControlService.instance;
      final results = await Future.wait<Object>([
        control.fetchCourseResources(course.code),
        control.fetchCourseTextbooks(course.code),
      ]);
      final resources =
          results[0]
              as ({List<CourseResourceItem> items, int total, String version});
      final textbooks =
          results[1]
              as ({List<CourseTextbookItem> items, int total, String version});
      // Independent requests may straddle a content update. Mixed revisions
      // can be displayed but must not be saved as a valid cache hit.
      final version = resources.version == textbooks.version
          ? resources.version
          : '';
      final snapshot = ResourceCourseSnapshot(
        version: version,
        resources: resources.items,
        textbooks: textbooks.items,
      );
      await widget.preferencesStorage.setResourceCourseCache(
        course.code,
        snapshot.encode(),
      );
      if (!mounted) return;
      setState(() {
        _resources = resources.items;
        _textbooks = textbooks.items;
      });
      unawaited(_refreshDownloadedStatuses());
    } catch (error, stackTrace) {
      talker.warning('课程资源加载失败', error, stackTrace);
      if (!mounted) return;
      showAppSnackBar(
        context,
        _resources.isEmpty && _textbooks.isEmpty
            ? '资源加载失败，请稍后重试'
            : '刷新失败，正在显示已缓存的数据',
        severity: ToastSeverity.warning,
      );
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
    if (_refreshing) {
      markAppRefreshHandled();
      return;
    }
    setState(() => _refreshing = true);
    try {
      // Refresh banks and the course detail in parallel; each keeps its cached
      // state when its own request fails.
      await Future.wait([
        repository.refresh(),
        _loadCourseDetails(force: true),
      ]);
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
      title: '清空做题进度？',
      message: '已选 ${selectedBanks.length} 个题库的进度将被清空，错题集和收藏集保留。',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed) return;
    await repository.resetProgress(questionIds);
    if (mounted) _exitBankSelectionMode();
  }

  String get _title {
    final name = course.name.trim();
    if (name.isNotEmpty) return name;
    final code = shortCourseCode(course.code);
    return code.isNotEmpty ? code : '课程';
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: _title,
      actions: _bankSelectionMode
          ? [
              AppIconButton(
                icon: FLucideIcons.trash2,
                onPress: _selectedBankKeys.isEmpty
                    ? null
                    : _clearSelectedBankProgress,
                tooltip: '清空已选题库进度',
              ),
            ]
          : const [],
      // Never gate the whole page on repository.load(): the body already has
      // per-section skeletons, so swapping a full-page skeleton for the body
      // would move everything as soon as the bank cache/network resolves.
      child: repository.libraryUnavailable
          ? AppPageBody(
              maxWidth: AppLayout.resultMaxWidth,
              onRefresh: _refreshLibrary,
              child: const AppStateView(
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
    // Counts come from the resource-centre list; a zero count can render its
    // empty state immediately instead of a shorter skeleton that jumps when
    // the (taller) empty state replaces it.
    final textbookLoading =
        _detailsLoading && _textbooks.isEmpty && course.textbookCount > 0;
    final bankLoading =
        _banksLoading && banks.isEmpty && course.questionBankCount > 0;
    final resourceLoading =
        _detailsLoading && _resources.isEmpty && course.resourceCount > 0;
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      bottomPadding: AppSpacing.xxl,
      onRefresh: _refreshLibrary,
      children: [
        _buildSectionHeader(theme, 0, '教材', _expandedSections[0]),
        _buildAnimatedSection(
          expanded: _expandedSections[0],
          children: [
            if (_textbooks.isNotEmpty)
              for (final item in _textbooks) ...[
                _buildPdfTile(
                  theme,
                  _PdfEntry(
                    id: item.id,
                    title: item.name,
                    courseCode: course.code,
                    sizeBytes: item.sizeBytes,
                    hasPdf: item.hasPdf,
                    format: 'pdf',
                    fileVersion: item.fileVersion,
                    urlLoader: () => ControlService.instance.fetchTextbookURL(
                      item.id,
                      fileVersion: item.fileVersion,
                    ),
                  ),
                  color: theme.colors.destructive,
                ),
                const SizedBox(height: AppSpacing.listGap),
              ]
            else if (textbookLoading)
              _buildLoading(course.textbookCount)
            else
              _buildUploadEmpty(
                theme,
                label: '暂无资源',
                icon: FLucideIcons.bookOpen,
              ),
          ],
        ),
        _buildSectionHeader(theme, 1, '题库', _expandedSections[1]),
        _buildAnimatedSection(
          expanded: _expandedSections[1],
          children: [
            if (banks.isNotEmpty)
              for (final bank in banks) ...[
                _buildBankCard(theme, bank),
                const SizedBox(height: AppSpacing.listGap),
              ]
            else if (bankLoading)
              _buildLoading(course.questionBankCount)
            else
              _buildUploadEmpty(
                theme,
                label: '暂无题库',
                icon: FLucideIcons.fileQuestion,
              ),
          ],
        ),
        _buildSectionHeader(theme, 2, '试卷', _expandedSections[2]),
        _buildAnimatedSection(
          expanded: _expandedSections[2],
          children: [
            if (_resources.isNotEmpty)
              for (final item in _resources) ...[
                _buildPdfTile(
                  theme,
                  _PdfEntry(
                    id: item.id,
                    title: item.name,
                    courseCode: course.code,
                    sizeBytes: item.sizeBytes,
                    hasPdf: item.hasPdf,
                    format: item.format,
                    fileVersion: item.fileVersion,
                    urlLoader: () => ControlService.instance.fetchResourceURL(
                      item.id,
                      fileVersion: item.fileVersion,
                    ),
                    aiModes: item.aiModes,
                  ),
                  color: theme.colors.semantic.info,
                ),
                const SizedBox(height: AppSpacing.listGap),
              ]
            else if (resourceLoading)
              _buildLoading(course.resourceCount)
            else
              _buildUploadEmpty(
                theme,
                label: '暂无资源',
                icon: FLucideIcons.fileText,
              ),
          ],
        ),
      ],
    );
  }

  /// Animates content height changes (skeleton → rows, empty → rows, expand /
  /// collapse) so the section headers below glide instead of jumping.
  Widget _buildAnimatedSection({
    required bool expanded,
    required List<Widget> children,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                ...children,
                const SizedBox(height: AppSpacing.md),
              ],
            )
          : const SizedBox.shrink(),
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
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResourceTag(
              label: label,
              background: background,
              foreground: foreground,
            ),
            Padding(
              padding: const EdgeInsets.only(left: SwallowtailTagClipper.point),
              child: Container(
                width: double.infinity,
                height: expanded ? 2 : 1,
                color: foreground,
              ),
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
      painter: DashedBorderPainter(color: theme.colors.border),
      child: SizedBox(
        width: double.infinity,
        height: 132,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: theme.colors.mutedForeground),
              const SizedBox(height: AppSpacing.xs),
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

  /// Uses the course counts from the resource-centre list so the placeholder
  /// has roughly the final height and the content does not jump in.
  Widget _buildLoading(int expected) {
    final rows = expected <= 0 ? 1 : expected.clamp(1, 6);
    return AppSkeleton(
      label: '正在加载',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            // Real rows are followed by a 6dp gap each; match it so replacing
            // the skeleton changes no height at all.
            for (var index = 0; index < rows; index++) ...[
              const AppSkeletonBox(
                width: double.infinity,
                height: 78,
                radius: 8,
              ),
              const SizedBox(height: AppSpacing.listGap),
            ],
          ],
        ),
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
    final downloaded = _downloadedIds.contains(entry.downloadKey);
    final downloading = _downloadingIds.contains(entry.downloadKey);
    final progress = _downloadProgress[entry.downloadKey] ?? 0;
    final size = _formatFileSize(entry.sizeBytes);
    final meta = downloading
        ? (progress > 0 ? '下载中 ${(progress * 100).round()}%' : '下载中…')
        : [if (size.isNotEmpty) size, downloaded ? '已下载' : '未下载'].join('  ');
    final canOpen = entry.hasPdf && !downloading;

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Where a file lands in Downloads is prefixed with the
                  // course code, but the row shows the source file name.
                  _documentFileName(entry.title, entry.format),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.tileTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  meta,
                  style: theme.typography.bodySmall.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
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
            _DocumentIcon(color: color, label: entry.format.toUpperCase()),
        ],
      ),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FTappable(
            onPress: canOpen ? () => unawaited(_handlePdf(entry)) : null,
            behavior: HitTestBehavior.opaque,
            child: content,
          ),
          if (entry.aiModes.isNotEmpty) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colors.border.withValues(alpha: 0.6),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: _buildAIReportLinks(theme, entry),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAIReportLinks(FThemeData theme, _PdfEntry entry) {
    final modes = [
      for (final mode in const ['more', 'basic', 'manual'])
        if (entry.aiModes.contains(mode)) mode,
    ];
    return Row(
      children: [
        for (var index = 0; index < modes.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.sm),
          _buildAIReportChip(theme, entry, modes[index]),
        ],
      ],
    );
  }

  Widget _buildAIReportChip(FThemeData theme, _PdfEntry entry, String mode) {
    final key = '${entry.id}:$mode';
    final downloading = _aiDownloading.contains(key);
    final primary = theme.colors.primary;
    return FTappable(
      onPress: downloading ? null : () => unawaited(_downloadAI(entry, mode)),
      child: SizedBox(
        height: 28,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                downloading ? FLucideIcons.clock3 : FLucideIcons.download,
                size: 13,
                color: primary,
              ),
              const SizedBox(width: AppSpacing.micro),
              Text(
                downloading
                    ? '下载中'
                    : mode == 'more'
                    ? '小学生版解析'
                    : mode == 'manual'
                    ? '原版解析'
                    : '精简版解析',
                style: theme.typography.caption.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadAI(_PdfEntry entry, String mode) async {
    final key = '${entry.id}:$mode';
    if (_aiDownloading.contains(key)) return;
    setState(() => _aiDownloading.add(key));
    try {
      final result = await ControlService.instance.fetchResourceAI(
        entry.id,
        mode: mode,
      );
      final url = result.pdfUrl;
      if (url.isEmpty) throw StateError('missing AI PDF url');
      final format = result.format.isEmpty ? 'pdf' : result.format;
      final base = _documentFileName(
        entry.title,
        format,
        courseCode: entry.courseCode,
      );
      final label = mode == 'more'
          ? '小学生版'
          : mode == 'manual'
          ? '原版'
          : '精简版';
      final dot = base.lastIndexOf('.');
      final fileName =
          '${base.substring(0, dot)}-AI解析-$label${base.substring(dot)}';
      final record = await ResourceDownloadService.instance.download(
        '${entry.id}-ai-$mode',
        url,
        fileName: fileName,
        fileVersion: result.fileVersion,
        format: format,
      );
      if (record != null) {
        await ResourceDownloadService.instance.open(record, format: format);
      }
    } catch (error, stackTrace) {
      talker.warning('下载 AI 解析失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '下载失败，请稍后重试', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _aiDownloading.remove(key));
    }
  }

  Future<void> _refreshDownloadedStatuses() async {
    final items = <({String id, String format, String fileVersion})>[
      for (final item in _resources)
        (id: item.id, format: item.format, fileVersion: item.fileVersion),
      for (final item in _textbooks)
        (id: item.id, format: 'pdf', fileVersion: item.fileVersion),
    ];
    await ResourceDownloadService.instance.refresh();
    final downloaded = <String>{};
    for (final item in items) {
      if (await ResourceDownloadService.instance.isDownloaded(
        item.id,
        format: item.format,
        fileVersion: item.fileVersion,
      )) {
        downloaded.add('${item.id}:${item.fileVersion}');
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
    final key = entry.downloadKey;
    if (_downloadingIds.contains(key)) return;
    try {
      if (_downloadedIds.contains(key)) {
        final record = await ResourceDownloadService.instance.recordFor(
          entry.id,
          format: entry.format,
          fileVersion: entry.fileVersion,
        );
        if (record != null) {
          await ResourceDownloadService.instance.open(
            record,
            format: entry.format,
          );
          return;
        }
        if (mounted) setState(() => _downloadedIds.remove(key));
      }
      setState(() {
        _downloadingIds.add(key);
        _downloadProgress[key] = 0;
      });
      final url = await entry.urlLoader();
      if (url.isEmpty) throw StateError('empty url');
      final record = await ResourceDownloadService.instance.download(
        entry.id,
        url,
        fileName: _documentFileName(
          entry.title,
          entry.format,
          courseCode: entry.courseCode,
        ),
        format: entry.format,
        fileVersion: entry.fileVersion,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress[key] = total > 0 ? received / total : 0;
          });
        },
      );
      if (!mounted) return;
      if (record == null) throw StateError('save returned no uri');
      setState(() => _downloadedIds.add(key));
      showAppSnackBar(
        context,
        '已保存到 Download/${record.name}',
        severity: ToastSeverity.success,
      );
    } on ControlApiException catch (error, stackTrace) {
      talker.warning('下载资源失败', error, stackTrace);
      if (error.code == 'resource_changed') {
        await _loadCourseDetails(force: true);
      }
      if (mounted) {
        showAppSnackBar(
          context,
          error.message,
          severity: ToastSeverity.warning,
        );
      }
    } catch (error, stackTrace) {
      talker.warning('下载资源失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '下载失败，请稍后重试', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(key);
          _downloadProgress.remove(key);
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

  String _documentFileName(
    String name,
    String format, {
    String courseCode = '',
  }) {
    final normalized = switch (format.toLowerCase()) {
      'docx' => 'docx',
      'doc' => 'doc',
      _ => 'pdf',
    };
    var base = name.trim();
    final lower = base.toLowerCase();
    for (final extension in const ['.pdf', '.docx', '.doc']) {
      if (lower.endsWith(extension)) {
        base = base.substring(0, base.length - extension.length);
        break;
      }
    }
    // The name is used for the Downloads entry and the shared file, so strip
    // separators and control characters that would break either path.
    final safe = base.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    final title = safe.isEmpty ? '资料' : safe;
    final code = courseCode
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .trim();
    return '${code.isEmpty ? '' : '${code}_'}$title.$normalized';
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
          padding: const EdgeInsets.all(AppSpacing.md),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.tileTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: theme.typography.bodySmall.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _DocumentIcon(
                color: theme.colors.semantic.warning,
                label: 'EXAM',
              ),
            ],
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
      routeStyle: appDialogRouteStyle(),
      style: appDialogStyle(context),
      builder: (context, style, animation) => FDialog(
        animation: animation,
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(
          minWidth: 280,
          maxWidth: AppDialogMetrics.maxWidth,
        ),
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
  final String courseCode;
  final int sizeBytes;
  final bool hasPdf;
  final String format;
  final String fileVersion;
  final Future<String> Function() urlLoader;
  final List<String> aiModes;

  const _PdfEntry({
    required this.id,
    required this.title,
    this.courseCode = '',
    required this.sizeBytes,
    required this.hasPdf,
    required this.format,
    required this.fileVersion,
    required this.urlLoader,
    this.aiModes = const [],
  });

  String get downloadKey => '$id:$fileVersion';
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppDialogMetrics.maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppDialogHeader(
                  title: '解锁题库',
                  message: '「${widget.bankName}」需要 CDK 解锁后才能练习',
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
              ],
            ),
          ),
          const AppDialogDivider(),
          AppDialogFooter(
            cancelLabel: '取消',
            confirmLabel: _redeeming ? '兑换中...' : '兑换',
            onCancel: () => Navigator.pop(context),
            onConfirm: () {
              if (!_redeeming) unawaited(_submit());
            },
          ),
        ],
      ),
    );
  }
}
