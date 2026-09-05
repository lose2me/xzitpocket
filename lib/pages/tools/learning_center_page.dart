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
  bool _redeeming = false;
  final _cdkController = TextEditingController();
  String? _selectedCdkBankId;

  @override
  void initState() {
    super.initState();
    repository.addListener(_onRepositoryUpdate);
    unawaited(
      repository.load().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    repository.removeListener(_onRepositoryUpdate);
    _cdkController.dispose();
    super.dispose();
  }

  void _onRepositoryUpdate() {
    if (mounted) setState(() {});
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
      actions: !loading && _tab != _LearningTab.bank
          ? [
              AppIconButton(
                icon: FLucideIcons.trash2,
                onPress: _clearCurrentCollection,
                tooltip: _tab == _LearningTab.wrong ? '清空错题集' : '清空收藏集',
              ),
            ]
          : const [],
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

  Future<void> _redeemCdk() async {
    final code = _cdkController.text.trim();
    if (code.isEmpty) {
      showAppSnackBar(context, '请输入 CDK', severity: ToastSeverity.warning);
      return;
    }
    final bankId = _selectedCdkBankId;
    if (bankId == null || bankId.isEmpty) {
      showAppSnackBar(context, '请选择要解锁的题库', severity: ToastSeverity.warning);
      return;
    }
    setState(() => _redeeming = true);
    try {
      await repository.redeemCdk(code, bankId);
      if (!mounted) return;
      _cdkController.clear();
      showAppSnackBar(context, '题库兑换成功', severity: ToastSeverity.success);
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

  Widget _buildBankPage(BuildContext context) {
    final theme = context.theme;
    final terms = _termGroups();
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
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      children: [
        if (repository.canRedeemCdk) ...[
          _buildCdkRedeemCard(theme),
          if (terms.isNotEmpty) const SizedBox(height: AppSpacing.xl),
        ],
        if (terms.isEmpty)
          const AppStateView(
            icon: FLucideIcons.library,
            title: '题库为空',
            description: '暂时没有可练习的题目',
          )
        else
          for (var termIndex = 0; termIndex < terms.length; termIndex++) ...[
            Text(terms[termIndex].code, style: theme.typography.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            for (
              var bankIndex = 0;
              bankIndex < terms[termIndex].banks.length;
              bankIndex++
            ) ...[
              _buildBankCard(theme, terms[termIndex].banks[bankIndex]),
              if (bankIndex != terms[termIndex].banks.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
            if (termIndex != terms.length - 1)
              const SizedBox(height: AppSpacing.xl),
          ],
      ],
    );
  }

  Widget _buildCdkRedeemCard(FThemeData theme) => AppCard(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(FLucideIcons.keyRound, color: theme.colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text('兑换通用 CDK', style: theme.typography.tileTitle),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildCdkBankSelector(theme),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _cdkController,
          label: '通用 CDK',
          hint: '输入兑换码以解锁需要 CDK 的题库',
          prefix: const Icon(FLucideIcons.keyRound),
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _redeeming ? null : _redeemCdk(),
          clearable: true,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FButton(
            variant: FButtonVariant.primary,
            onPress: _redeeming ? null : _redeemCdk,
            prefix: const Icon(FLucideIcons.unlock),
            child: Text(_redeeming ? '兑换中...' : '兑换 CDK'),
          ),
        ),
      ],
    ),
  );

  Widget _buildCdkBankSelector(FThemeData theme) {
    final banks = repository.banks.where((bank) => bank.requiresCDK).toList();
    if (banks.isEmpty) {
      return Text(
        '当前没有需要 CDK 的题库',
        style: theme.typography.bodySmall.copyWith(
          color: theme.colors.mutedForeground,
        ),
      );
    }
    final selected = banks.any((bank) => bank.id == _selectedCdkBankId)
        ? _selectedCdkBankId
        : banks.first.id;
    if (_selectedCdkBankId != selected) _selectedCdkBankId = selected;
    return SizedBox(
      width: double.infinity,
      child: FSelect<String>.rich(
        control: FSelectControl.lifted(
          value: selected,
          onChange: (value) {
            if (value != null && mounted) {
              setState(() => _selectedCdkBankId = value);
            }
          },
        ),
        format: (value) => banks.firstWhere((bank) => bank.id == value).name,
        children: [
          for (final bank in banks)
            FSelectItem.item(title: Text(bank.name), value: bank.id),
        ],
      ),
    );
  }

  Widget _buildBankCard(
    FThemeData theme,
    _QuestionBankGroup bank, {
    LearningListKind? collectionKind,
  }) {
    final name = bank.name.trim().isEmpty ? '题库' : bank.name.trim();
    final allQuestions = collectionKind == null
        ? bank.questions
        : repository.questions.where((question) {
            final bankId = question.bankId.trim();
            final targetId = bank.id.trim();
            return targetId.isNotEmpty
                ? bankId == targetId
                : question.bankName == bank.name &&
                      question.bankIsNew == bank.isNew;
          }).toList();
    final completed = allQuestions
        .where((question) => repository.isJudged(question.id))
        .length;
    final progress = allQuestions.isEmpty
        ? 0
        : (completed / allQuestions.length * 100).round();
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onPress: bank.locked || bank.questions.isEmpty
          ? null
          : () => _openQuestions(bank.questions, pageTitle: name),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(theme.colors.primary, Colors.black, 0.18),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colors.secondary,
                shape: BoxShape.circle,
              ),
              child: Text(
                name.characters.first,
                style: theme.typography.tileTitle.copyWith(
                  color: theme.colors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodyText.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (bank.locked)
                      Text(
                        '需要 CDK 解锁',
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.semantic.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (bank.questions.isEmpty)
                      Text(
                        '暂无题目',
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      )
                    else if (collectionKind == LearningListKind.wrong)
                      Text(
                        '剩余 ${bank.questions.length} 道错题',
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.destructive,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        '$progress%',
                        style: theme.typography.bodySmall.copyWith(
                          color: theme.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_TermGroup> _termGroups() {
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
        questions: [...source.questions],
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
    return result;
  }

  String _bankKey(LearningQuestion question) {
    final bankId = question.bankId.trim();
    return bankId.isEmpty
        ? '${question.bankName}\u0000${question.bankIsNew == true ? 'new' : 'old'}'
        : bankId;
  }

  Widget _buildQuestionPage(BuildContext context, LearningListKind kind) {
    final theme = context.theme;
    final groups = _groupedQuestions(kind);
    final sections = <String, List<_QuestionBankGroup>>{};
    for (final group in groups) {
      final section = group.isNew == true ? '最新题库' : '往年题库';
      sections.putIfAbsent(section, () => []).add(group);
    }
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
        : AppPageListView(
            maxWidth: AppLayout.resultMaxWidth,
            topPadding: AppSpacing.lg,
            bottomPadding: AppSpacing.xxl,
            children: [
              for (
                var sectionIndex = 0;
                sectionIndex < sections.length;
                sectionIndex++
              ) ...[
                Text(
                  sections.keys.elementAt(sectionIndex),
                  style: theme.typography.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.md),
                for (
                  var groupIndex = 0;
                  groupIndex < sections.values.elementAt(sectionIndex).length;
                  groupIndex++
                ) ...[
                  _buildBankCard(
                    theme,
                    sections.values.elementAt(sectionIndex)[groupIndex],
                    collectionKind: kind,
                  ),
                  if (groupIndex !=
                      sections.values.elementAt(sectionIndex).length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
                if (sectionIndex != sections.length - 1)
                  const SizedBox(height: AppSpacing.xl),
              ],
            ],
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

  void _openQuestions(
    List<LearningQuestion> questions, {
    int initialIndex = 0,
    String pageTitle = '题库',
  }) {
    if (questions.isEmpty) return;
    Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.learningQuiz,
        builder: (_) => LearningQuizPage(
          repository: repository,
          questionIds: [for (final question in questions) question.id],
          initialIndex: initialIndex,
          pageTitle: pageTitle,
        ),
      ),
    );
  }
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

  String get title => isNew == true ? '最新题库' : '往年题库';
}

class _TermGroup {
  final String code;
  final List<_QuestionBankGroup> banks = [];

  _TermGroup(this.code);
}
