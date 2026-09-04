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
  final int year;
  final String bankName;
  final String bankId;
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
    required this.year,
    this.bankName = '题库',
    this.bankId = '',
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
    int? fallbackYear,
    String? fallbackId,
    String? fallbackBankName,
    String? fallbackBankId,
    bool? fallbackBankIsNew,
  }) {
    final rawType = json['type']?.toString() ?? 'single';
    final rawYear = json['year'];
    final year = rawYear is num
        ? rawYear.toInt()
        : int.tryParse(rawYear?.toString() ?? '') ??
              fallbackYear ??
              DateTime.now().year;
    final title = json['title']?.toString() ?? '';
    final questionText = json['questionText']?.toString() ?? title;
    final rawQuestionNumber = json['questionNumber'];
    final questionNumber = rawQuestionNumber is num
        ? rawQuestionNumber.toInt()
        : int.tryParse(rawQuestionNumber?.toString() ?? '');
    final bankId = json['bankId']?.toString() ?? fallbackBankId ?? '';
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
      id: json['id']?.toString() ?? fallbackId ?? '$year:$title',
      year: year,
      bankName: json['bankName']?.toString() ?? fallbackBankName ?? '题库',
      bankId: bankId,
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
    'year': year,
    'bankName': bankName,
    if (bankId.isNotEmpty) 'bankId': bankId,
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
  final int year;
  final String name;
  final List<LearningQuestion> questions;

  const LearningQuestionBank({
    this.id = '',
    this.isNew,
    required this.year,
    required this.name,
    required this.questions,
  });

  factory LearningQuestionBank.fromJson(Map<String, dynamic> json) {
    final rawBank = json['questionBank'];
    final bank = rawBank is Map<String, dynamic> ? rawBank : json;
    final rawYear = bank['year'];
    var year = rawYear is num
        ? rawYear.toInt()
        : int.tryParse(rawYear?.toString() ?? '') ?? DateTime.now().year;
    final rawSemester = bank['semester'] ?? bank['term'];
    if (rawSemester != null && year >= 2000 && year <= 2099) {
      final semester = int.tryParse(rawSemester.toString());
      if (semester != null && semester > 0 && semester < 100) {
        year = (year % 100) * 100 + semester;
      }
    }
    final name = bank['name']?.toString() ?? '题库';
    final id = bank['id']?.toString() ?? '$year:$name';
    final isNew = bank['new'] is bool ? bank['new'] as bool : null;
    final rawQuestions = bank['questions'] as List<dynamic>? ?? const [];
    final questions =
        [
          for (var index = 0; index < rawQuestions.length; index++)
            LearningQuestion.fromJson(
              rawQuestions[index] as Map<String, dynamic>,
              fallbackYear: year,
              fallbackId:
                  '$id:${(rawQuestions[index] as Map<String, dynamic>)['questionNumber'] ?? index + 1}',
              fallbackBankName: name,
              fallbackBankId: id,
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
      year: year,
      name: name,
      questions: questions,
    );
  }

  Map<String, dynamic> toJson() => {
    'questionBank': {
      if (id.isNotEmpty) 'id': id,
      if (isNew != null) 'new': isNew,
      'year': year.toString(),
      'name': name,
      'questions': [for (final question in questions) question.toJson()],
    },
  };
}

/// Local fallback data used until the backend question-bank endpoint is wired.
/// The repository accepts a fetcher so the fallback can be replaced without
/// changing any page code.
List<LearningQuestion> defaultLearningQuestions() {
  final questions = <LearningQuestion>[
    LearningQuestion(
      id: 'campus-001',
      year: 2026,
      bankId: 'QB-CAMPUS',
      bankIsNew: true,
      title: '在校园服务中发现设备故障时，最合适的第一步是什么？',
      questionText: '在校园服务中发现设备故障时，最合适的第一步是什么？',
      type: LearningQuestionType.single,
      options: [
        LearningOption(id: 'a', text: '拍照记录现场并提交报修'),
        LearningOption(id: 'b', text: '直接拆开设备检查'),
        LearningOption(id: 'c', text: '等待设备自行恢复'),
        LearningOption(id: 'd', text: '在群聊里留言后不再处理'),
      ],
      correctOptionIds: {'a'},
      explanation: '先记录现场并通过正式渠道报修，便于工作人员定位和跟进。',
    ),
    LearningQuestion(
      id: 'campus-002',
      year: 2026,
      bankId: 'QB-CAMPUS',
      bankIsNew: true,
      title: '以下哪些做法有助于保护校园账号安全？',
      questionText: '以下哪些做法有助于保护校园账号安全？',
      type: LearningQuestionType.multiple,
      options: [
        LearningOption(id: 'a', text: '为不同服务设置不同密码'),
        LearningOption(id: 'b', text: '在公共电脑上勾选记住密码'),
        LearningOption(id: 'c', text: '开启多因素认证（如果服务支持）'),
        LearningOption(id: 'd', text: '不点击来源不明的登录链接'),
      ],
      correctOptionIds: {'a', 'c', 'd'},
      explanation: '分离密码、开启多因素认证和识别钓鱼链接，能降低账号被盗风险。',
    ),
    LearningQuestion(
      id: 'campus-003',
      year: 2026,
      bankId: 'QB-CAMPUS',
      bankIsNew: true,
      title: '查询本学期考试安排时，最应优先核对哪一项信息？',
      questionText: '查询本学期考试安排时，最应优先核对哪一项信息？',
      type: LearningQuestionType.single,
      options: [
        LearningOption(id: 'a', text: '考试科目、时间和地点'),
        LearningOption(id: 'b', text: '同学的昵称'),
        LearningOption(id: 'c', text: '校园卡余额'),
        LearningOption(id: 'd', text: '天气预报颜色'),
      ],
      correctOptionIds: {'a'},
      explanation: '考试科目、时间和地点直接决定是否能按时参加考试。',
    ),
    LearningQuestion(
      id: 'campus-004',
      year: 2026,
      bankId: 'QB-CAMPUS',
      bankIsNew: true,
      title: '下列哪些情况适合使用校园网络管理中的自助诊断？',
      questionText: '下列哪些情况适合使用校园网络管理中的自助诊断？',
      type: LearningQuestionType.multiple,
      options: [
        LearningOption(
          id: 'a',
          text: '已连接校园网但无法访问校内系统',
          imageUrl:
              'https://placehold.co/720x220/e7effa/153b6b?text=Campus+Network',
        ),
        LearningOption(id: 'b', text: '忘记了个人银行卡密码'),
        LearningOption(id: 'c', text: '需要检查认证状态或重新认证'),
        LearningOption(id: 'd', text: '所有网站都能正常访问且没有异常'),
      ],
      correctOptionIds: {'a', 'c'},
      explanation: '自助诊断适合处理校园网连接、认证和校内访问异常。',
    ),
    LearningQuestion(
      id: 'campus-005',
      year: 2025,
      bankId: 'QB-CAMPUS',
      bankIsNew: true,
      title: '使用校园卡消费后，发现余额显示异常，应该怎么做？',
      questionText: '使用校园卡消费后，发现余额显示异常，应该怎么做？',
      type: LearningQuestionType.single,
      options: [
        LearningOption(id: 'a', text: '通过一卡通查询核对最近交易记录'),
        LearningOption(id: 'b', text: '连续刷卡直到余额恢复'),
        LearningOption(id: 'c', text: '把卡交给陌生人代查'),
        LearningOption(id: 'd', text: '删除所有查询记录'),
      ],
      correctOptionIds: {'a'},
      explanation: '先核对交易记录，再根据记录联系服务窗口处理。',
    ),
    LearningQuestion(
      id: 'campus-006',
      year: 2025,
      bankId: 'QB-CAMPUS',
      bankIsNew: true,
      title: '提交报修单时，哪些信息可以帮助维修人员更快处理？',
      questionText: '提交报修单时，哪些信息可以帮助维修人员更快处理？',
      type: LearningQuestionType.multiple,
      options: [
        LearningOption(id: 'a', text: '准确的楼栋、房间或设备位置'),
        LearningOption(id: 'b', text: '故障出现的时间和现象'),
        LearningOption(id: 'c', text: '可联系到报修人的方式'),
        LearningOption(id: 'd', text: '与故障无关的个人隐私'),
      ],
      correctOptionIds: {'a', 'b', 'c'},
      explanation: '位置、故障现象和联系方式是定位与沟通所需的关键信息。',
    ),
    LearningQuestion(
      id: 'campus-007',
      year: 2025,
      bankId: 'QB-CAMPUS',
      bankIsNew: true,
      title: '查看电费时，显示“请先设置宿舍号”通常意味着什么？',
      questionText: '查看电费时，显示“请先设置宿舍号”通常意味着什么？',
      type: LearningQuestionType.single,
      options: [
        LearningOption(id: 'a', text: '需要先在“我的”中保存宿舍号'),
        LearningOption(id: 'b', text: '校园卡已被冻结'),
        LearningOption(id: 'c', text: '考试成绩尚未发布'),
        LearningOption(id: 'd', text: '手机需要开启飞行模式'),
      ],
      correctOptionIds: {'a'},
      explanation: '电费查询依赖宿舍号，保存后才能定位对应房间的用电数据。',
    ),
    LearningQuestion(
      id: 'campus-008',
      year: 2025,
      bankId: 'QB-CAMPUS',
      bankIsNew: true,
      title: '处理个人学习数据时，以下哪些做法更稳妥？',
      questionText: '处理个人学习数据时，以下哪些做法更稳妥？',
      type: LearningQuestionType.multiple,
      options: [
        LearningOption(id: 'a', text: '只在可信设备上登录账号'),
        LearningOption(id: 'b', text: '将含学号的截图公开发布'),
        LearningOption(id: 'c', text: '离开公共设备前退出账号'),
        LearningOption(id: 'd', text: '分享前遮挡不必要的个人信息'),
      ],
      correctOptionIds: {'a', 'c', 'd'},
      explanation: '可信设备、及时退出和最小化公开信息，都能减少隐私泄露。',
    ),
    LearningQuestion(
      id: 'qb001-001',
      year: 2024,
      bankName: '计算机基础知识测验',
      bankId: 'QB-001',
      questionNumber: 1,
      title: '第1题',
      questionText: '以下哪个是计算机的核心部件？',
      type: LearningQuestionType.single,
      options: [
        LearningOption(id: 'A', text: 'A. 显示器'),
        LearningOption(id: 'B', text: 'B. CPU'),
        LearningOption(id: 'C', text: 'C. 键盘'),
        LearningOption(id: 'D', text: 'D. 鼠标'),
      ],
      correctOptionIds: {'B'},
    ),
    LearningQuestion(
      id: 'qb001-002',
      year: 2024,
      bankName: '计算机基础知识测验',
      bankId: 'QB-001',
      questionNumber: 2,
      title: '第2题',
      questionText: '下列哪些属于操作系统？',
      type: LearningQuestionType.multiple,
      options: [
        LearningOption(id: 'A', text: 'A. Windows'),
        LearningOption(id: 'B', text: 'B. Linux'),
        LearningOption(id: 'C', text: 'C. macOS'),
        LearningOption(id: 'D', text: 'D. Photoshop'),
      ],
      correctOptionIds: {'A', 'B', 'C'},
    ),
    LearningQuestion(
      id: 'qb001-003',
      year: 2024,
      bankName: '计算机基础知识测验',
      bankId: 'QB-001',
      questionNumber: 3,
      title: '第3题',
      questionText: 'Python 是一种编译型语言。',
      type: LearningQuestionType.trueFalse,
      options: [
        LearningOption(id: '正确', text: '正确'),
        LearningOption(id: '错误', text: '错误'),
      ],
      correctOptionIds: {'错误'},
    ),
    LearningQuestion(
      id: 'qb001-004',
      year: 2024,
      bankName: '计算机基础知识测验',
      bankId: 'QB-001',
      questionNumber: 4,
      title: '第4题',
      questionText: '1 GB 等于 ____ MB。',
      type: LearningQuestionType.fillBlank,
      options: [],
      correctOptionIds: {'1024'},
    ),
    LearningQuestion(
      id: 'qb002-001',
      year: 2023,
      bankName: '网络安全基础测验',
      bankId: 'QB-002',
      questionNumber: 1,
      title: '第1题',
      questionText: '以下哪种密码设置方式更安全？',
      type: LearningQuestionType.single,
      options: [
        LearningOption(id: 'A', text: 'A. 使用生日作为密码'),
        LearningOption(id: 'B', text: 'B. 使用随机长密码并定期更新'),
        LearningOption(id: 'C', text: 'C. 所有网站使用同一个密码'),
        LearningOption(id: 'D', text: 'D. 将密码写在桌面便签上'),
      ],
      correctOptionIds: {'B'},
    ),
    LearningQuestion(
      id: 'qb002-002',
      year: 2023,
      bankName: '网络安全基础测验',
      bankId: 'QB-002',
      questionNumber: 2,
      title: '第2题',
      questionText: '下列哪些做法有助于保护个人账号？',
      type: LearningQuestionType.multiple,
      options: [
        LearningOption(id: 'A', text: 'A. 开启多因素认证'),
        LearningOption(id: 'B', text: 'B. 点击来源不明的链接'),
        LearningOption(id: 'C', text: 'C. 使用密码管理器'),
        LearningOption(id: 'D', text: 'D. 及时安装安全更新'),
      ],
      correctOptionIds: {'A', 'C', 'D'},
    ),
    LearningQuestion(
      id: 'qb002-003',
      year: 2023,
      bankName: '网络安全基础测验',
      bankId: 'QB-002',
      questionNumber: 3,
      title: '第3题',
      questionText: 'HTTPS 可以加密浏览器与网站之间的通信。',
      type: LearningQuestionType.trueFalse,
      options: [
        LearningOption(id: '正确', text: '正确'),
        LearningOption(id: '错误', text: '错误'),
      ],
      correctOptionIds: {'正确'},
    ),
    LearningQuestion(
      id: 'qb002-004',
      year: 2023,
      bankName: '网络安全基础测验',
      bankId: 'QB-002',
      questionNumber: 4,
      title: '第4题',
      questionText: '登录时除了密码，还要求输入验证码，这属于____认证。',
      type: LearningQuestionType.fillBlank,
      options: [],
      correctOptionIds: {'双因素'},
    ),
    LearningQuestion(
      id: 'qb003-001',
      year: 2022,
      bankName: '程序设计基础练习',
      bankId: 'QB-003',
      questionNumber: 1,
      title: '第1题',
      questionText: '在大多数编程语言中，数组下标通常从哪个数字开始？',
      type: LearningQuestionType.single,
      options: [
        LearningOption(id: 'A', text: 'A. 0'),
        LearningOption(id: 'B', text: 'B. 1'),
        LearningOption(id: 'C', text: 'C. -1'),
        LearningOption(id: 'D', text: 'D. 由编译器随机决定'),
      ],
      correctOptionIds: {'A'},
    ),
    LearningQuestion(
      id: 'qb003-002',
      year: 2022,
      bankName: '程序设计基础练习',
      bankId: 'QB-003',
      questionNumber: 2,
      title: '第2题',
      questionText: '下列哪些属于常见的基本数据结构？',
      type: LearningQuestionType.multiple,
      options: [
        LearningOption(id: 'A', text: 'A. 数组'),
        LearningOption(id: 'B', text: 'B. 链表'),
        LearningOption(id: 'C', text: 'C. 栈'),
        LearningOption(id: 'D', text: 'D. 显示器'),
      ],
      correctOptionIds: {'A', 'B', 'C'},
    ),
    LearningQuestion(
      id: 'qb003-003',
      year: 2022,
      bankName: '程序设计基础练习',
      bankId: 'QB-003',
      questionNumber: 3,
      title: '第3题',
      questionText: '二进制数只使用 0 和 1 两个数字。',
      type: LearningQuestionType.trueFalse,
      options: [
        LearningOption(id: '正确', text: '正确'),
        LearningOption(id: '错误', text: '错误'),
      ],
      correctOptionIds: {'正确'},
    ),
    LearningQuestion(
      id: 'qb003-004',
      year: 2022,
      bankName: '程序设计基础练习',
      bankId: 'QB-003',
      questionNumber: 4,
      title: '第4题',
      questionText: 'HTML 的中文名称是超文本____语言。',
      type: LearningQuestionType.fillBlank,
      options: [],
      correctOptionIds: {'标记'},
    ),
  ];
  questions.addAll(_largePracticeQuestions());
  return questions;
}

List<LearningQuestion> _largePracticeQuestions() => List.generate(104, (index) {
  final number = index + 1;
  final bankId = 'QB-100';
  switch (index % 4) {
    case 0:
      return LearningQuestion(
        id: '$bankId-$number',
        year: 2021,
        bankName: '综合能力训练 100+',
        bankId: bankId,
        questionNumber: number,
        title: '第$number题',
        questionText: '下列哪项最符合计算机系统的基本工作原理？',
        type: LearningQuestionType.single,
        options: const [
          LearningOption(id: 'A', text: '输入、处理、输出'),
          LearningOption(id: 'B', text: '只显示结果'),
          LearningOption(id: 'C', text: '只保存文件'),
          LearningOption(id: 'D', text: '只执行打印'),
        ],
        correctOptionIds: const {'A'},
      );
    case 1:
      return LearningQuestion(
        id: '$bankId-$number',
        year: 2021,
        bankName: '综合能力训练 100+',
        bankId: bankId,
        questionNumber: number,
        title: '第$number题',
        questionText: '下列哪些属于良好的信息处理习惯？',
        type: LearningQuestionType.multiple,
        options: const [
          LearningOption(id: 'A', text: '定期备份重要数据'),
          LearningOption(id: 'B', text: '为文件分类命名'),
          LearningOption(id: 'C', text: '随意共享账号密码'),
          LearningOption(id: 'D', text: '及时更新软件'),
        ],
        correctOptionIds: const {'A', 'B', 'D'},
      );
    case 2:
      return LearningQuestion(
        id: '$bankId-$number',
        year: 2021,
        bankName: '综合能力训练 100+',
        bankId: bankId,
        questionNumber: number,
        title: '第$number题',
        questionText: '二进制是计算机中常用的数制。',
        type: LearningQuestionType.trueFalse,
        options: const [
          LearningOption(id: 'A', text: '正确'),
          LearningOption(id: 'B', text: '错误'),
        ],
        correctOptionIds: const {'A'},
      );
    default:
      return LearningQuestion(
        id: '$bankId-$number',
        year: 2021,
        bankName: '综合能力训练 100+',
        bankId: bankId,
        questionNumber: number,
        title: '第$number题',
        questionText: '1 KB 等于 ____ 字节。',
        type: LearningQuestionType.fillBlank,
        options: const [],
        correctOptionIds: const {'1024'},
      );
  }
});
