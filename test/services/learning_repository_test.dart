import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/learning_question.dart';
import 'package:xzitpocket/services/learning_repository.dart';
import 'package:xzitpocket/services/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferencesStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage();
    await storage.init();
  });

  LearningRepository repository() => LearningRepository(
    preferencesStorage: storage,
    fetcher: () async => _fixtureQuestions(),
  );

  test(
    'loads only questions returned by the configured control fetcher',
    () async {
      final value = repository();
      await value.load();

      expect(value.questions, hasLength(8));
      expect(value.questions.any((question) => question.isMultiple), isTrue);
      expect(value.questions.any((question) => question.isTrueFalse), isTrue);
      expect(value.questions.any((question) => question.isFillBlank), isTrue);
      expect(storage.getLearningQuestionBankCache(), isNull);
    },
  );

  test('does not create local questions when control is unavailable', () async {
    final value = LearningRepository(
      preferencesStorage: storage,
      fetcher: () async => throw StateError('offline'),
    );
    await value.load();

    expect(value.questions, isEmpty);
    expect(storage.getLearningQuestionBankCache(), isNull);
  });

  test(
    'keeps locked active banks visible without loading their questions',
    () async {
      final value = LearningRepository(
        preferencesStorage: storage,
        bankFetcher: () async => [
          const LearningQuestionBank(
            id: 'QB-LOCKED',
            name: '受保护题库',
            isNew: true,
            orderId: 1,
            requiresCDK: true,
            locked: true,
            questions: [],
          ),
        ],
      );

      await value.load();

      expect(value.banks, hasLength(1));
      expect(value.banks.single.locked, isTrue);
      expect(value.banks.single.requiresCDK, isTrue);
      expect(value.questions, isEmpty);
    },
  );

  test('locks a judged answer and keeps the wrong set', () async {
    final value = repository();
    await value.load();
    final question = value.questions.firstWhere((item) => item.isMultiple);

    expect(await value.submitAnswer(question.id, {'A'}), isFalse);
    expect(value.wrongIds, contains(question.id));
    expect(
      await value.submitAnswer(question.id, question.correctOptionIds),
      isFalse,
    );
    expect(value.wrongIds, contains(question.id));
  });

  test('does not judge an empty answer', () async {
    final value = repository();
    await value.load();
    final question = value.questions.first;

    expect(await value.submitAnswer(question.id, const <String>{}), isFalse);
    expect(value.isJudged(question.id), isFalse);
  });

  test('favorites and answer state survive a repository reload', () async {
    final first = repository();
    await first.load();
    final question = first.questions.first;
    await first.toggleFavorite(question.id);
    await first.submitAnswer(question.id, question.correctOptionIds);

    final second = repository();
    await second.load();

    expect(second.isFavorite(question.id), isTrue);
    expect(second.isJudged(question.id), isTrue);
    expect(second.isCorrect(question.id), isTrue);
  });

  test(
    'resets answers while preserving wrong and favorite collections',
    () async {
      final value = repository();
      await value.load();
      final question = value.questions.first;

      await value.toggleFavorite(question.id);
      await value.submitAnswer(question.id, {'not-correct'});
      await value.resetProgress();

      expect(value.isJudged(question.id), isFalse);
      expect(value.answerFor(question.id), isEmpty);
      expect(value.wrongIds, contains(question.id));
      expect(value.favoriteIds, contains(question.id));
    },
  );

  test('can reset only the current question list', () async {
    final value = repository();
    await value.load();
    final first = value.questions[0];
    final second = value.questions[1];

    await value.submitAnswer(first.id, first.correctOptionIds);
    await value.submitAnswer(second.id, second.correctOptionIds);
    await value.resetProgress([first.id]);

    expect(value.isJudged(first.id), isFalse);
    expect(value.isJudged(second.id), isTrue);
  });

  test('tracks recent judged questions in order', () async {
    final value = repository();
    await value.load();
    final questions = value.questions;

    for (final question in questions.take(7)) {
      await value.submitAnswer(question.id, question.correctOptionIds);
    }

    expect(
      value.recentJudgedIds(questions.map((question) => question.id)),
      questions.skip(1).take(6).map((question) => question.id).toList(),
    );
  });

  test(
    'parses the control questionBank payload and supported question types',
    () {
      final bank = LearningQuestionBank.fromJson({
        'questionBank': {
          'id': 'QB-001',
          'orderId': 12,
          'new': true,
          'name': '计算机基础知识测验',
          'questions': [
            {
              'questionNumber': 1,
              'type': '单选题',
              'title': '第1题',
              'questionText': '核心部件？',
              'options': [
                {'label': 'A', 'text': '显示器'},
                {'label': 'B', 'text': 'CPU'},
              ],
              'correctAnswer': 'B',
            },
            {
              'questionNumber': 2,
              'type': '多选题',
              'title': '第2题',
              'questionText': '操作系统？',
              'options': [
                {'label': 'A', 'text': 'Windows'},
                {'label': 'B', 'text': 'Linux'},
              ],
              'correctAnswer': 'A,B',
            },
            {
              'questionNumber': 3,
              'type': '判断题',
              'title': '第3题',
              'questionText': '判断',
              'options': [],
              'correctAnswer': '正确',
            },
            {
              'questionNumber': 4,
              'type': '填空题',
              'title': '第4题',
              'questionText': '答案？',
              'options': [],
              'correctAnswer': '1024',
            },
          ],
        },
      });

      expect(bank.id, 'QB-001');
      expect(bank.orderId, 12);
      expect(bank.questions, hasLength(4));
      expect(bank.questions.first.bankOrderId, 12);
      expect(bank.questions[0].correctOptionIds, {'B'});
      expect(bank.questions[1].correctOptionIds, {'A', 'B'});
      expect(bank.questions[2].correctOptionIds, {'正确'});
      expect(bank.questions[3].correctOptionIds, {'1024'});
    },
  );
}

List<LearningQuestion> _fixtureQuestions() => [
  LearningQuestion(
    id: 'remote-1',
    bankName: '在线题库',
    bankId: 'QB-REMOTE',
    bankOrderId: 1,
    bankIsNew: true,
    questionNumber: 1,
    title: '单选',
    questionText: '单选',
    type: LearningQuestionType.single,
    options: const [
      LearningOption(id: 'A', text: 'A'),
      LearningOption(id: 'B', text: 'B'),
    ],
    correctOptionIds: {'A'},
  ),
  LearningQuestion(
    id: 'remote-2',
    bankName: '在线题库',
    bankId: 'QB-REMOTE',
    bankOrderId: 1,
    bankIsNew: true,
    questionNumber: 2,
    title: '多选',
    questionText: '多选',
    type: LearningQuestionType.multiple,
    options: const [
      LearningOption(id: 'A', text: 'A'),
      LearningOption(id: 'B', text: 'B'),
    ],
    correctOptionIds: {'A', 'B'},
  ),
  LearningQuestion(
    id: 'remote-3',
    bankName: '在线题库',
    bankId: 'QB-REMOTE',
    bankOrderId: 1,
    bankIsNew: true,
    questionNumber: 3,
    title: '判断',
    questionText: '判断',
    type: LearningQuestionType.trueFalse,
    options: const [
      LearningOption(id: '正确', text: '正确'),
      LearningOption(id: '错误', text: '错误'),
    ],
    correctOptionIds: {'正确'},
  ),
  LearningQuestion(
    id: 'remote-4',
    bankName: '在线题库',
    bankId: 'QB-REMOTE',
    bankOrderId: 1,
    bankIsNew: true,
    questionNumber: 4,
    title: '填空',
    questionText: '填空',
    type: LearningQuestionType.fillBlank,
    options: const [],
    correctOptionIds: {'答案'},
  ),
  for (var index = 5; index <= 8; index++)
    LearningQuestion(
      id: 'remote-$index',
      bankName: '在线题库',
      bankId: 'QB-REMOTE',
      bankOrderId: 1,
      bankIsNew: true,
      questionNumber: index,
      title: '题目$index',
      questionText: '题目$index',
      type: LearningQuestionType.single,
      options: const [LearningOption(id: 'A', text: 'A')],
      correctOptionIds: {'A'},
    ),
];
