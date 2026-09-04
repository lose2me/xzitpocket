import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/learning_question.dart';
import '../../services/learning_repository.dart';
import '../../ui/app_components.dart';

enum LearningQuizMode { normal, random, memorize, memorizeFlow }

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
  bool get _isMemorize =>
      widget.mode == LearningQuizMode.memorize ||
      widget.mode == LearningQuizMode.memorizeFlow;
  bool get _isMemorizeFlow => widget.mode == LearningQuizMode.memorizeFlow;

  String get _displayTitle {
    final provided = widget.pageTitle.trim();
    const genericTitles = {'题库', '错题集', '收藏集'};
    if (provided.isNotEmpty && !genericTitles.contains(provided)) {
      return provided;
    }
    for (final questionId in widget.questionIds) {
      final bankName = repository.questionById(questionId)?.bankName.trim();
      if (bankName != null && bankName.isNotEmpty) return bankName;
    }
    return provided.isEmpty ? '题库' : provided;
  }

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
    if (_isMemorize ||
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
    if (_isMemorize ||
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
    if (_isMemorize) return;
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
    if (_isMemorize) {
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
      if (!repository.isJudged(question.id)) {
        if (_judgingIds.contains(question.id) || !_hasAnswer(question)) {
          return;
        }
        _judgingIds.add(question.id);
        try {
          await repository.submitAnswer(question.id, _answerFor(question));
        } finally {
          _judgingIds.remove(question.id);
        }
      }
      await _advanceToNextUnanswered();
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

  Future<void> _advanceToNextUnanswered() async {
    if (_isMemorize) return;
    final unanswered = [
      for (final questionId in widget.questionIds)
        if (!repository.isJudged(questionId) &&
            !_judgingIds.contains(questionId))
          questionId,
    ];
    if (unanswered.isEmpty) return;
    final nextId = widget.mode == LearningQuizMode.random
        ? (unanswered..shuffle(Random())).first
        : unanswered.first;
    var targetIndex = _questionIds.indexOf(nextId);
    if (targetIndex < 0) {
      _questionIds.add(nextId);
      targetIndex = _questionIds.length - 1;
    }
    if (!_pageController.hasClients || targetIndex == _currentIndex) return;
    await _pageController.animateToPage(
      targetIndex,
      duration: AppMotion.standard,
      curve: Curves.easeOutCubic,
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
            SizedBox(
              width: double.infinity,
              child: Text(
                '选题卡',
                textAlign: TextAlign.center,
                style: context.theme.typography.pageTitle,
              ),
            ),
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
                  final questionNumber = question.questionNumber ?? index + 1;
                  final judged = repository.isJudged(question.id);
                  final correct = judged && repository.isCorrect(question.id);
                  final targetPage = _questionIds.indexOf(questionId);
                  final current = _question?.id == questionId;
                  final background = _isMemorize
                      ? context.theme.colors.semantic.successContainer
                      : judged
                      ? correct
                            ? context.theme.colors.semantic.successContainer
                            : context.theme.colors.destructive.withAlpha(28)
                      : current
                      ? context.theme.colors.secondary
                      : context.theme.colors.card;
                  final foreground = _isMemorize
                      ? context.theme.colors.semantic.onSuccessContainer
                      : judged
                      ? correct
                            ? context.theme.colors.semantic.onSuccessContainer
                            : context.theme.colors.destructive
                      : current
                      ? context.theme.colors.primary
                      : context.theme.colors.mutedForeground;
                  final border = _isMemorize
                      ? context.theme.colors.semantic.success
                      : judged
                      ? correct
                            ? context.theme.colors.semantic.success
                            : context.theme.colors.destructive
                      : current
                      ? context.theme.colors.primary
                      : context.theme.colors.border;
                  return Semantics(
                    button: true,
                    selected: current,
                    label: '第$questionNumber题',
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
                          '$questionNumber',
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
    if (_isMemorizeFlow) {
      return AppPage(
        title: _displayTitle,
        actions: [
          AppIconButton(
            icon: FLucideIcons.grid2x2,
            onPress: _openQuestionCard,
            tooltip: '选题卡',
          ),
          AppIconButton(
            icon: FLucideIcons.settings,
            onPress: _openSettings,
            tooltip: '刷题设置',
          ),
        ],
        child: _buildMemorizeFlow(theme),
      );
    }
    return AppPage(
      title: _displayTitle,
      actions: _isMemorize
          ? [
              AppIconButton(
                icon: FLucideIcons.settings,
                onPress: _openSettings,
                tooltip: '刷题设置',
              ),
            ]
          : [
              AppIconButton(
                icon: FLucideIcons.trash2,
                onPress: _resetProgress,
                tooltip: '清空做题数据',
              ),
              AppIconButton(
                icon: FLucideIcons.settings,
                onPress: _openSettings,
                tooltip: '刷题设置',
              ),
            ],
      footer: _buildFooter(theme, question),
      child: Column(
        children: [
          if (!_isMemorize) _buildFixedHeader(theme, question),
          Expanded(
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
                    : _buildQuestionView(theme, item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedHeader(FThemeData theme, LearningQuestion question) {
    if (_isMemorize) return const SizedBox.shrink();
    final originalIndex = widget.questionIds.indexOf(question.id);
    final questionNumber =
        question.questionNumber ??
        (originalIndex >= 0 ? originalIndex + 1 : _currentIndex + 1);
    final judgedCount = widget.questionIds.where(repository.isJudged).length;
    final progress = widget.questionIds.isEmpty
        ? 0
        : (judgedCount / widget.questionIds.length * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(bottom: BorderSide(color: theme.colors.border)),
      ),
      child: AppContentFrame(
        safeArea: false,
        topPadding: AppSpacing.md,
        bottomPadding: AppSpacing.md,
        child: Row(
          children: [
            Text(
              '$questionNumber/${widget.questionIds.length}',
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$progress%',
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Expanded(child: Center(child: _buildRecentStatusDots(theme))),
            Text(
              question.typeLabel,
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionView(FThemeData theme, LearningQuestion question) {
    final selected = _isMemorize ? const <String>{} : _selectionFor(question);
    final submitted = repository.isJudged(question.id);
    final revealed = submitted || _isMemorize;
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.sm,
      bottomPadding: AppSpacing.xxl,
      primary: false,
      children: [
        Text(
          _questionPrompt(question),
          style: theme.typography.body.lg.copyWith(height: 1.45),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (question.isFillBlank)
          AppTextField(
            controller: _textControllerFor(
              question,
              answerOverride: _isMemorize
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
              optionIndex: index,
            ),
            if (index != question.options.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  Widget _buildMemorizeFlow(FThemeData theme) => AppPageListView(
    maxWidth: AppLayout.resultMaxWidth,
    topPadding: AppSpacing.lg,
    bottomPadding: AppSpacing.xxl,
    children: [
      for (var index = 0; index < widget.questionIds.length; index++)
        if (repository.questionById(widget.questionIds[index])
            case final question?)
          _buildFlowQuestion(theme, question, index),
    ],
  );

  Widget _buildFlowQuestion(
    FThemeData theme,
    LearningQuestion question,
    int index,
  ) {
    final number = question.questionNumber ?? index + 1;
    return Padding(
      padding: EdgeInsets.only(
        bottom: index == widget.questionIds.length - 1 ? 0 : AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.typeLabel,
            style: theme.typography.caption.copyWith(
              color: theme.colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _questionPrompt(
              question,
              fallbackNumber: number,
              revealFillBlank: true,
            ),
            style: theme.typography.body.lg,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!question.isFillBlank) ...[
            for (
              var optionIndex = 0;
              optionIndex < question.options.length;
              optionIndex++
            ) ...[
              _buildOption(
                theme,
                question,
                question.options[optionIndex],
                const <String>{},
                true,
                optionIndex: optionIndex,
              ),
              if (optionIndex != question.options.length - 1)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ],
      ),
    );
  }

  String _questionPrompt(
    LearningQuestion question, {
    int? fallbackNumber,
    bool revealFillBlank = false,
  }) {
    final number =
        question.questionNumber ??
        fallbackNumber ??
        widget.questionIds.indexOf(question.id) + 1;
    var text = question.questionText;
    if (revealFillBlank && question.isFillBlank) {
      final answer = question.correctOptionIds.join('、');
      final revealed = text.replaceFirst(RegExp(r'_{2,}'), answer);
      text = revealed == text ? '$text（$answer）' : revealed;
    }
    return '$number.$text';
  }

  Widget _buildRecentStatusDots(FThemeData theme) {
    final slotCount = min(widget.questionIds.length, 6);
    final judgedIds = repository.recentJudgedIds(
      _questionIds,
      limit: slotCount,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < slotCount - judgedIds.length; index++) ...[
          _buildStatusDot(theme, null, latest: false),
          const SizedBox(width: AppSpacing.xs),
        ],
        for (var index = 0; index < judgedIds.length; index++) ...[
          _buildStatusDot(
            theme,
            repository.isCorrect(judgedIds[index]),
            questionNumber: _questionNumberFor(judgedIds[index]),
            latest: index == judgedIds.length - 1,
          ),
          if (index != judgedIds.length - 1)
            const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }

  int _questionNumberFor(String questionId) {
    final question = repository.questionById(questionId);
    if (question?.questionNumber != null) return question!.questionNumber!;
    final index = widget.questionIds.indexOf(questionId);
    return index < 0 ? 0 : index + 1;
  }

  Widget _buildStatusDot(
    FThemeData theme,
    bool? status, {
    int? questionNumber,
    required bool latest,
  }) {
    final fill = status == null
        ? theme.colors.mutedForeground.withAlpha(100)
        : status
        ? theme.colors.semantic.success
        : theme.colors.destructive;
    return Container(
      width: 18,
      height: 18,
      padding: EdgeInsets.all(latest ? 1.5 : 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: latest
            ? Border.all(color: theme.colors.primary, width: 1.5)
            : null,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: questionNumber == null
            ? null
            : Center(
                child: Text(
                  '$questionNumber',
                  style: theme.typography.caption.copyWith(
                    color: Colors.white,
                    fontSize: questionNumber >= 100 ? 7 : 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildOption(
    FThemeData theme,
    LearningQuestion question,
    LearningOption option,
    Set<String> selectedIds,
    bool submitted, {
    required int optionIndex,
  }) {
    final optionLabel = _optionLabel(option, optionIndex);
    final optionText = _optionText(option.text);
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
        ? theme.colors.destructive.withAlpha(28)
        : selected
        ? theme.colors.secondary
        : theme.colors.card;
    return Semantics(
      button: true,
      selected: selected,
      label: '$optionLabel $optionText',
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
              SizedBox(
                width: 28,
                child: Text(
                  optionLabel,
                  style: theme.typography.bodyText.copyWith(
                    color: showCorrect
                        ? theme.colors.semantic.success
                        : showWrong
                        ? theme.colors.destructive
                        : selected
                        ? theme.colors.primary
                        : theme.colors.mutedForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(optionText, style: theme.typography.bodyText),
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

  String _optionLabel(LearningOption option, int index) {
    final id = option.id.trim();
    if (RegExp(r'^[A-Za-z]$').hasMatch(id)) return id.toUpperCase();
    return String.fromCharCode('A'.codeUnitAt(0) + index);
  }

  String _optionText(String text) {
    final value = text.trim();
    return value.replaceFirst(RegExp(r'^[A-Za-z][.、)）:\s]+'), '');
  }

  Widget _buildFooter(FThemeData theme, LearningQuestion question) {
    if (_isMemorizeFlow) return const SizedBox.shrink();
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
              variant: FButtonVariant.ghost,
              size: FButtonSizeVariant.sm,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: FButton(
                size: FButtonSizeVariant.sm,
                variant: FButtonVariant.ghost,
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
