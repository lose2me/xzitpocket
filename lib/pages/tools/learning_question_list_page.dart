import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';

import '../../models/learning_question.dart';
import '../../services/learning_repository.dart';
import '../../services/talker.dart';
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
    if (!repository.isLoaded) unawaited(_ensureRepository());
  }

  Future<void> _ensureRepository() async {
    try {
      await repository.load();
      if (repository.loadedFromCache) await repository.sync();
    } catch (error, stackTrace) {
      talker.warning('题库同步失败', error, stackTrace);
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
      final key = bankId.isEmpty ? question.bankName : bankId;
      final group = groups.putIfAbsent(
        key,
        () => _QuestionBankGroup(id: question.bankId, name: question.bankName),
      );
      group.questions.add(question);
    }
    return groups.values.toList()..sort((a, b) {
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
    final rows = _buildRows(groups);
    return AppPage(
      title: _title,
      actions: [
        if (widget.kind != LearningListKind.bank)
          AppIconButton(
            icon: FLucideIcons.trash2,
            onPress: _clearData,
            tooltip: widget.kind == LearningListKind.wrong ? '清空错题集' : '清空收藏集',
          ),
        AppIconButton(
          icon: FLucideIcons.settings,
          onPress: _openModeSettings,
          tooltip: '刷题设置',
        ),
      ],
      child: !repository.isLoaded
          ? _buildSkeleton()
          : questions.isEmpty
          ? AppStateView(
              icon: switch (widget.kind) {
                LearningListKind.bank => FLucideIcons.fileQuestion,
                LearningListKind.wrong => FLucideIcons.circleAlert,
                LearningListKind.favorite => FLucideIcons.bookmark,
              },
              title: widget.kind == LearningListKind.bank ? '题库为空' : '这里还没有题目',
              description: widget.kind == LearningListKind.bank
                  ? '暂时没有可练习的题目'
                  : '完成题目或收藏题目后会显示在这里',
            )
          : AppPageListViewBuilder(
              maxWidth: AppLayout.resultMaxWidth,
              bottomPadding: AppSpacing.xxl,
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return switch (row.type) {
                  _QuestionRowType.count => Text(
                    '${questions.length} 道题目',
                    style: theme.typography.bodySmall.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  _QuestionRowType.heading => Text(
                    row.heading!,
                    style: theme.typography.sectionTitle,
                  ),
                  _QuestionRowType.card => _buildQuestionCard(
                    theme,
                    row.group!.questions,
                    row.group!.questions[row.questionIndex!],
                    row.questionIndex!,
                    row.group!.name,
                  ),
                  _QuestionRowType.spacer => SizedBox(height: row.height),
                };
              },
            ),
    );
  }

  List<_QuestionListRow> _buildRows(List<_QuestionBankGroup> groups) {
    final rows = <_QuestionListRow>[
      if (widget.kind == LearningListKind.bank) ...[
        const _QuestionListRow.count(),
        const _QuestionListRow.spacer(AppSpacing.sm),
      ],
    ];
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      if (groups.length > 1) {
        rows.add(_QuestionListRow.heading(group.title));
        rows.add(const _QuestionListRow.spacer(AppSpacing.md));
      }
      for (var index = 0; index < group.questions.length; index++) {
        rows.add(_QuestionListRow.card(group, index));
        if (index != group.questions.length - 1) {
          rows.add(const _QuestionListRow.spacer(AppSpacing.listGap));
        }
      }
      if (groupIndex != groups.length - 1) {
        rows.add(const _QuestionListRow.spacer(AppSpacing.xl));
      }
    }
    return rows;
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
      title: '清空$collection？',
      message: widget.kind == LearningListKind.bank
          ? '当前题单的答题进度将被清空，错题集和收藏集保留。'
          : '全部$collection将被删除，无法恢复。',
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

  Widget _buildSkeleton() => AppPageListView(
    maxWidth: AppLayout.resultMaxWidth,
    bottomPadding: AppSpacing.xxl,
    children: [
      AppSkeleton(
        label: '正在加载题目',
        child: Column(
          children: [
            for (var index = 0; index < 4; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppSkeletonBox(width: 180, height: 16),
                      SizedBox(height: AppSpacing.sm),
                      AppSkeletonBox(width: double.infinity, height: 14),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

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
            title: '背题模式【瀑布式】',
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
          allowSettings: widget.kind == LearningListKind.bank,
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
            allowSettings: widget.kind == LearningListKind.bank,
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
                  style: theme.typography.bodySmall,
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
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.micro,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: theme.typography.badge.copyWith(
        color: textColor ?? theme.colors.mutedForeground,
      ),
    ),
  );
}

enum _QuestionRowType { count, heading, card, spacer }

class _QuestionListRow {
  final _QuestionRowType type;
  final String? heading;
  final _QuestionBankGroup? group;
  final int? questionIndex;
  final double height;

  const _QuestionListRow.count()
    : type = _QuestionRowType.count,
      heading = null,
      group = null,
      questionIndex = null,
      height = 0;

  const _QuestionListRow.heading(this.heading)
    : type = _QuestionRowType.heading,
      group = null,
      questionIndex = null,
      height = 0;

  const _QuestionListRow.card(this.group, this.questionIndex)
    : type = _QuestionRowType.card,
      heading = null,
      height = 0;

  const _QuestionListRow.spacer(this.height)
    : type = _QuestionRowType.spacer,
      heading = null,
      group = null,
      questionIndex = null;
}

class _QuestionBankGroup {
  final String id;
  final String name;
  final List<LearningQuestion> questions = [];

  _QuestionBankGroup({required this.id, required this.name});

  String get title => name;
}
