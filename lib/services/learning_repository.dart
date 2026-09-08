import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/learning_question.dart';
import 'preferences_storage.dart';
import 'control_service.dart';

typedef LearningQuestionFetcher = Future<List<LearningQuestion>> Function();
typedef LearningQuestionBankFetcher =
    Future<List<LearningQuestionBank>> Function();
typedef LearningCdkRedeemer = Future<void> Function(
  String code,
  String questionBankId,
);

class LearningRepository extends ChangeNotifier {
  static const _libraryCacheTtl = Duration(minutes: 5);

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
  Map<String, LearningQuestion>? _questionIndex;
  List<LearningQuestionBank> _banks = const [];
  final Set<String> _favoriteIds = {};
  final Set<String> _wrongIds = {};
  final Map<String, Set<String>> _answers = {};
  final Set<String> _judgedIds = {};
  final List<String> _judgedOrder = [];
  bool _loaded = false;
  bool _libraryUnavailable = false;
  int _libraryRevision = 0;
  bool _loadedFromCache = false;
  bool _loadedFromNetwork = false;

  List<LearningQuestion> get questions => List.unmodifiable(_questions);
  List<LearningQuestionBank> get banks => List.unmodifiable(_banks);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  Set<String> get wrongIds => Set.unmodifiable(_wrongIds);
  bool get isLoaded => _loaded;
  bool get libraryUnavailable => _libraryUnavailable;
  int get libraryRevision => _libraryRevision;
  bool get canRedeemCdk => cdkRedeemer != null;
  bool get loadedFromCache => _loadedFromCache;
  bool get loadedFromNetwork => _loadedFromNetwork;
  bool get isLibraryCacheFresh => PreferencesStorage.isCacheValid(
    preferencesStorage.getLearningQuestionBankCacheTime(),
    _libraryCacheTtl,
  );
  int get answeredCount =>
      _questions.where((question) => _judgedIds.contains(question.id)).length;

  LearningQuestion? questionById(String id) {
    final index = _questionIndex ??= <String, LearningQuestion>{};
    if (index.isEmpty && _questions.isNotEmpty) {
      for (final question in _questions) {
        index.putIfAbsent(question.id, () => question);
      }
    }
    return index[id];
  }

  void _setQuestions(List<LearningQuestion> questions) {
    _questions = questions;
    _questionIndex = null;
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
    final cachedRaw = preferencesStorage.getLearningQuestionBankCache();
    final cachedBanks = cachedRaw == null ? null : _decodeBanks(cachedRaw);
    if (cachedBanks != null) {
      _banks = cachedBanks;
      _setQuestions([for (final bank in _banks) ...bank.questions]);
      _loadedFromCache = true;
    }
    _restoreState();

    if (_loadedFromCache) {
      if (_pruneState()) await _persistState();
      _loaded = true;
      _libraryRevision++;
      notifyListeners();
      return;
    }

    if (bankFetcher != null) {
      try {
        await refresh();
      } catch (_) {
        // Cached data remains visible when the control service is unavailable.
        if (!_loaded) {
          _loaded = true;
          _libraryRevision++;
          notifyListeners();
        }
      }
      return;
    }

    if (!_loaded && fetcher != null) {
      try {
        final fetched = await fetcher!();
        _setQuestions(fetched);
        _banks = _deriveBanks(fetched);
        await _saveBankCache();
        _loadedFromNetwork = true;
      } catch (_) {
        _setQuestions(const []);
      }
    }
    if (_banks.isEmpty && _questions.isNotEmpty) {
      _banks = _deriveBanks(_questions);
    }
    if (_pruneState()) await _persistState();
    _loaded = true;
    _libraryRevision++;
    notifyListeners();
  }

  void _restoreState() {
    final stateJson = preferencesStorage.getLearningStateCache();
    if (stateJson == null || stateJson.isEmpty) return;
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

  Future<void> redeemCdk(String code, String questionBankId) async {
    final redeem = cdkRedeemer;
    if (redeem == null) return;
    await redeem(code, questionBankId);
    await refresh();
  }

  Future<void> refresh() async {
    if (fetcher == null && bankFetcher == null) return;
    final previousBanks = _banks;
    List<LearningQuestionBank> fetchedBanks;
    if (bankFetcher != null) {
      try {
        _libraryUnavailable = false;
        fetchedBanks = await bankFetcher!();
      } on ControlApiException catch (error) {
        _libraryUnavailable = error.code == 'user_unavailable';
        notifyListeners();
        rethrow;
      }
    } else {
      final fetched = await fetcher!();
      fetchedBanks = _deriveBanks(fetched);
    }

    final fetchedBankIds = {
      for (final bank in fetchedBanks)
        if (bank.id.trim().isNotEmpty) bank.id.trim(),
    };
    final removedQuestionIds = {
      for (final bank in previousBanks)
        if (bank.id.trim().isNotEmpty &&
            !fetchedBankIds.contains(bank.id.trim()))
          for (final question in bank.questions) question.id,
    };
    _banks = fetchedBanks;
    _setQuestions([for (final bank in fetchedBanks) ...bank.questions]);
    _loadedFromNetwork = true;

    var stateChanged = _dropQuestions(removedQuestionIds);
    stateChanged = _pruneState() || stateChanged;
    await _saveBankCache();
    if (stateChanged) await _persistState();
    _loaded = true;
    _libraryRevision++;
    notifyListeners();
  }

  bool _pruneState() {
    final questionIds = _questions.map((question) => question.id).toSet();
    var changed = false;
    final favoriteCount = _favoriteIds.length;
    _favoriteIds.retainAll(questionIds);
    changed = _favoriteIds.length != favoriteCount || changed;
    final wrongCount = _wrongIds.length;
    _wrongIds.retainAll(questionIds);
    changed = _wrongIds.length != wrongCount || changed;
    final judgedCount = _judgedIds.length;
    _judgedIds.retainAll(questionIds);
    changed = _judgedIds.length != judgedCount || changed;
    final judgedOrderCount = _judgedOrder.length;
    final judgedOrderIds = _judgedOrder.toSet();
    _judgedOrder
      ..removeWhere((questionId) => !questionIds.contains(questionId))
      ..addAll([
        for (final question in _questions)
          if (_judgedIds.contains(question.id) &&
              !judgedOrderIds.contains(question.id))
            question.id,
      ]);
    changed = _judgedOrder.length != judgedOrderCount || changed;
    final answerCount = _answers.length;
    _answers.removeWhere((questionId, _) => !questionIds.contains(questionId));
    changed = _answers.length != answerCount || changed;
    return changed;
  }

  bool _dropQuestions(Iterable<String> questionIds) {
    final ids = questionIds.toSet();
    if (ids.isEmpty) return false;

    var changed = false;
    final favoriteCount = _favoriteIds.length;
    _favoriteIds.removeWhere(ids.contains);
    changed = _favoriteIds.length != favoriteCount || changed;
    final wrongCount = _wrongIds.length;
    _wrongIds.removeWhere(ids.contains);
    changed = _wrongIds.length != wrongCount || changed;
    final judgedCount = _judgedIds.length;
    _judgedIds.removeWhere(ids.contains);
    changed = _judgedIds.length != judgedCount || changed;
    final judgedOrderCount = _judgedOrder.length;
    _judgedOrder.removeWhere(ids.contains);
    changed = _judgedOrder.length != judgedOrderCount || changed;
    final answerCount = _answers.length;
    _answers.removeWhere((questionId, _) => ids.contains(questionId));
    changed = _answers.length != answerCount || changed;
    return changed;
  }

  Future<void> _saveBankCache() =>
      preferencesStorage.setLearningQuestionBankCache(
        jsonEncode([for (final bank in _banks) bank.toJson()]),
      );

  static List<LearningQuestionBank>? _decodeBanks(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) LearningQuestionBank.fromJson(item),
      ];
    } catch (_) {
      return null;
    }
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

  Future<void> removeFavorites(Iterable<String> questionIds) async {
    final ids = questionIds.toSet();
    if (ids.isEmpty || !_favoriteIds.any(ids.contains)) return;
    _favoriteIds.removeWhere(ids.contains);
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
