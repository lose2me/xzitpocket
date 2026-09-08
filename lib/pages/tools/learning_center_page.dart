import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/learning_question.dart';
import '../../services/control_service.dart';
import '../../services/learning_repository.dart';
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

enum _LearningTab { bank, wrong, favorite }

class _LearningCenterPageState extends State<LearningCenterPage> {
  LearningRepository get repository => widget.repository;

  _LearningTab _tab = _LearningTab.bank;
  List<_TermGroup>? _cachedTermGroups;
  int _cachedLibraryRevision = -1;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    repository.addListener(_onRepositoryUpdate);
    unawaited(
      repository.load().then((_) {
        if (!mounted) return;
        setState(() {});
        if (repository.loadedFromCache) {
          unawaited(_refreshLibrary(showToast: false));
        }
      }),
    );
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
      if (mounted && showToast) {
        showAppSnackBar(
          context,
          '题库已刷新',
          severity: ToastSeverity.success,
          showAboveNavBar: true,
        );
      }
    } on ControlApiException catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          error.message,
          severity: ToastSeverity.error,
          showAboveNavBar: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          '刷新题库失败，请稍后重试',
          severity: ToastSeverity.error,
          showAboveNavBar: true,
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _clearCurrentCollection() async {
    if (_tab == _LearningTab.bank) return;
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

  @override
  Widget build(BuildContext context) {
    final loading = !repository.isLoaded;
    return AppPage(
      title: switch (_tab) {
        _LearningTab.bank => '题库',
        _LearningTab.wrong => '错题集',
        _LearningTab.favorite => '收藏集',
      },
      actions: loading
          ? const []
          : _tab == _LearningTab.bank
          ? [
              AppIconButton(
                icon: FLucideIcons.refreshCw,
                onPress: _refreshing ? null : _refreshLibrary,
                tooltip: '刷新题库',
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
          ? const Center(
              child: FCircularProgress(size: FCircularProgressSizeVariant.md),
            )
          : switch (_tab) {
              _LearningTab.bank => _buildBankPage(context),
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
      setState(() => _tab = _LearningTab.values[index]);
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
  );

  Widget _buildBankPage(BuildContext context) {
    if (repository.libraryUnavailable) {
      return const AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          AppStateView(
            icon: FLucideIcons.shieldAlert,
            title: '风险控制',
            description: '您的账户被暂时禁用',
          ),
        ],
      );
    }
    final terms = _termGroups();
    if (terms.isEmpty) {
      return const AppStateView(
        icon: FLucideIcons.library,
        title: '题库为空',
        description: '暂时没有可练习的题目',
      );
    }
    return _buildBankSections(context.theme, {
      for (final term in terms) term.code: term.banks,
    });
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

  FTile _buildBankTile(
    FThemeData theme,
    _QuestionBankGroup bank, {
    LearningListKind? collectionKind,
  }) {
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
      _ => null,
    };

    return FTile(
      style: FItemStyleDelta.delta(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        backgroundColor: FVariantsValueDelta.delta([
          FVariantValueDeltaOperation.base(Colors.transparent),
        ]),
        contentDecoration: FVariantsDelta.delta([
          FVariantOperation.all(
            DecorationDelta.value(
              ShapeDecoration(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(color: theme.colors.border),
                ),
              ),
            ),
          ),
        ]),
        contentStyle: FItemContentStyleDelta.delta(
          suffixedPadding: const EdgeInsetsGeometryDelta.value(
            EdgeInsetsDirectional.fromSTEB(4, 2, 12, 2),
          ),
          unsuffixedPadding: const EdgeInsetsGeometryDelta.value(
            EdgeInsetsDirectional.fromSTEB(4, 2, 12, 2),
          ),
          prefixIconSpacing: 8,
        ),
      ),
      prefix: _BankInitial(
        initial: _bankInitial(name),
        outerColor: theme.colors.primary,
        innerColor: theme.colors.secondary,
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
      details:
          collectionDetails ??
          (needsCdk
              ? _CdkBadge(
                  theme: theme,
                  label: 'CDK',
                  foreground: theme.colors.semantic.onWarningContainer,
                  background: theme.colors.semantic.warningContainer,
                )
              : unlockedWithCdk
              ? _CdkBadge(
                  theme: theme,
                  label: '已解锁',
                  foreground: theme.colors.semantic.onSuccessContainer,
                  background: theme.colors.semantic.successContainer,
                )
              : null),
      onPress: onPress,
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

  static String _bankInitial(String name) {
    final match = RegExp(r'[一-龥]').firstMatch(name);
    if (match != null) return match.group(0)!;
    final first = name.runes.firstOrNull;
    return first == null ? '题' : String.fromCharCode(first);
  }

  Future<void> _openCdkRedeem(_QuestionBankGroup bank) async {
    final name = bank.name.trim().isEmpty ? '题库' : bank.name.trim();
    if (!repository.canRedeemCdk || bank.id.trim().isEmpty) {
      showAppSnackBar(
        context,
        '此题库需要 CDK 解锁',
        severity: ToastSeverity.warning,
        showAboveNavBar: true,
      );
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
    showAppSnackBar(
      context,
      '题库兑换成功',
      severity: ToastSeverity.success,
      showAboveNavBar: true,
    );
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

  Widget _buildQuestionPage(BuildContext context, LearningListKind kind) {
    final groups = _groupedQuestions(kind);
    final sections = <String, List<_QuestionBankGroup>>{'': groups};
    final emptyIcon = kind == LearningListKind.wrong
        ? FLucideIcons.circleCheck
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
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, color: outerColor),
    padding: const EdgeInsets.all(2),
    child: DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: innerColor),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: outerColor,
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
  final List<LearningQuestion> questions;

  _QuestionBankGroup({
    required this.id,
    required this.name,
    required this.orderId,
    required this.isNew,
    this.requiresCDK = false,
    this.locked = false,
    List<LearningQuestion>? questions,
  }) : questions = questions ?? [];
}

class _TermGroup {
  final String code;
  final List<_QuestionBankGroup> banks = [];

  _TermGroup(this.code);
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
      showAppSnackBar(
        context,
        '请输入 CDK',
        severity: ToastSeverity.warning,
        showAboveNavBar: true,
      );
      return;
    }
    setState(() => _redeeming = true);
    try {
      await widget.onRedeem(code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ControlApiException catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        error.message,
        severity: ToastSeverity.error,
        showAboveNavBar: true,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        '题库兑换失败，请稍后重试',
        severity: ToastSeverity.error,
        showAboveNavBar: true,
      );
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
