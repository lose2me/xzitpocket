import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/learning_question.dart';
import 'preferences_storage.dart';
import 'control_service.dart';

typedef LearningQuestionFetcher = Future<List<LearningQuestion>> Function();
typedef LearningQuestionBankFetcher =
    Future<List<LearningQuestionBank>> Function();
typedef LearningCdkRedeemer = Future<void> Function(String code);

class LearningRepository extends ChangeNotifier {
  final PreferencesStorage preferencesStorage;
  final LearningQuestionFetcher? fetcher;
  final LearningQuestionBankFetcher? bankFetcher;
  final LearningCdkRedeemer? cdkRedeemer;

  LearningRepository({
    required this.preferencesStorage,
    this.fetcher,
    this.bankFetcher,
    this.cdkRedeemer,
  });

  List<LearningQuestion> _questions = const [];
  List<LearningQuestionBank> _banks = const [];
  final Set<String> _favoriteIds = {};
  final Set<String> _wrongIds = {};
  final Map<String, Set<String>> _answers = {};
  final Set<String> _judgedIds = {};
  final List<String> _judgedOrder = [];
  bool _loaded = false;
  bool _libraryUnavailable = false;

  List<LearningQuestion> get questions => List.unmodifiable(_questions);
  List<LearningQuestionBank> get banks => List.unmodifiable(_banks);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  Set<String> get wrongIds => Set.unmodifiable(_wrongIds);
  bool get isLoaded => _loaded;
  bool get libraryUnavailable => _libraryUnavailable;
  bool get canRedeemCdk => cdkRedeemer != null;
  int get answeredCount =>
      _questions.where((question) => _judgedIds.contains(question.id)).length;

  LearningQuestion? questionById(String id) {
    for (final question in _questions) {
      if (question.id == id) return question;
    }
    return null;
  }

  bool isFavorite(String questionId) => _favoriteIds.contains(questionId);

  Set<String> answerFor(String questionId) =>
      Set.unmodifiable(_answers[questionId] ?? const <String>{});

  bool isJudged(String questionId) => _judgedIds.contains(questionId);

  List<String> recentJudgedIds(Iterable<String> questionIds, {int limit = 6}) {
    final allowed = questionIds.toSet();
    final ordered = _judgedOrder.where(allowed.contains).toList();
    if (ordered.isEmpty) {
      ordered.addAll(
        _questions
            .where(
              (question) =>
                  allowed.contains(question.id) && isJudged(question.id),
            )
            .map((question) => question.id),
      );
    }
    final start = ordered.length > limit ? ordered.length - limit : 0;
    return ordered.sublist(start);
  }

  bool isCorrect(String questionId) {
    final question = questionById(questionId);
    if (question == null || !isJudged(questionId)) return false;
    if (question.isFillBlank) {
      final answer = answerFor(questionId).join().trim();
      return question.correctOptionIds.any(
        (correct) => correct.trim().toLowerCase() == answer.toLowerCase(),
      );
    }
    return _sameSet(answerFor(questionId), question.correctOptionIds);
  }

  Future<void> load() async {
    if (_loaded) return;
    await preferencesStorage.clearLearningQuestionBankCache();

    if (bankFetcher != null) {
      try {
        _libraryUnavailable = false;
        _banks = await bankFetcher!();
        _questions = [for (final bank in _banks) ...bank.questions];
      } on ControlApiException catch (error) {
        _libraryUnavailable = error.code == 'user_unavailable';
        _banks = const [];
        _questions = const [];
      } catch (_) {
        _libraryUnavailable = false;
        _banks = const [];
        _questions = const [];
      }
    } else if (fetcher != null) {
      try {
        final fetched = await fetcher!();
        if (fetched.isNotEmpty) {
          _questions = fetched;
        }
      } catch (_) {
        _questions = const [];
      }
    }
    if (_banks.isEmpty && _questions.isNotEmpty) {
      _banks = _deriveBanks(_questions);
    }
    final stateJson = preferencesStorage.getLearningStateCache();
    if (stateJson != null && stateJson.isNotEmpty) {
      try {
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        _favoriteIds
          ..clear()
          ..addAll(_stringSet(state['favoriteIds']));
        _wrongIds
          ..clear()
          ..addAll(_stringSet(state['wrongIds']));
        _judgedIds
          ..clear()
          ..addAll(_stringSet(state['judgedIds']));
        _judgedOrder
          ..clear()
          ..addAll(_stringSet(state['judgedOrder']));
        _answers
          ..clear()
          ..addAll(_answersFromJson(state['answers']));
      } catch (_) {
        _favoriteIds.clear();
        _wrongIds.clear();
        _judgedIds.clear();
        _judgedOrder.clear();
        _answers.clear();
      }
    }
    _pruneState();
    _loaded = true;
  }

  Future<void> redeemCdk(String code) async {
    final redeem = cdkRedeemer;
    if (redeem == null) return;
    await redeem(code);
    await refresh();
  }

  Future<void> refresh() async {
    if (fetcher == null && bankFetcher == null) return;
    if (bankFetcher != null) {
      try {
        _libraryUnavailable = false;
        _banks = await bankFetcher!();
      } on ControlApiException catch (error) {
        _libraryUnavailable = error.code == 'user_unavailable';
        _banks = const [];
      }
      _questions = [for (final bank in _banks) ...bank.questions];
    } else {
      final fetched = await fetcher!();
      _questions = fetched;
      _banks = _deriveBanks(fetched);
    }
    _pruneState();
    _loaded = true;
    notifyListeners();
  }

  void _pruneState() {
    final questionIds = _questions.map((question) => question.id).toSet();
    _favoriteIds.retainAll(questionIds);
    _wrongIds.retainAll(questionIds);
    _judgedIds.retainAll(questionIds);
    _judgedOrder
      ..removeWhere((questionId) => !questionIds.contains(questionId))
      ..addAll([
        for (final question in _questions)
          if (_judgedIds.contains(question.id) &&
              !_judgedOrder.contains(question.id))
            question.id,
      ]);
    _answers.removeWhere((questionId, _) => !questionIds.contains(questionId));
  }

  static List<LearningQuestionBank> _deriveBanks(
    List<LearningQuestion> questions,
  ) {
    final grouped = <String, LearningQuestionBank>{};
    for (final question in questions) {
      final key = question.bankId.trim().isNotEmpty
          ? question.bankId.trim()
          : '${question.bankName}\u0000${question.bankIsNew == true ? 'new' : 'old'}';
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = LearningQuestionBank(
          id: question.bankId,
          isNew: question.bankIsNew,
          name: question.bankName,
          orderId: question.bankOrderId,
          questions: [question],
        );
      } else {
        existing.questions.add(question);
      }
    }
    return grouped.values.toList();
  }

  static Set<String> _stringSet(dynamic value) {
    if (value is! List) return <String>{};
    return {for (final item in value) item.toString()};
  }

  static Map<String, Set<String>> _answersFromJson(dynamic value) {
    if (value is! Map) return <String, Set<String>>{};
    return {
      for (final entry in value.entries)
        entry.key.toString(): _stringSet(entry.value),
    };
  }

  Future<void> toggleFavorite(String questionId) async {
    if (_favoriteIds.contains(questionId)) {
      _favoriteIds.remove(questionId);
    } else {
      _favoriteIds.add(questionId);
    }
    await _persistState();
    notifyListeners();
  }

  Future<void> clearWrongQuestions() async {
    if (_wrongIds.isEmpty) return;
    _wrongIds.clear();
    await _persistState();
    notifyListeners();
  }

  Future<void> clearFavorites() async {
    if (_favoriteIds.isEmpty) return;
    _favoriteIds.clear();
    await _persistState();
    notifyListeners();
  }

  Future<bool> submitAnswer(
    String questionId,
    Iterable<String> optionIds,
  ) async {
    final question = questionById(questionId);
    if (question == null) return false;
    if (_judgedIds.contains(questionId)) return isCorrect(questionId);
    final selected = optionIds.toSet();
    if (selected.isEmpty ||
        (selected.length == 1 && selected.first.trim().isEmpty)) {
      return false;
    }
    _answers[questionId] = selected;
    _judgedIds.add(questionId);
    _judgedOrder.remove(questionId);
    _judgedOrder.add(questionId);
    final correct = _sameSet(selected, question.correctOptionIds);
    if (correct) {
      _wrongIds.remove(questionId);
    } else {
      _wrongIds.add(questionId);
    }
    await _persistState();
    notifyListeners();
    return correct;
  }

  Future<void> resetProgress([Iterable<String>? questionIds]) async {
    final ids =
        questionIds?.toSet() ??
        _questions.map((question) => question.id).toSet();
    _answers.removeWhere((questionId, _) => ids.contains(questionId));
    _judgedIds.removeAll(ids);
    _judgedOrder.removeWhere(ids.contains);
    await _persistState();
    notifyListeners();
  }

  Future<void> _persistState() => preferencesStorage.setLearningStateCache(
    jsonEncode({
      'favoriteIds': _favoriteIds.toList(),
      'wrongIds': _wrongIds.toList(),
      'judgedIds': _judgedIds.toList(),
      'judgedOrder': _judgedOrder,
      'answers': {
        for (final entry in _answers.entries) entry.key: entry.value.toList(),
      },
    }),
  );

  static bool _sameSet(Set<String> first, Set<String> second) =>
      first.length == second.length && first.containsAll(second);
}
