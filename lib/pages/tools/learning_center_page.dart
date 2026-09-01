import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/learning_question.dart';
import '../../services/learning_repository.dart';
import '../../ui/app_components.dart';
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

  Widget _buildBankPage(BuildContext context) {
    final theme = context.theme;
    final terms = _termGroups(repository.questions);
    return terms.isEmpty
        ? const AppStateView(
            icon: FLucideIcons.library,
            title: '题库为空',
            description: '暂时没有可练习的题目',
          )
        : AppPageListView(
            maxWidth: AppLayout.resultMaxWidth,
            topPadding: AppSpacing.lg,
            bottomPadding: AppSpacing.xxl,
            children: [
              for (
                var termIndex = 0;
                termIndex < terms.length;
                termIndex++
              ) ...[
                Text(
                  terms[termIndex].code,
                  style: theme.typography.sectionTitle,
                ),
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

  Widget _buildBankCard(FThemeData theme, _QuestionBankGroup bank) {
    final name = bank.name.trim().isEmpty ? '题库' : bank.name.trim();
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onPress: () => _openQuestions(bank.questions, pageTitle: name),
      child: Row(
        children: [
          Container(
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(name, style: theme.typography.tileTitle)),
        ],
      ),
    );
  }

  List<_TermGroup> _termGroups(List<LearningQuestion> questions) {
    final banks = <String, _QuestionBankGroup>{};
    for (final question in questions) {
      final key = '${question.bankName}\u0000${question.year}';
      final bank = banks.putIfAbsent(
        key,
        () => _QuestionBankGroup(name: question.bankName, year: question.year),
      );
      bank.questions.add(question);
    }

    final terms = <String, _TermGroup>{};
    for (final bank in banks.values) {
      final code = _termCode(bank.year);
      terms.putIfAbsent(code, () => _TermGroup(code)).banks.add(bank);
    }
    final result = terms.values.toList()
      ..sort((a, b) => b.code.compareTo(a.code));
    for (final term in result) {
      term.banks.sort((a, b) => a.name.compareTo(b.name));
    }
    return result;
  }

  String _termCode(int year) {
    if (year >= 2000 && year <= 2099) {
      return '${(year % 100).toString().padLeft(2, '0')}01';
    }
    return year.toString();
  }

  Widget _buildQuestionPage(BuildContext context, LearningListKind kind) {
    final theme = context.theme;
    final groups = _groupedQuestions(kind);
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
                var groupIndex = 0;
                groupIndex < groups.length;
                groupIndex++
              ) ...[
                Text(
                  groups[groupIndex].title,
                  style: theme.typography.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.md),
                for (
                  var index = 0;
                  index < groups[groupIndex].questions.length;
                  index++
                ) ...[
                  _buildQuestionCard(
                    theme,
                    groups[groupIndex].questions,
                    groups[groupIndex].questions[index],
                    index,
                    kind == LearningListKind.wrong ? '错题集' : '收藏集',
                  ),
                  if (index != groups[groupIndex].questions.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
                if (groupIndex != groups.length - 1)
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
      final key = '${question.bankName}\u0000${question.year}';
      final group = groups.putIfAbsent(
        key,
        () => _QuestionBankGroup(name: question.bankName, year: question.year),
      );
      group.questions.add(question);
    }
    return groups.values.toList()..sort((a, b) {
      final year = b.year.compareTo(a.year);
      if (year != 0) return year;
      return a.name.compareTo(b.name);
    });
  }

  Widget _buildQuestionCard(
    FThemeData theme,
    List<LearningQuestion> questions,
    LearningQuestion question,
    int index,
    String pageTitle,
  ) {
    final judged = repository.isJudged(question.id);
    final correct = judged && repository.isCorrect(question.id);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onPress: () =>
          _openQuestions(questions, initialIndex: index, pageTitle: pageTitle),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question.title != question.questionText)
                  Text(
                    question.title,
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  question.questionText,
                  style: theme.typography.tileTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  question.typeLabel,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            judged && correct
                ? FLucideIcons.circleCheck
                : FLucideIcons.chevronRight,
            color: judged && correct
                ? theme.colors.semantic.success
                : theme.colors.mutedForeground,
          ),
        ],
      ),
    );
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
  final String name;
  final int year;
  final List<LearningQuestion> questions = [];

  _QuestionBankGroup({required this.name, required this.year});

  String get termCode => year >= 2000 && year <= 2099
      ? '${(year % 100).toString().padLeft(2, '0')}01'
      : year.toString();

  String get title => name == '题库' ? termCode : '$termCode · $name';
}

class _TermGroup {
  final String code;
  final List<_QuestionBankGroup> banks = [];

  _TermGroup(this.code);
}
