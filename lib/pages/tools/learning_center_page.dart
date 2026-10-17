import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/learning_question.dart';
import '../../models/resource_center.dart';
import '../../services/control_service.dart';
import '../../services/learning_repository.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';
import 'learning_question_list_page.dart';
import 'learning_quiz_page.dart';

class LearningCenterPage extends StatefulWidget {
  final LearningRepository repository;

  const LearningCenterPage({super.key, required this.repository});

  @override
  State<LearningCenterPage> createState() => _LearningCenterPageState();
}

enum _LearningTab { course, wrong, favorite }

class _LearningCenterPageState extends State<LearningCenterPage> {
  LearningRepository get repository => widget.repository;

  _LearningTab _tab = _LearningTab.course;
  List<_TermGroup>? _cachedTermGroups;
  int _cachedLibraryRevision = -1;
  bool _refreshing = false;
  bool _bankSelectionMode = false;
  final Set<String> _selectedBankKeys = {};

  List<ResourceCourse> _courses = const [];
  final Map<String, List<CourseResourceItem>> _resourcesByCourse = {};
  final Map<String, List<CourseTextbookItem>> _textbooksByCourse = {};
  final Set<String> _courseDataLoaded = {};
  final Set<String> _courseDataLoading = {};
  String? _courseListError;
  bool _coursesLoading = false;

  @override
  void initState() {
    super.initState();
    repository.addListener(_onRepositoryUpdate);
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    await repository.load();
    unawaited(_loadCourses());
    if (!mounted || !repository.loadedFromCache) return;
    try {
      // Version compare happens inside sync; only changed banks are downloaded.
      await repository.sync();
    } catch (error, stackTrace) {
      talker.warning('题库同步失败', error, stackTrace);
    }
  }

  /// Loads the course entries of the resource centre. Courses are independent
  /// from the cached question banks, so a failure keeps the local fallback
  /// grouping instead of hiding the existing banks.
  Future<void> _loadCourses({bool force = false}) async {
    if (_coursesLoading) return;
    if (!force && _courses.isNotEmpty) return;
    setState(() {
      _coursesLoading = true;
      _courseListError = null;
    });
    try {
      final courses = await ControlService.instance.fetchResourceCourses();
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _resourcesByCourse.clear();
        _textbooksByCourse.clear();
        _courseDataLoaded.clear();
        _courseDataLoading.clear();
      });
    } catch (error, stackTrace) {
      talker.warning('资源中心课程加载失败', error, stackTrace);
      if (mounted) setState(() => _courseListError = '课程资源加载失败，仅显示本地题库');
    } finally {
      if (mounted) setState(() => _coursesLoading = false);
    }
  }

  void _ensureCourseData(String code) {
    if (code.isEmpty ||
        _courseDataLoaded.contains(code) ||
        _courseDataLoading.contains(code)) {
      return;
    }
    _courseDataLoading.add(code);
    unawaited(_loadCourseData(code));
  }

  Future<void> _loadCourseData(String code) async {
    try {
      final control = ControlService.instance;
      final results = await Future.wait([
        control.fetchCourseResources(code),
        control.fetchCourseTextbooks(code),
      ]);
      if (!mounted) return;
      setState(() {
        _resourcesByCourse[code] = results[0] as List<CourseResourceItem>;
        _textbooksByCourse[code] = results[1] as List<CourseTextbookItem>;
        _courseDataLoaded.add(code);
      });
    } catch (error, stackTrace) {
      talker.warning('课程资源加载失败', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _resourcesByCourse[code] = const [];
        _textbooksByCourse[code] = const [];
        _courseDataLoaded.add(code);
      });
    } finally {
      _courseDataLoading.remove(code);
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
      await _loadCourses(force: true);
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

  Future<void> _clearCurrentCollection() async {
    if (_tab == _LearningTab.course) return;
    final isWrong = _tab == _LearningTab.wrong;
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
      for (final term in _termGroups())
        for (final bank in term.banks)
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
      title: switch (_tab) {
        _LearningTab.course => '资源中心',
        _LearningTab.wrong => '错题集',
        _LearningTab.favorite => '收藏集',
      },
      actions: loading
          ? const [
              AppIconButton(
                icon: FLucideIcons.refreshCw,
                onPress: null,
                tooltip: '正在加载资源',
                loading: true,
              ),
            ]
          : _tab == _LearningTab.course
          ? _bankSelectionMode
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
                      icon: FLucideIcons.refreshCw,
                      onPress: _refreshing ? null : _refreshLibrary,
                      tooltip: '刷新资源',
                      loading: _refreshing,
                    ),
                  ]
          : [
              AppIconButton(
                icon: FLucideIcons.trash2,
                onPress: _clearCurrentCollection,
                tooltip: _tab == _LearningTab.wrong ? '清空错题集' : '清空收藏集',
              ),
            ],
      footer: _buildBottomNavigation(),
      child: loading
          ? const AppStateView(icon: FLucideIcons.library, title: '正在加载题库')
          : switch (_tab) {
              _LearningTab.course => _buildResourcePage(context),
              _LearningTab.wrong => _buildQuestionPage(
                context,
                LearningListKind.wrong,
              ),
              _LearningTab.favorite => _buildQuestionPage(
                context,
                LearningListKind.favorite,
              ),
            },
    );
  }

  Widget _buildBottomNavigation() => FBottomNavigationBar(
    index: _tab.index,
    onChange: (index) {
      if (index < 0 || index >= _LearningTab.values.length) return;
      setState(() {
        _tab = _LearningTab.values[index];
        if (_tab != _LearningTab.course) {
          _bankSelectionMode = false;
          _selectedBankKeys.clear();
        }
      });
    },
    children: const [
      FBottomNavigationBarItem(
        icon: Icon(FLucideIcons.library),
        label: Text('课程'),
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
  );

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
    final result = groups.values.toList();
    result.sort(_compareBanks);
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

  /// Groups the published banks by every course they are associated with. Banks
  /// without a course association are kept in a trailing `未关联课程` entry so
  /// they never disappear from the app.
  List<_ResourceCourseGroup> _resourceCourseGroups() {
    final banksByCourse = <String, List<_QuestionBankGroup>>{};
    for (final bank in _allBankGroups()) {
      final codes = bank.courseCodes.isEmpty ? const [''] : bank.courseCodes;
      for (final code in codes) {
        banksByCourse.putIfAbsent(code, () => []).add(bank);
      }
    }
    final result = <_ResourceCourseGroup>[];
    final seen = <String>{};
    for (final course in _courses) {
      if (course.code.isEmpty || !seen.add(course.code)) continue;
      result.add(
        _ResourceCourseGroup(
          code: course.code,
          name: course.name,
          banks: banksByCourse[course.code] ?? const [],
          resourceCount: course.resourceCount,
          textbookCount: course.textbookCount,
        ),
      );
    }
    for (final entry in banksByCourse.entries) {
      if (entry.key.isEmpty || !seen.add(entry.key)) continue;
      result.add(
        _ResourceCourseGroup(
          code: entry.key,
          name: entry.key,
          banks: entry.value,
        ),
      );
    }
    final unassociated = banksByCourse[''] ?? const <_QuestionBankGroup>[];
    if (unassociated.isNotEmpty) {
      result.add(
        _ResourceCourseGroup(code: '', name: '未关联课程', banks: unassociated),
      );
    }
    return result;
  }

  Widget _buildResourcePage(BuildContext context) {
    if (repository.libraryUnavailable) {
      return const AppPageBody(
        maxWidth: AppLayout.resultMaxWidth,
        child: AppStateView(
          icon: FLucideIcons.shieldAlert,
          title: '风险控制',
          description: '您的账户被暂时禁用',
        ),
      );
    }
    final groups = _resourceCourseGroups();
    if (groups.isEmpty) {
      return AppStateView(
        icon: FLucideIcons.library,
        title: _coursesLoading ? '正在加载资源' : '暂无资源',
        description: _courseListError ?? '暂时没有可用的题库、试卷或电子教材',
      );
    }
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      children: [
        if (_courseListError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              _courseListError!,
              style: context.theme.typography.bodySmall.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ),
        for (var index = 0; index < groups.length; index++) ...[
          _buildCourseCard(context.theme, groups[index]),
          if (index != groups.length - 1)
            const SizedBox(height: AppSpacing.section),
        ],
      ],
    );
  }

  Widget _buildCourseCard(FThemeData theme, _ResourceCourseGroup group) {
    _ensureCourseData(group.code);
    final resources = _resourcesByCourse[group.code] ?? const [];
    final textbooks = _textbooksByCourse[group.code] ?? const [];
    final loadingDetails =
        group.code.isNotEmpty && !_courseDataLoaded.contains(group.code);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name.trim().isEmpty ? group.code : group.name,
                      style: theme.typography.body.lg.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (group.code.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          group.code,
                          style: theme.typography.bodySmall.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${group.banks.length} 题库 · ${group.resourceCount} 试卷 · ${group.textbookCount} 教材',
                style: theme.typography.bodySmall.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FTabs(
            children: [
              FTabEntry(
                label: Text('题库 ${group.banks.length}'),
                child: _buildCourseBanks(theme, group),
              ),
              FTabEntry(
                label: Text('试卷 ${group.resourceCount}'),
                child: loadingDetails
                    ? _buildCourseLoading(theme)
                    : _buildCourseResources(theme, resources),
              ),
              FTabEntry(
                label: Text('电子教材 ${group.textbookCount}'),
                child: loadingDetails
                    ? _buildCourseLoading(theme)
                    : _buildCourseTextbooks(theme, textbooks),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseLoading(FThemeData theme) => const Padding(
    padding: EdgeInsets.all(AppSpacing.lg),
    child: Center(child: CircularProgressIndicator.adaptive()),
  );

  Widget _buildCourseEmpty(FThemeData theme, String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Center(
      child: Text(
        message,
        style: theme.typography.bodySmall.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
    ),
  );

  Widget _buildCourseBanks(FThemeData theme, _ResourceCourseGroup group) {
    final banks = group.banks;
    if (banks.isEmpty) return _buildCourseEmpty(theme, '该课程暂无关联题库');
    final latest = banks.where((bank) => bank.isNew == true).toList();
    final older = banks.where((bank) => bank.isNew != true).toList();
    final showHeadings = latest.isNotEmpty && older.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildCourseResources(
    FThemeData theme,
    List<CourseResourceItem> resources,
  ) {
    if (resources.isEmpty) return _buildCourseEmpty(theme, '该课程暂无试卷');
    return Column(
      children: [
        for (var index = 0; index < resources.length; index++) ...[
          FTile(
            prefix: const Icon(FLucideIcons.fileText),
            title: Text(
              resources[index].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: resources[index].tags.isEmpty
                ? null
                : Text(
                    resources[index].tags,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            suffix: const Icon(FLucideIcons.externalLink),
            onPress: resources[index].hasPdf
                ? () => unawaited(_openResource(resources[index]))
                : null,
          ),
          if (index != resources.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildCourseTextbooks(
    FThemeData theme,
    List<CourseTextbookItem> textbooks,
  ) {
    if (textbooks.isEmpty) return _buildCourseEmpty(theme, '该课程暂无电子教材');
    return Column(
      children: [
        for (var index = 0; index < textbooks.length; index++) ...[
          FTile(
            prefix: const Icon(FLucideIcons.bookOpen),
            title: Text(
              textbooks[index].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: textbooks[index].tags.isEmpty
                ? null
                : Text(
                    textbooks[index].tags,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            suffix: const Icon(FLucideIcons.externalLink),
            onPress: textbooks[index].hasPdf
                ? () => unawaited(_openTextbook(textbooks[index]))
                : null,
          ),
          if (index != textbooks.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Future<void> _openResource(CourseResourceItem item) =>
      _openSignedURL(() => ControlService.instance.fetchResourceURL(item.id));

  Future<void> _openTextbook(CourseTextbookItem item) =>
      _openSignedURL(() => ControlService.instance.fetchTextbookURL(item.id));

  Future<void> _openSignedURL(Future<String> Function() loader) async {
    try {
      final url = await loader();
      if (url.isEmpty) throw StateError('empty url');
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw StateError('launch failed');
    } catch (error, stackTrace) {
      talker.warning('打开资源失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '打开资源失败，请稍后重试', severity: ToastSeverity.error);
      }
    }
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
    final collectionDetails = switch (collectionKind) {
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
      details: collectionDetails,
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

  int _bankProgressPercent(_QuestionBankGroup bank) {
    if (bank.questions.isEmpty) return 0;
    final judged = bank.questions
        .where((q) => repository.isJudged(q.id))
        .length;
    return (judged * 100 / bank.questions.length).round();
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
    for (final term in _termGroups()) {
      for (final bank in term.banks) {
        final idMatch = id.trim().isNotEmpty && bank.id.trim() == id.trim();
        final nameMatch = bank.name == name && bank.isNew == isNew;
        if (idMatch || nameMatch) return bank;
      }
    }
    return null;
  }

  List<_TermGroup> _termGroups() {
    if (_cachedTermGroups != null &&
        _cachedLibraryRevision == repository.libraryRevision) {
      return _cachedTermGroups!;
    }
    final banks = <String, _QuestionBankGroup>{};
    for (final source in repository.banks) {
      final key = source.id.trim().isNotEmpty
          ? source.id.trim()
          : '${source.name}\u0000${source.isNew == true ? 'new' : 'old'}';
      banks[key] = _QuestionBankGroup(
        id: source.id,
        name: source.name,
        orderId: source.orderId,
        isNew: source.isNew,
        requiresCDK: source.requiresCDK,
        locked: source.locked,
        questions: source.questions,
      );
    }
    if (banks.isEmpty) {
      for (final question in repository.questions) {
        final key = _bankKey(question);
        final bank = banks.putIfAbsent(
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

    final terms = <String, _TermGroup>{};
    for (final bank in banks.values) {
      final code = bank.isNew == true ? '最新题库' : '往年题库';
      terms.putIfAbsent(code, () => _TermGroup(code)).banks.add(bank);
    }
    final result = terms.values.toList()
      ..sort(
        (a, b) => a.code == '最新题库'
            ? -1
            : b.code == '最新题库'
            ? 1
            : 0,
      );
    for (final term in result) {
      term.banks.sort((a, b) {
        final aOrder = a.orderId;
        final bOrder = b.orderId;
        if (aOrder != null && bOrder != null && aOrder != bOrder) {
          return aOrder.compareTo(bOrder);
        }
        if (aOrder != null && bOrder == null) return -1;
        if (aOrder == null && bOrder != null) return 1;
        return a.name.compareTo(b.name);
      });
    }
    _cachedLibraryRevision = repository.libraryRevision;
    _cachedTermGroups = result;
    return result;
  }

  String _bankKey(LearningQuestion question) {
    final bankId = question.bankId.trim();
    return bankId.isEmpty
        ? '${question.bankName}\u0000${question.bankIsNew == true ? 'new' : 'old'}'
        : bankId;
  }

  Widget _buildBankSections(
    FThemeData theme,
    Map<String, List<_QuestionBankGroup>> sections, {
    bool showSectionHeadings = true,
    LearningListKind? collectionKind,
  }) {
    final entries = sections.entries.toList();
    final displayHeadings = showSectionHeadings && entries.length > 1;
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          if (displayHeadings)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                0,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Text(
                entries[index].key,
                style: theme.typography.body.lg.copyWith(
                  color: theme.colors.foreground,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          for (
            var bankIndex = 0;
            bankIndex < entries[index].value.length;
            bankIndex++
          ) ...[
            _buildBankTile(
              theme,
              entries[index].value[bankIndex],
              collectionKind: collectionKind,
            ),
            if (bankIndex != entries[index].value.length - 1)
              const SizedBox(height: AppSpacing.md),
          ],
          if (index != entries.length - 1)
            const SizedBox(height: AppSpacing.section),
        ],
      ],
    );
  }

  Widget _buildQuestionPage(BuildContext context, LearningListKind kind) {
    final groups = _groupedQuestions(kind);
    final sections = <String, List<_QuestionBankGroup>>{'': groups};
    final emptyIcon = kind == LearningListKind.wrong
        ? FLucideIcons.circleAlert
        : FLucideIcons.bookmark;
    return groups.isEmpty
        ? AppStateView(
            icon: emptyIcon,
            title: '这里还没有题目',
            description: kind == LearningListKind.wrong
                ? '完成题目后，答错的题目会显示在这里'
                : '收藏题目后会显示在这里',
          )
        : _buildBankSections(
            context.theme,
            sections,
            showSectionHeadings: false,
            collectionKind: kind,
          );
  }

  List<LearningQuestion> _filteredQuestions(LearningListKind kind) {
    return [
      for (final question in repository.questions)
        if (kind == LearningListKind.wrong
            ? repository.wrongIds.contains(question.id)
            : repository.favoriteIds.contains(question.id))
          question,
    ];
  }

  List<_QuestionBankGroup> _groupedQuestions(LearningListKind kind) {
    final groups = <String, _QuestionBankGroup>{};
    for (final question in _filteredQuestions(kind)) {
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
    return groups.values.toList()..sort((a, b) {
      final aIsNew = a.isNew == true;
      final bIsNew = b.isNew == true;
      if (aIsNew != bIsNew) return aIsNew ? -1 : 1;
      final aOrder = a.orderId;
      final bOrder = b.orderId;
      if (aOrder != null && bOrder != null && aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }
      if (aOrder != null && bOrder == null) return -1;
      if (aOrder == null && bOrder != null) return 1;
      return a.name.compareTo(b.name);
    });
  }

  Future<void> _openQuestions(
    List<LearningQuestion> questions, {
    int initialIndex = 0,
    String pageTitle = '题库',
    LearningQuizMode mode = LearningQuizMode.normal,
    bool retryIncorrect = false,
    bool lockMode = false,
  }) async {
    if (questions.isEmpty) return;
    final questionIds = [for (final question in questions) question.id];
    if (retryIncorrect) {
      // Wrong-question practice is a retry flow. Clear only the judged state
      // and answer draft; the repository deliberately keeps wrongIds until a
      // subsequent correct submission removes the question.
      await repository.resetProgress(questionIds);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.learningQuiz,
        builder: (_) => LearningQuizPage(
          repository: repository,
          questionIds: questionIds,
          initialIndex: initialIndex,
          pageTitle: pageTitle,
          mode: mode,
          lockMode: lockMode,
        ),
      ),
    );
  }
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
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: outerColor,
      border: Border.all(color: outerColor, width: 2),
    ),
    padding: const EdgeInsets.all(3),
    child: DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: innerColor),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.typography.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
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
      color: theme.colors.primary,
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

class _TermGroup {
  final String code;
  final List<_QuestionBankGroup> banks = [];

  _TermGroup(this.code);
}

class _ResourceCourseGroup {
  final String code;
  final String name;
  final List<_QuestionBankGroup> banks;
  final int resourceCount;
  final int textbookCount;

  const _ResourceCourseGroup({
    required this.code,
    required this.name,
    required this.banks,
    this.resourceCount = 0,
    this.textbookCount = 0,
  });
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
