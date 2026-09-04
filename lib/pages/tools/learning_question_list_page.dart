import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/learning_question.dart';
import '../../services/learning_repository.dart';
import '../../ui/app_components.dart';
import 'learning_quiz_page.dart';

enum LearningListKind { bank, wrong, favorite }

class LearningQuestionListPage extends StatefulWidget {
  final LearningRepository repository;
  final LearningListKind kind;

  const LearningQuestionListPage({
    super.key,
    required this.repository,
    required this.kind,
  });

  @override
  State<LearningQuestionListPage> createState() =>
      _LearningQuestionListPageState();
}

class _LearningQuestionListPageState extends State<LearningQuestionListPage> {
  LearningRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    repository.addListener(_onRepositoryUpdate);
  }

  @override
  void dispose() {
    repository.removeListener(_onRepositoryUpdate);
    super.dispose();
  }

  void _onRepositoryUpdate() {
    if (mounted) setState(() {});
  }

  List<LearningQuestion> get _questions {
    final questions = switch (widget.kind) {
      LearningListKind.bank => repository.questions,
      LearningListKind.wrong => [
        for (final question in repository.questions)
          if (repository.wrongIds.contains(question.id)) question,
      ],
      LearningListKind.favorite => [
        for (final question in repository.questions)
          if (repository.favoriteIds.contains(question.id)) question,
      ],
    };
    return questions;
  }

  List<_QuestionBankGroup> get _groupedQuestions {
    final groups = <String, _QuestionBankGroup>{};
    for (final question in _questions) {
      final bankId = question.bankId.trim();
      final key = bankId.isEmpty
          ? '${question.bankName}\u0000${question.bankIsNew == true ? 'new' : 'old'}'
          : bankId;
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

  String get _title => switch (widget.kind) {
    LearningListKind.bank => '题库',
    LearningListKind.wrong => '错题集',
    LearningListKind.favorite => '收藏集',
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final questions = _questions;
    final groups = _groupedQuestions;
    return AppPage(
      title: _title,
      actions: [
        AppIconButton(
          icon: FLucideIcons.trash2,
          onPress: _clearData,
          tooltip: widget.kind == LearningListKind.wrong
              ? '清空错题集'
              : widget.kind == LearningListKind.favorite
              ? '清空收藏集'
              : '清空做题数据',
        ),
        AppIconButton(
          icon: FLucideIcons.settings,
          onPress: _openModeSettings,
          tooltip: '刷题设置',
        ),
      ],
      child: questions.isEmpty
          ? AppStateView(
              icon: switch (widget.kind) {
                LearningListKind.bank => FLucideIcons.library,
                LearningListKind.wrong => FLucideIcons.circleCheck,
                LearningListKind.favorite => FLucideIcons.bookmark,
              },
              title: widget.kind == LearningListKind.bank ? '题库为空' : '这里还没有题目',
              description: widget.kind == LearningListKind.bank
                  ? '暂时没有可练习的题目'
                  : '完成题目或收藏题目后会显示在这里',
            )
          : AppPageListView(
              maxWidth: AppLayout.resultMaxWidth,
              topPadding: AppSpacing.lg,
              bottomPadding: AppSpacing.xxl,
              children: [
                Text(
                  '${questions.length} 道题目',
                  style: theme.typography.bodySmall.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (
                  var groupIndex = 0;
                  groupIndex < groups.length;
                  groupIndex++
                ) ...[
                  if (groups.length > 1) ...[
                    Text(
                      groups[groupIndex].title,
                      style: theme.typography.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
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
                      groups[groupIndex].name,
                    ),
                    if (index != groups[groupIndex].questions.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                  if (groupIndex != groups.length - 1)
                    const SizedBox(height: AppSpacing.xl),
                ],
              ],
            ),
    );
  }

  Future<void> _clearData() async {
    final questions = _questions;
    if (questions.isEmpty) return;
    final collection = switch (widget.kind) {
      LearningListKind.bank => '做题数据',
      LearningListKind.wrong => '错题集',
      LearningListKind.favorite => '收藏集',
    };
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '清空$collection',
      message: widget.kind == LearningListKind.bank
          ? '将清空当前题单的答题进度，错题集和收藏集会保留。'
          : '确定清空全部$collection吗？',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed) return;
    switch (widget.kind) {
      case LearningListKind.bank:
        await repository.resetProgress(
          questions.map((question) => question.id),
        );
      case LearningListKind.wrong:
        await repository.clearWrongQuestions();
      case LearningListKind.favorite:
        await repository.clearFavorites();
    }
  }

  Future<void> _openModeSettings() async {
    final mode = await showAppSheet<LearningQuizMode>(
      context: context,
      builder: (context) => const AppOptionSheet<LearningQuizMode>(
        title: '刷题模式',
        value: LearningQuizMode.normal,
        options: [
          AppOption(
            value: LearningQuizMode.normal,
            title: '顺序刷题',
            icon: FLucideIcons.listOrdered,
          ),
          AppOption(
            value: LearningQuizMode.random,
            title: '随机刷题',
            icon: FLucideIcons.shuffle,
          ),
          AppOption(
            value: LearningQuizMode.memorize,
            title: '背题模式',
            icon: FLucideIcons.bookOpen,
          ),
          AppOption(
            value: LearningQuizMode.memorizeFlow,
            title: '背题模式·流水',
            icon: FLucideIcons.rows3,
          ),
        ],
      ),
    );
    if (mode != null) _openMode(mode);
  }

  void _openMode(LearningQuizMode mode) {
    final questions = _questions;
    if (questions.isEmpty) return;
    Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.learningQuiz,
        builder: (_) => LearningQuizPage(
          repository: repository,
          questionIds: [for (final question in questions) question.id],
          pageTitle: _title,
          mode: mode,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    FThemeData theme,
    List<LearningQuestion> questionSet,
    LearningQuestion question,
    int index,
    String pageTitle,
  ) {
    final judged = repository.isJudged(question.id);
    final correct = judged && repository.isCorrect(question.id);
    final markerColor = judged
        ? correct
              ? theme.colors.semantic.success
              : theme.colors.destructive
        : theme.colors.mutedForeground;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onPress: () => Navigator.of(context).push(
        appRoute(
          name: AppRouteNames.learningQuiz,
          builder: (_) => LearningQuizPage(
            repository: repository,
            questionIds: [for (final item in questionSet) item.id],
            initialIndex: index,
            pageTitle: pageTitle,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.kind == LearningListKind.wrong ? '[错题] ' : ''}${question.questionNumber ?? index + 1}.${question.questionText}',
                  style: theme.typography.bodySmall.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _buildTag(theme, question.typeLabel, theme.colors.muted),
                    if (judged) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _buildTag(
                        theme,
                        correct ? '已答对' : '待复习',
                        correct
                            ? theme.colors.semantic.successContainer
                            : theme.colors.semantic.warningContainer,
                        textColor: correct
                            ? theme.colors.semantic.onSuccessContainer
                            : theme.colors.semantic.onWarningContainer,
                      ),
                    ],
                    if (repository.isFavorite(question.id)) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        FLucideIcons.bookmark,
                        size: 16,
                        color: theme.colors.primary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(FLucideIcons.chevronRight, color: markerColor),
        ],
      ),
    );
  }

  Widget _buildTag(
    FThemeData theme,
    String text,
    Color background, {
    Color? textColor,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: theme.typography.caption.copyWith(
        color: textColor ?? theme.colors.mutedForeground,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _QuestionBankGroup {
  final String id;
  final String name;
  final int? orderId;
  final bool? isNew;
  final List<LearningQuestion> questions = [];

  _QuestionBankGroup({
    required this.id,
    required this.name,
    required this.orderId,
    required this.isNew,
  });

  String get title => isNew == true ? '最新题库' : '往年题库';
}
