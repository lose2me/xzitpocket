enum LearningQuestionType { single, multiple, trueFalse, fillBlank }

class LearningOption {
  final String id;
  final String text;
  final String? imageUrl;

  const LearningOption({required this.id, required this.text, this.imageUrl});

  factory LearningOption.fromJson(dynamic json, {int index = 0}) {
    if (json is String) {
      final text = json.trim();
      final match = RegExp(r'^([A-Za-z])(?:[.、)）:\s]+)(.*)$').firstMatch(text);
      if (match != null) {
        return LearningOption(id: match.group(1)!.toUpperCase(), text: text);
      }
      return LearningOption(id: '${index + 1}', text: text);
    }
    final map = json as Map<String, dynamic>;
    return LearningOption(
      id: map['label']?.toString() ?? map['id']?.toString() ?? '${index + 1}',
      text: map['text']?.toString() ?? '',
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
}

class LearningQuestion {
  final String id;
  final String bankName;
  final String bankId;
  final int? bankOrderId;
  final bool? bankIsNew;
  final int? questionNumber;
  final String title;
  final String questionText;
  final String? explanation;
  final LearningQuestionType type;
  final List<LearningOption> options;
  final Set<String> correctOptionIds;

  const LearningQuestion({
    required this.id,
    this.bankName = '题库',
    this.bankId = '',
    this.bankOrderId,
    this.bankIsNew,
    this.questionNumber,
    required this.title,
    String? questionText,
    required this.type,
    required this.options,
    required this.correctOptionIds,
    this.explanation,
  }) : questionText = questionText ?? title;

  bool get isMultiple => type == LearningQuestionType.multiple;
  bool get isTrueFalse => type == LearningQuestionType.trueFalse;
  bool get isFillBlank => type == LearningQuestionType.fillBlank;

  String get typeLabel => switch (type) {
    LearningQuestionType.single => '单选题',
    LearningQuestionType.multiple => '多选题',
    LearningQuestionType.trueFalse => '判断题',
    LearningQuestionType.fillBlank => '填空题',
  };

  factory LearningQuestion.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
    String? fallbackBankName,
    String? fallbackBankId,
    int? fallbackBankOrderId,
    bool? fallbackBankIsNew,
  }) {
    final rawType = json['type']?.toString() ?? 'single';
    final title = json['title']?.toString() ?? '';
    final questionText = json['questionText']?.toString() ?? title;
    final rawQuestionNumber = json['questionNumber'];
    final questionNumber = rawQuestionNumber is num
        ? rawQuestionNumber.toInt()
        : int.tryParse(rawQuestionNumber?.toString() ?? '');
    final bankId = json['bankId']?.toString() ?? fallbackBankId ?? '';
    final rawBankOrderId = json['bankOrderId'] ?? json['orderId'];
    final bankOrderId = rawBankOrderId is num
        ? rawBankOrderId.toInt()
        : int.tryParse(rawBankOrderId?.toString() ?? '') ?? fallbackBankOrderId;
    final bankIsNew = json['bankNew'] is bool
        ? json['bankNew'] as bool
        : json['isNew'] is bool
        ? json['isNew'] as bool
        : fallbackBankIsNew;
    final type = _parseType(rawType);
    final rawOptions = json['options'] as List<dynamic>? ?? const [];
    final options = [
      for (var index = 0; index < rawOptions.length; index++)
        LearningOption.fromJson(rawOptions[index], index: index),
    ];
    if (type == LearningQuestionType.trueFalse && options.isEmpty) {
      options.addAll(const [
        LearningOption(id: '正确', text: '正确'),
        LearningOption(id: '错误', text: '错误'),
      ]);
    } else if (type == LearningQuestionType.trueFalse) {
      for (var index = 0; index < options.length; index++) {
        final option = options[index];
        final normalizedText = _normalizeTrueFalse(
          option.text.replaceFirst(RegExp(r'^[A-Za-z][.、)）:\s]+'), ''),
          fallback: option.id,
        );
        final optionId = RegExp(r'^[A-Za-z]$').hasMatch(option.id.trim())
            ? option.id.trim().toUpperCase()
            : normalizedText;
        options[index] = LearningOption(
          id: optionId,
          text: option.text,
          imageUrl: option.imageUrl,
        );
      }
    }
    final rawCorrectIds = json['correctOptionIds'];
    final rawCorrectAnswer = json['correctAnswer'];
    final parsedCorrectOptionIds = rawCorrectIds is List
        ? {for (final value in rawCorrectIds) value.toString().trim()}
        : _parseCorrectAnswer(rawCorrectAnswer, type);
    final correctOptionIds = _resolveCorrectOptionIds(
      parsedCorrectOptionIds,
      options,
    );
    return LearningQuestion(
      id: json['id']?.toString() ?? fallbackId ?? title,
      bankName: json['bankName']?.toString() ?? fallbackBankName ?? '题库',
      bankId: bankId,
      bankOrderId: bankOrderId,
      bankIsNew: bankIsNew,
      questionNumber: questionNumber,
      title: title.isEmpty ? questionText : title,
      questionText: questionText,
      explanation: json['explanation'] as String?,
      type: type,
      options: options,
      correctOptionIds: correctOptionIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bankName': bankName,
    if (bankId.isNotEmpty) 'bankId': bankId,
    if (bankOrderId != null) 'bankOrderId': bankOrderId,
    if (bankIsNew != null) 'bankNew': bankIsNew,
    if (questionNumber != null) 'questionNumber': questionNumber,
    'title': title,
    'questionText': questionText,
    if (explanation != null) 'explanation': explanation,
    'type': type.name,
    'options': [for (final option in options) option.toJson()],
    'correctOptionIds': correctOptionIds.toList(),
  };

  static LearningQuestionType _parseType(String value) {
    return switch (value.trim().toLowerCase()) {
      'multiple' || '多选题' || '多选' => LearningQuestionType.multiple,
      'truefalse' ||
      'true_false' ||
      '判断题' ||
      '判断' => LearningQuestionType.trueFalse,
      'fillblank' ||
      'fill_blank' ||
      '填空题' ||
      '填空' => LearningQuestionType.fillBlank,
      _ => LearningQuestionType.single,
    };
  }

  static Set<String> _parseCorrectAnswer(
    dynamic value,
    LearningQuestionType type,
  ) {
    if (value is List) {
      return {for (final item in value) item.toString().trim()};
    }
    final answer = value?.toString().trim() ?? '';
    if (answer.isEmpty) return <String>{};
    if (type == LearningQuestionType.multiple) {
      return {
        for (final item in answer.split(RegExp(r'[,，、]')))
          if (item.trim().isNotEmpty) item.trim(),
      };
    }
    if (type == LearningQuestionType.trueFalse) {
      return {_normalizeTrueFalse(answer, fallback: answer)};
    }
    return {answer};
  }

  static Set<String> _resolveCorrectOptionIds(
    Set<String> values,
    List<LearningOption> options,
  ) {
    if (values.isEmpty || options.isEmpty) return values;
    final resolved = <String>{};
    for (final value in values) {
      final normalized = value.trim().toLowerCase();
      final match = options.where((option) {
        final id = option.id.trim().toLowerCase();
        final text = option.text
            .replaceFirst(RegExp(r'^[A-Za-z][.、)）:\s]+'), '')
            .trim()
            .toLowerCase();
        return id == normalized || text == normalized;
      }).firstOrNull;
      resolved.add(match?.id ?? value.trim());
    }
    return resolved;
  }

  static String _normalizeTrueFalse(String value, {required String fallback}) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      '正确' || '对' || 'true' => '正确',
      '错误' || '错' || 'false' => '错误',
      _ => fallback,
    };
  }
}

class LearningQuestionBank {
  final String id;
  final bool? isNew;
  final String name;
  final int? orderId;
  final bool requiresCDK;
  final bool locked;
  final List<LearningQuestion> questions;

  const LearningQuestionBank({
    this.id = '',
    this.isNew,
    required this.name,
    this.orderId,
    this.requiresCDK = false,
    this.locked = false,
    required this.questions,
  });

  factory LearningQuestionBank.fromJson(Map<String, dynamic> json) {
    final rawBank = json['questionBank'];
    final bank = rawBank is Map<String, dynamic> ? rawBank : json;
    final name = bank['name']?.toString() ?? '题库';
    final id = bank['id']?.toString() ?? name;
    final rawOrderId = bank['orderId'];
    final orderId = rawOrderId is num
        ? rawOrderId.toInt()
        : int.tryParse(rawOrderId?.toString() ?? '');
    final isNew = bank['new'] is bool ? bank['new'] as bool : null;
    final requiresCDK = bank['requiresCDK'] == true;
    final locked = bank['locked'] == true;
    final rawQuestions = bank['questions'] as List<dynamic>? ?? const [];
    final questions =
        [
          for (var index = 0; index < rawQuestions.length; index++)
            LearningQuestion.fromJson(
              rawQuestions[index] as Map<String, dynamic>,
              fallbackId:
                  '$id:${(rawQuestions[index] as Map<String, dynamic>)['questionNumber'] ?? index + 1}',
              fallbackBankName: name,
              fallbackBankId: id,
              fallbackBankOrderId: orderId,
              fallbackBankIsNew: isNew,
            ),
        ]..sort((a, b) {
          final aNumber = a.questionNumber;
          final bNumber = b.questionNumber;
          if (aNumber != null && bNumber != null) {
            return aNumber.compareTo(bNumber);
          }
          if (aNumber != null) return -1;
          if (bNumber != null) return 1;
          return 0;
        });
    return LearningQuestionBank(
      id: id,
      isNew: isNew,
      name: name,
      orderId: orderId,
      requiresCDK: requiresCDK,
      locked: locked,
      questions: questions,
    );
  }

  Map<String, dynamic> toJson() => {
    'questionBank': {
      if (id.isNotEmpty) 'id': id,
      if (isNew != null) 'new': isNew,
      'name': name,
      if (orderId != null) 'orderId': orderId,
      if (requiresCDK) 'requiresCDK': true,
      if (locked) 'locked': true,
      'questions': [for (final question in questions) question.toJson()],
    },
  };
}
