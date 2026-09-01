import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/learning_question.dart';
import '../../services/learning_repository.dart';
import '../../ui/app_components.dart';

enum LearningQuizMode { normal, random, memorize }

class LearningQuizPage extends StatefulWidget {
  final LearningRepository repository;
  final List<String> questionIds;
  final int initialIndex;
  final String pageTitle;
  final LearningQuizMode mode;

  const LearningQuizPage({
    super.key,
    required this.repository,
    required this.questionIds,
    this.initialIndex = 0,
    this.pageTitle = '题库',
    this.mode = LearningQuizMode.normal,
  });

  @override
  State<LearningQuizPage> createState() => _LearningQuizPageState();
}

class _LearningQuizPageState extends State<LearningQuizPage> {
  late final PageController _pageController;
  late final List<String> _questionIds;
  late int _currentIndex;
  final Map<String, Set<String>> _draftAnswers = {};
  final Map<String, String> _draftTextAnswers = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Set<String> _judgingIds = {};

  LearningRepository get repository => widget.repository;

  LearningQuestion? get _question {
    if (_currentIndex < 0 || _currentIndex >= _questionIds.length) {
      return null;
    }
    return repository.questionById(_questionIds[_currentIndex]);
  }

  @override
  void initState() {
    super.initState();
    _questionIds = [...widget.questionIds];
    if (widget.mode == LearningQuizMode.random) {
      _questionIds.shuffle(Random());
    }
    final lastIndex = _questionIds.isEmpty ? 0 : _questionIds.length - 1;
    _currentIndex = widget.initialIndex.clamp(0, lastIndex);
    _pageController = PageController(initialPage: _currentIndex);
    _loadSelection(_currentIndex);
    repository.addListener(_onRepositoryUpdate);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    repository.removeListener(_onRepositoryUpdate);
    super.dispose();
  }

  void _onRepositoryUpdate() {
    if (mounted) setState(() {});
  }

  Set<String> _selectionFor(LearningQuestion question) =>
      _draftAnswers[question.id] ?? {...repository.answerFor(question.id)};

  String _textAnswerFor(LearningQuestion question, {String? override}) {
    if (override != null) return override;
    final draft = _draftTextAnswers[question.id];
    if (draft != null) return draft;
    return repository.answerFor(question.id).firstOrNull ?? '';
  }

  TextEditingController _textControllerFor(
    LearningQuestion question, {
    String? answerOverride,
  }) {
    final answer = _textAnswerFor(question, override: answerOverride);
    final controller = _textControllers.putIfAbsent(
      question.id,
      () => TextEditingController(text: answer),
    );
    if (controller.text != answer) controller.text = answer;
    return controller;
  }

  Set<String> _answerFor(LearningQuestion question) {
    if (question.isFillBlank) return {_textAnswerFor(question).trim()};
    return _selectionFor(question);
  }

  bool _hasAnswer(LearningQuestion question) {
    final answer = _answerFor(question);
    return answer.isNotEmpty &&
        !(answer.length == 1 && answer.first.trim().isEmpty);
  }

  void _loadSelection(int index) {
    if (index < 0 || index >= _questionIds.length) return;
    final question = repository.questionById(_questionIds[index]);
    if (question == null) return;
    _draftAnswers[question.id] = {...repository.answerFor(question.id)};
  }

  void _selectOption(LearningQuestion question, String optionId) {
    if (widget.mode == LearningQuizMode.memorize ||
        repository.isJudged(question.id) ||
        _judgingIds.contains(question.id)) {
      return;
    }
    final selected = {..._selectionFor(question)};
    if (question.isMultiple) {
      if (selected.contains(optionId)) {
        selected.remove(optionId);
      } else {
        selected.add(optionId);
      }
    } else {
      selected
        ..clear()
        ..add(optionId);
    }
    setState(() => _draftAnswers[question.id] = selected);
  }

  void _updateTextAnswer(LearningQuestion question, String value) {
    if (widget.mode == LearningQuizMode.memorize ||
        repository.isJudged(question.id) ||
        _judgingIds.contains(question.id)) {
      return;
    }
    _draftTextAnswers[question.id] = value;
  }

  void _handlePageChanged(int nextIndex) {
    final previousIndex = _currentIndex;
    _currentIndex = nextIndex;
    _loadSelection(nextIndex);
    setState(() {});
    if (previousIndex != nextIndex) {
      unawaited(_judgeAndNotify(previousIndex));
    }
  }

  Future<void> _judgeAndNotify(int index) async {
    if (widget.mode == LearningQuizMode.memorize) return;
    if (index < 0 || index >= _questionIds.length) return;
    final question = repository.questionById(_questionIds[index]);
    if (question == null) return;
    if (repository.isJudged(question.id) || _judgingIds.contains(question.id)) {
      return;
    }
    if (!_hasAnswer(question)) return;
    _judgingIds.add(question.id);
    try {
      await repository.submitAnswer(question.id, _answerFor(question));
    } finally {
      _judgingIds.remove(question.id);
    }
  }

  void _goPrevious() {
    if (_currentIndex == 0 || !_pageController.hasClients) return;
    unawaited(
      _pageController.previousPage(
        duration: AppMotion.standard,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _goNext() async {
    if (widget.mode == LearningQuizMode.memorize) {
      if (_currentIndex < _questionIds.length - 1 &&
          _pageController.hasClients) {
        unawaited(
          _pageController.nextPage(
            duration: AppMotion.standard,
            curve: Curves.easeOutCubic,
          ),
        );
      }
      return;
    }
    if (_currentIndex >= _questionIds.length - 1) {
      final question = _question;
      if (question == null) return;
      if (repository.isJudged(question.id) ||
          _judgingIds.contains(question.id)) {
        return;
      }
      if (!_hasAnswer(question)) return;
      _judgingIds.add(question.id);
      try {
        await repository.submitAnswer(question.id, _answerFor(question));
      } finally {
        _judgingIds.remove(question.id);
      }
      return;
    }
    if (!_pageController.hasClients) return;
    unawaited(
      _pageController.nextPage(
        duration: AppMotion.standard,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _openQuestionCard() async {
    final selectedIndex = await showAppSheet<int>(
      context: context,
      maxHeightRatio: 0.65,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选题卡', style: context.theme.typography.pageTitle),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1,
                ),
                itemCount: widget.questionIds.length,
                itemBuilder: (context, index) {
                  final questionId = widget.questionIds[index];
                  final question = repository.questionById(questionId);
                  if (question == null) return const SizedBox.shrink();
                  final judged = repository.isJudged(question.id);
                  final correct = judged && repository.isCorrect(question.id);
                  final targetPage = _questionIds.indexOf(questionId);
                  final current = _question?.id == questionId;
                  final background = judged
                      ? correct
                            ? context.theme.colors.semantic.successContainer
                            : context.theme.colors.destructive.withAlpha(28)
                      : current
                      ? context.theme.colors.secondary
                      : context.theme.colors.card;
                  final foreground = judged
                      ? correct
                            ? context.theme.colors.semantic.onSuccessContainer
                            : context.theme.colors.destructive
                      : current
                      ? context.theme.colors.primary
                      : context.theme.colors.mutedForeground;
                  final border = judged
                      ? correct
                            ? context.theme.colors.semantic.success
                            : context.theme.colors.destructive
                      : current
                      ? context.theme.colors.primary
                      : context.theme.colors.border;
                  return Semantics(
                    button: true,
                    selected: current,
                    label: '第${index + 1}题',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: targetPage < 0
                          ? null
                          : () => Navigator.pop(sheetContext, targetPage),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: border,
                            width: current ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: context.theme.typography.bodySmall.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selectedIndex == null || !_pageController.hasClients) {
      return;
    }
    unawaited(
      _pageController.animateToPage(
        selectedIndex,
        duration: AppMotion.standard,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final question = _question;
    if (question == null) return;
    await repository.toggleFavorite(question.id);
  }

  Future<void> _resetProgress() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '清空做题数据',
      message: '将清空本题单的答题进度，错题集和收藏集会保留。',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed) return;
    await repository.resetProgress(_questionIds);
    _draftAnswers.clear();
    _draftTextAnswers.clear();
    for (final controller in _textControllers.values) {
      controller.clear();
    }
    if (mounted) setState(() {});
  }

  Future<void> _openMode(LearningQuizMode mode) async {
    if (mode == widget.mode) return;
    await Navigator.of(context).pushReplacement(
      appRoute(
        name: AppRouteNames.learningQuiz,
        builder: (_) => LearningQuizPage(
          repository: repository,
          questionIds: widget.questionIds,
          initialIndex: 0,
          pageTitle: widget.pageTitle,
          mode: mode,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final selected = await showAppSheet<LearningQuizMode>(
      context: context,
      builder: (context) => AppOptionSheet<LearningQuizMode>(
        title: '刷题设置',
        value: widget.mode,
        options: const [
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
            subtitle: '直接显示正确答案',
            icon: FLucideIcons.bookOpen,
          ),
        ],
      ),
    );
    if (selected != null) await _openMode(selected);
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;
    if (question == null) {
      return const AppPage(
        title: '题库',
        child: AppStateView(icon: FLucideIcons.circleAlert, title: '题目不存在'),
      );
    }
    final theme = context.theme;
    return AppPage(
      title: widget.pageTitle,
      actions: [
        AppIconButton(
          icon: FLucideIcons.settings,
          onPress: _openSettings,
          tooltip: '刷题设置',
        ),
        AppIconButton(
          icon: FLucideIcons.trash2,
          onPress: _resetProgress,
          tooltip: '清空做题数据',
        ),
      ],
      footer: _buildFooter(theme, question),
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: _handlePageChanged,
        itemCount: _questionIds.length,
        itemBuilder: (context, index) {
          final item = repository.questionById(_questionIds[index]);
          return item == null
              ? const AppStateView(
                  icon: FLucideIcons.circleAlert,
                  title: '题目不存在',
                )
              : _buildQuestionView(theme, item, index);
        },
      ),
    );
  }

  Widget _buildQuestionView(
    FThemeData theme,
    LearningQuestion question,
    int pageIndex,
  ) {
    final originalIndex = widget.questionIds.indexOf(question.id);
    final questionNumber = originalIndex >= 0
        ? originalIndex + 1
        : pageIndex + 1;
    final selected = widget.mode == LearningQuizMode.memorize
        ? const <String>{}
        : _selectionFor(question);
    final submitted = repository.isJudged(question.id);
    final revealed = submitted || widget.mode == LearningQuizMode.memorize;
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      primary: false,
      children: [
        Row(
          children: [
            Text(
              '$questionNumber/${widget.questionIds.length}',
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const Spacer(),
            Text(
              question.typeLabel,
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (question.title != question.questionText) ...[
          Text(
            question.title,
            style: theme.typography.caption.copyWith(
              color: theme.colors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          question.questionText,
          style: theme.typography.body.lg.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (question.isFillBlank)
          AppTextField(
            controller: _textControllerFor(
              question,
              answerOverride: widget.mode == LearningQuizMode.memorize
                  ? question.correctOptionIds.join(', ')
                  : null,
            ),
            label: '答案',
            hint: revealed ? null : '请输入答案',
            readOnly: revealed,
            enabled: !revealed,
            onChanged: (value) => _updateTextAnswer(question, value),
          )
        else
          for (var index = 0; index < question.options.length; index++) ...[
            _buildOption(
              theme,
              question,
              question.options[index],
              selected,
              revealed,
            ),
            if (index != question.options.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        if (widget.mode == LearningQuizMode.memorize) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            '答案：${_answerLabel(question)}',
            style: theme.typography.bodyText.copyWith(
              color: theme.colors.semantic.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  String _answerLabel(LearningQuestion question) {
    if (question.isFillBlank || question.isTrueFalse) {
      return question.correctOptionIds.join('、');
    }
    final ids = question.options
        .where((option) => question.correctOptionIds.contains(option.id))
        .map((option) => option.text)
        .toList();
    return ids.isEmpty ? question.correctOptionIds.join('、') : ids.join('、');
  }

  Widget _buildOption(
    FThemeData theme,
    LearningQuestion question,
    LearningOption option,
    Set<String> selectedIds,
    bool submitted,
  ) {
    final selected = selectedIds.contains(option.id);
    final isCorrectOption = question.correctOptionIds.contains(option.id);
    final showCorrect = submitted && isCorrectOption;
    final showWrong = submitted && selected && !isCorrectOption;
    final borderColor = showCorrect
        ? theme.colors.semantic.success
        : showWrong
        ? theme.colors.destructive
        : selected
        ? theme.colors.primary
        : theme.colors.border;
    final backgroundColor = showCorrect
        ? theme.colors.semantic.successContainer
        : showWrong
        ? theme.colors.semantic.warningContainer
        : selected
        ? theme.colors.secondary
        : theme.colors.card;
    return Semantics(
      button: true,
      selected: selected,
      label: option.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: submitted ? null : () => _selectOption(question, option.id),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.text, style: theme.typography.bodyText),
                    if (option.imageUrl != null &&
                        option.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          option.imageUrl!,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : Container(
                                  height: 120,
                                  color: theme.colors.muted,
                                  alignment: Alignment.center,
                                  child: const FCircularProgress(
                                    size: FCircularProgressSizeVariant.sm,
                                  ),
                                ),
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 120,
                                color: theme.colors.muted,
                                alignment: Alignment.center,
                                child: Icon(
                                  FLucideIcons.imageOff,
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (submitted && (showCorrect || showWrong)) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  showCorrect ? FLucideIcons.check : FLucideIcons.x,
                  size: 19,
                  color: showCorrect
                      ? theme.colors.semantic.success
                      : theme.colors.destructive,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(FThemeData theme, LearningQuestion question) {
    final favorite = repository.isFavorite(question.id);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colors.card,
          border: Border(top: BorderSide(color: theme.colors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: FButton(
                size: FButtonSizeVariant.sm,
                variant: FButtonVariant.ghost,
                onPress: _currentIndex == 0 ? null : _goPrevious,
                prefix: const Icon(FLucideIcons.chevronLeft),
                child: const Text('上一题'),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            AppIconButton(
              icon: FLucideIcons.grid2x2,
              onPress: _openQuestionCard,
              tooltip: '选题卡',
              size: FButtonSizeVariant.sm,
            ),
            const SizedBox(width: AppSpacing.xs),
            AppIconButton(
              icon: favorite
                  ? FLucideIcons.bookmarkCheck
                  : FLucideIcons.bookmark,
              onPress: _toggleFavorite,
              tooltip: favorite ? '取消收藏' : '收藏',
              variant: favorite
                  ? FButtonVariant.secondary
                  : FButtonVariant.outline,
              size: FButtonSizeVariant.sm,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: FButton(
                size: FButtonSizeVariant.sm,
                variant: FButtonVariant.primary,
                onPress: _goNext,
                suffix: const Icon(FLucideIcons.chevronRight),
                child: const Text('下一题'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
