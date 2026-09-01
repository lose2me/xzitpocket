import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/learning_question.dart';
import 'preferences_storage.dart';

typedef LearningQuestionFetcher = Future<List<LearningQuestion>> Function();

class LearningRepository extends ChangeNotifier {
  final PreferencesStorage preferencesStorage;
  final LearningQuestionFetcher? fetcher;

  LearningRepository({required this.preferencesStorage, this.fetcher});

  List<LearningQuestion> _questions = const [];
  String _questionBankName = '题库';
  int? _questionBankYear;
  final Set<String> _favoriteIds = {};
  final Set<String> _wrongIds = {};
  final Map<String, Set<String>> _answers = {};
  final Set<String> _judgedIds = {};
  bool _loaded = false;

  List<LearningQuestion> get questions => List.unmodifiable(_questions);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  Set<String> get wrongIds => Set.unmodifiable(_wrongIds);
  bool get isLoaded => _loaded;
  String get questionBankName => _questionBankName;
  int? get questionBankYear => _questionBankYear;
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

    final cachedQuestions = preferencesStorage.getLearningQuestionBankCache();
    if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedQuestions);
        if (decoded is Map<String, dynamic> &&
            (decoded['questionBank'] is Map<String, dynamic> ||
                decoded['questions'] is List<dynamic>)) {
          final bank = LearningQuestionBank.fromJson(decoded);
          _questionBankName = bank.name;
          _questionBankYear = bank.year;
          _questions = bank.questions;
        } else if (decoded is List<dynamic>) {
          final banks = [
            for (final item in decoded)
              if (item is Map<String, dynamic> &&
                  (item['questionBank'] is Map<String, dynamic> ||
                      item['questions'] is List<dynamic>))
                LearningQuestionBank.fromJson(item),
          ];
          if (banks.isNotEmpty) {
            _questionBankName = banks.first.name;
            _questionBankYear = banks.first.year;
            _questions = [for (final bank in banks) ...bank.questions];
          } else {
            _questions = [
              for (final item in decoded)
                LearningQuestion.fromJson(item as Map<String, dynamic>),
            ];
          }
        }
      } catch (_) {
        _questions = const [];
      }
    }

    if (_questions.isEmpty) {
      _questions = fetcher == null
          ? defaultLearningQuestions()
          : await fetcher!();
      await preferencesStorage.setLearningQuestionBankCache(
        jsonEncode([for (final question in _questions) question.toJson()]),
      );
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
        _answers
          ..clear()
          ..addAll(_answersFromJson(state['answers']));
      } catch (_) {
        _favoriteIds.clear();
        _wrongIds.clear();
        _judgedIds.clear();
        _answers.clear();
      }
    }
    final questionIds = _questions.map((question) => question.id).toSet();
    _favoriteIds.retainAll(questionIds);
    _wrongIds.retainAll(questionIds);
    _judgedIds.retainAll(questionIds);
    _answers.removeWhere((questionId, _) => !questionIds.contains(questionId));
    _loaded = true;
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
    await _persistState();
    notifyListeners();
  }

  Future<void> _persistState() => preferencesStorage.setLearningStateCache(
    jsonEncode({
      'favoriteIds': _favoriteIds.toList(),
      'wrongIds': _wrongIds.toList(),
      'judgedIds': _judgedIds.toList(),
      'answers': {
        for (final entry in _answers.entries) entry.key: entry.value.toList(),
      },
    }),
  );

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

  static bool _sameSet(Set<String> first, Set<String> second) =>
      first.length == second.length && first.containsAll(second);
}
