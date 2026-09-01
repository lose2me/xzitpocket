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

  test('loads the fallback bank and caches it locally', () async {
    final repository = LearningRepository(preferencesStorage: storage);

    await repository.load();

    expect(repository.questions, hasLength(8));
    expect(repository.questions.any((question) => question.isMultiple), isTrue);
    expect(storage.getLearningQuestionBankCache(), isNotEmpty);
  });

  test('locks a judged answer and keeps the wrong set', () async {
    final repository = LearningRepository(preferencesStorage: storage);
    await repository.load();
    final question = repository.questions.firstWhere((item) => item.isMultiple);

    expect(await repository.submitAnswer(question.id, {'a'}), isFalse);
    expect(repository.wrongIds, contains(question.id));
    expect(
      await repository.submitAnswer(question.id, question.correctOptionIds),
      isFalse,
    );
    expect(repository.wrongIds, contains(question.id));
  });

  test('does not judge an empty answer', () async {
    final repository = LearningRepository(preferencesStorage: storage);
    await repository.load();
    final question = repository.questions.first;

    expect(
      await repository.submitAnswer(question.id, const <String>{}),
      isFalse,
    );
    expect(repository.isJudged(question.id), isFalse);
  });

  test('favorites and answer state survive a repository reload', () async {
    final first = LearningRepository(preferencesStorage: storage);
    await first.load();
    final question = first.questions.first;
    await first.toggleFavorite(question.id);
    await first.submitAnswer(question.id, question.correctOptionIds);

    final second = LearningRepository(preferencesStorage: storage);
    await second.load();

    expect(second.isFavorite(question.id), isTrue);
    expect(second.isJudged(question.id), isTrue);
    expect(second.isCorrect(question.id), isTrue);
  });

  test(
    'resets answers while preserving wrong and favorite collections',
    () async {
      final repository = LearningRepository(preferencesStorage: storage);
      await repository.load();
      final question = repository.questions.first;

      await repository.toggleFavorite(question.id);
      await repository.submitAnswer(question.id, {'not-correct'});
      expect(repository.wrongIds, contains(question.id));

      await repository.resetProgress();

      expect(repository.isJudged(question.id), isFalse);
      expect(repository.answerFor(question.id), isEmpty);
      expect(repository.wrongIds, contains(question.id));
      expect(repository.favoriteIds, contains(question.id));
    },
  );

  test('can reset only the current question list', () async {
    final repository = LearningRepository(preferencesStorage: storage);
    await repository.load();
    final first = repository.questions[0];
    final second = repository.questions[1];

    await repository.submitAnswer(first.id, first.correctOptionIds);
    await repository.submitAnswer(second.id, second.correctOptionIds);
    await repository.resetProgress([first.id]);

    expect(repository.isJudged(first.id), isFalse);
    expect(repository.isJudged(second.id), isTrue);
  });

  test(
    'parses the questionBank payload and supported question types',
    () async {
      final payload = {
        'questionBank': {
          'year': '2026',
          'name': '计算机基础知识测验',
          'questions': [
            {
              'type': '单选题',
              'title': '第1题',
              'questionText': '以下哪个是计算机的核心部件？',
              'options': ['A. 显示器', 'B. CPU', 'C. 键盘', 'D. 鼠标'],
              'correctAnswer': 'B',
            },
            {
              'type': '多选题',
              'title': '第2题',
              'questionText': '下列哪些属于操作系统？',
              'options': ['A. Windows', 'B. Linux', 'C. macOS', 'D. Photoshop'],
              'correctAnswer': 'A,B,C',
            },
            {
              'type': '判断题',
              'title': '第3题',
              'questionText': 'Python 是一种编译型语言。',
              'options': [],
              'correctAnswer': '错误',
            },
            {
              'type': '填空题',
              'title': '第4题',
              'questionText': '1 GB 等于 ____ MB。',
              'options': [],
              'correctAnswer': '1024',
            },
          ],
        },
      };
      final bank = LearningQuestionBank.fromJson(payload);

      expect(bank.year, 2026);
      expect(bank.name, '计算机基础知识测验');
      expect(bank.questions, hasLength(4));
      expect(bank.questions[0].bankName, '计算机基础知识测验');
      expect(bank.questions[0].type, LearningQuestionType.single);
      expect(bank.questions[0].options[1].id, 'B');
      expect(bank.questions[0].correctOptionIds, {'B'});
      expect(bank.questions[1].type, LearningQuestionType.multiple);
      expect(bank.questions[1].correctOptionIds, {'A', 'B', 'C'});
      expect(bank.questions[2].type, LearningQuestionType.trueFalse);
      expect(bank.questions[2].options, hasLength(2));
      expect(bank.questions[2].correctOptionIds, {'错误'});
      expect(bank.questions[3].type, LearningQuestionType.fillBlank);
      expect(bank.questions[3].questionText, '1 GB 等于 ____ MB。');
      expect(bank.questions[3].correctOptionIds, {'1024'});

      final secondTerm = LearningQuestionBank.fromJson({
        'questionBank': {
          'year': '2025',
          'semester': '2',
          'name': '第二学期题单',
          'questions': <dynamic>[],
        },
      });
      expect(secondTerm.year, 2502);
    },
  );
}
