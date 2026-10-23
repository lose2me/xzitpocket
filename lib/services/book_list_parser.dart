import 'dart:convert';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../models/academic.dart';
import '../models/book_list.dart';

BookListResult parseBookListPayload(dynamic payload) {
  if (payload is Map) {
    final rawItems = payload['items'] ?? payload['data'] ?? payload['rows'];
    if (rawItems is List) {
      return _bookListFromMaps(rawItems);
    }
  }
  if (payload is List) return _bookListFromMaps(payload);

  final source = payload?.toString() ?? '';
  if (source.trim().isEmpty) {
    return const BookListResult(items: []);
  }
  try {
    final decoded = jsonDecode(source);
    if (!identical(decoded, payload)) return parseBookListPayload(decoded);
  } catch (_) {
    // The endpoint normally returns HTML. Continue with table parsing.
  }

  final document = html_parser.parse(source);
  final candidates = document.querySelectorAll('table');
  html_dom.Element? selected;
  var selectedScore = 0;
  for (final table in candidates) {
    final rows = table.querySelectorAll('tr');
    final score = rows.fold<int>(0, (total, row) {
      final cells = row.querySelectorAll('th, td').length;
      return total + (cells >= 2 ? cells : 0);
    });
    if (score > selectedScore) {
      selected = table;
      selectedScore = score;
    }
  }
  final rows =
      selected?.querySelectorAll('tr') ?? document.querySelectorAll('tr');
  if (rows.isEmpty) {
    return const BookListResult(items: []);
  }

  final values = [
    for (final row in rows)
      [
        for (final cell in row.querySelectorAll('th, td'))
          _bookTableCellText(cell),
      ],
  ].where((row) => row.any((value) => value.isNotEmpty)).toList();
  if (values.isEmpty) {
    return const BookListResult(items: []);
  }

  final headerRow = values.first;
  final hasHeaderCells = rows.first.querySelectorAll('th').isNotEmpty;
  final columnCount = values.fold<int>(
    headerRow.length,
    (max, row) => row.length > max ? row.length : max,
  );
  final columns = hasHeaderCells
      ? [
          for (var index = 0; index < columnCount; index++)
            index < headerRow.length && headerRow[index].trim().isNotEmpty
                ? headerRow[index]
                : '字段 ${index + 1}',
        ]
      : [for (var index = 0; index < columnCount; index++) '字段 ${index + 1}'];
  final dataRows = hasHeaderCells ? values.skip(1) : values;
  return _bookListFromMaps([
    for (final row in dataRows)
      {
        for (var index = 0; index < columns.length; index++)
          columns[index]: index < row.length ? row[index] : '',
      },
  ]);
}

BookListSemesterCatalog buildBookListSemesterCatalog(
  GradeResult grades,
  String studentId,
) {
  final enrollmentYear = _studentEnrollmentYear(studentId);
  if (enrollmentYear == null) {
    return const BookListSemesterCatalog(options: []);
  }

  final completed = <({int academicYear, int term})>[];
  for (final yearLabel in grades.years) {
    final academicYear = _academicYearStart(yearLabel);
    if (academicYear == null) continue;
    for (final termLabel in grades.termsByYear[yearLabel] ?? const <String>[]) {
      final term = _gradeTermNumber(termLabel);
      if (term != null) completed.add((academicYear: academicYear, term: term));
    }
  }

  final latest = completed.isEmpty
      ? null
      : (completed..sort(_compareAcademicTerms)).last;
  final currentTerm = latest == null
      ? (academicYear: enrollmentYear, term: 1)
      : _nextAcademicTerm(latest);

  final semesters = <String, BookListSemesterOption>{};
  for (
    var academicYear = enrollmentYear;
    academicYear <= currentTerm.academicYear;
    academicYear++
  ) {
    final lastTerm = academicYear == currentTerm.academicYear
        ? currentTerm.term
        : 2;
    for (var term = 1; term <= lastTerm; term++) {
      final option = _bookSemesterOption(
        academicYear,
        term,
        enrollmentYear: enrollmentYear,
      );
      semesters[option.key] = option;
    }
  }

  final current = _bookSemesterOption(
    currentTerm.academicYear,
    currentTerm.term,
    enrollmentYear: enrollmentYear,
  );
  final options = semesters.values.toList()..sort(_compareBookSemesters);
  return BookListSemesterCatalog(options: options, current: current);
}

int? _gradeTermNumber(String value) {
  final term = value.trim();
  if (term == '1' || term == '3' || term.contains('一')) return 1;
  if (term == '2' || term == '12' || term.contains('二')) return 2;
  final number = int.tryParse(term);
  return number == 1 || number == 2 ? number : null;
}

int? _academicYearStart(String value) =>
    int.tryParse(RegExp(r'20\d{2}').firstMatch(value)?.group(0) ?? '');

int _compareAcademicTerms(
  ({int academicYear, int term}) left,
  ({int academicYear, int term}) right,
) {
  final yearOrder = left.academicYear.compareTo(right.academicYear);
  return yearOrder == 0 ? left.term.compareTo(right.term) : yearOrder;
}

({int academicYear, int term}) _nextAcademicTerm(
  ({int academicYear, int term}) value,
) => value.term == 1
    ? (academicYear: value.academicYear, term: 2)
    : (academicYear: value.academicYear + 1, term: 1);

int? _studentEnrollmentYear(String studentId) {
  final value = studentId.trim();
  final fullYear = RegExp(r'^(20\d{2})').firstMatch(value)?.group(1);
  if (fullYear != null) return int.tryParse(fullYear);
  final shortYear = RegExp(r'^(\d{2})').firstMatch(value)?.group(1);
  final parsed = int.tryParse(shortYear ?? '');
  return parsed == null ? null : 2000 + parsed;
}

BookListSemesterOption _bookSemesterOption(
  int academicYear,
  int term, {
  required int enrollmentYear,
}) {
  final yearLevel = academicYear - enrollmentYear + 1;
  final yearLabel = switch (yearLevel) {
    1 => '大一',
    2 => '大二',
    3 => '大三',
    4 => '大四',
    _ => '大${yearLevel.clamp(1, 9)}',
  };
  return BookListSemesterOption(
    academicYear: academicYear.toString(),
    termCode: term == 1 ? '3' : '12',
    label: '$yearLabel${term == 1 ? '上' : '下'}学期',
  );
}

int _compareBookSemesters(
  BookListSemesterOption left,
  BookListSemesterOption right,
) {
  final yearOrder = int.parse(right.academicYear)
      .compareTo(int.parse(left.academicYear));
  if (yearOrder != 0) return yearOrder;
  final leftTerm = left.termCode == '12' ? 2 : 1;
  final rightTerm = right.termCode == '12' ? 2 : 1;
  return rightTerm.compareTo(leftTerm);
}

BookListResult _bookListFromMaps(List<dynamic> rawItems) {
  final items = <BookListItem>[];
  for (final raw in rawItems) {
    if (raw is! Map) continue;
    final fields = <String, String>{
      for (final entry in raw.entries)
        _normalizeBookFieldName(entry.key.toString()):
            entry.value?.toString() ?? '',
    };
    final courseName = _cleanBookText(
      _firstBookField(fields, const ['kcmc', '课程名称', '课程']),
    );
    if (courseName.isEmpty) continue;
    final textbook = _firstBookField(fields, const ['jcxx', '教材信息', '教材']);
    for (final entry in _splitTextbookEntries(textbook)) {
      final parts = entry.split('/');
      final textbookName = parts.isEmpty ? '' : parts.first.trim();
      if (textbookName.isEmpty) continue;
      final tags = [
        for (final part in parts.skip(1))
          if (part.trim().isNotEmpty) part.trim(),
      ];
      items.add(
        BookListItem(
          courseName: courseName,
          textbookName: textbookName,
          textbookTags: tags,
        ),
      );
    }
  }
  return BookListResult(items: items);
}

String _normalizeBookFieldName(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

String _firstBookField(Map<String, String> fields, List<String> names) {
  for (final name in names) {
    final value = fields[_normalizeBookFieldName(name)] ?? '';
    if (value.trim().isNotEmpty) return value;
  }
  return '';
}

List<String> _splitTextbookEntries(String value) {
  final normalized = value
      .replaceAll(RegExp(r'&lt;br\s*/?&gt;', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final entries = <String>[];
  for (final rawLine in normalized.split('\n')) {
    final line = _cleanBookText(rawLine);
    if (line.isEmpty) continue;

    // Some records put a second author after <br>, followed by the publisher
    // and edition. It is a continuation of the previous textbook, not a
    // textbook whose title is the author's name.
    if (entries.isNotEmpty &&
        _isTextbookAuthorContinuation(entries.last, line)) {
      entries[entries.length - 1] = '${entries.last}/$line';
    } else {
      entries.add(line);
    }
  }
  return entries;
}

bool _isTextbookAuthorContinuation(String previous, String current) {
  final previousParts = previous.split('/');
  final currentParts = current.split('/');
  if (previousParts.length != 2 || currentParts.length < 3) return false;
  if (!_looksLikeChinesePersonName(previousParts[1]) ||
      !_looksLikeChinesePersonName(currentParts.first)) {
    return false;
  }
  return currentParts
      .skip(1)
      .any((part) => part.contains('出版社') || part.contains('版'));
}

bool _looksLikeChinesePersonName(String value) {
  final text = value.trim();
  return RegExp(
    r'^[赵钱孙李周吴郑王冯陈褚卫蒋沈韩杨朱秦尤许何吕施张孔曹严华金魏陶姜戚谢邹喻柏水窦章云苏潘葛奚范彭郎鲁韦昌马苗凤花方俞任袁柳酆鲍史唐费廉岑薛雷贺倪汤滕殷罗毕郝邬安常乐于时傅皮卞齐康伍余元卜顾孟平黄和穆萧尹姚邵湛汪祁毛禹狄米贝明臧计伏成戴谈宋茅庞熊纪舒屈项祝董梁杜阮蓝闵席季麻强贾路娄危江童颜郭梅盛林刁钟徐邱骆高夏蔡田樊胡凌霍虞万支柯昝管卢莫经房裘缪干解应宗丁宣贲邓郁单杭洪包诸左石崔吉钮龚程嵇邢滑裴陆荣翁荀羊於惠甄曲家封芮羿储靳汲邴糜松井段富巫乌焦巴弓牧隗山谷车侯宓蓬全郗班仰秋仲伊宫宁仇栾暴甘钭厉戎祖武符刘景詹束龙叶幸司韶郜黎蓟薄印宿白怀蒲邰从鄂索咸籍赖卓蔺屠蒙池乔阴郁胥能苍双闻莘党翟谭贡劳逄姬申扶堵冉宰郦雍却璩桑桂濮牛寿通边扈燕冀郏浦尚农温别庄晏柴瞿阎充慕连茹习宦艾鱼容向古易慎戈廖庾终暨居衡步都耿满弘匡国文寇广禄阙东欧殳沃利蔚越夔隆师巩厍聂晁勾敖融冷訾辛阚那简饶空曾毋沙乜养鞠须丰巢关蒯相查后荆红游竺权逯盖益桓公万俟司马上官欧阳夏侯诸葛闻人东方赫连皇甫尉迟公羊澹台公冶宗政濮阳淳于单于太叔申屠公孙仲孙轩辕令狐钟离宇文长孙慕容鲜于闾丘司徒司空亓官司寇仉督子车颛孙端木巫马公西漆雕乐正壤驷公良拓跋夹谷宰父谷梁晋楚闫法汝鄢涂钦段干百里东郭南门呼延归海羊舌微生岳帅缑亢况后有琴梁丘左丘东门西门商牟佘佴伯赏南宫墨哈谯笪年爱阳佟第五言福][\u4e00-\u9fff]{1,4}(?:等|等人)?$',
  ).hasMatch(text);
}

String _bookTableCellText(html_dom.Element cell) {
  final source = cell.innerHtml.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );
  return (html_parser.parseFragment(source).text ?? '')
      .replaceAll('\u00a0', ' ')
      .trim();
}

String _cleanBookText(String value) =>
    value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
