class ResourceCourse {
  final String code;
  final String name;
  final int questionBankCount;
  final int resourceCount;
  final int textbookCount;

  /// Signed WebP cover of the first textbook with a cover, empty when the
  /// course has no cover yet.
  final String coverUrl;

  const ResourceCourse({
    required this.code,
    required this.name,
    this.questionBankCount = 0,
    this.resourceCount = 0,
    this.textbookCount = 0,
    this.coverUrl = '',
  });

  factory ResourceCourse.fromJson(Map<String, dynamic> json) => ResourceCourse(
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    questionBankCount: _asInt(json['question_bank_count']),
    resourceCount: _asInt(json['resource_count']),
    textbookCount: _asInt(json['textbook_count']),
    coverUrl: json['cover_url']?.toString() ?? '',
  );
}

class CourseResourceItem {
  final String id;
  final String name;
  final String tags;
  final bool hasPdf;

  const CourseResourceItem({
    required this.id,
    required this.name,
    this.tags = '',
    this.hasPdf = false,
  });

  factory CourseResourceItem.fromJson(Map<String, dynamic> json) =>
      CourseResourceItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '试卷',
        tags: json['tags']?.toString() ?? '',
        hasPdf: json['has_pdf'] == true,
      );
}

class CourseTextbookItem {
  final String id;
  final String name;
  final String tags;
  final bool hasPdf;
  final bool hasCover;

  const CourseTextbookItem({
    required this.id,
    required this.name,
    this.tags = '',
    this.hasPdf = false,
    this.hasCover = false,
  });

  factory CourseTextbookItem.fromJson(Map<String, dynamic> json) =>
      CourseTextbookItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '教材',
        tags: json['tags']?.toString() ?? '',
        hasPdf: json['has_pdf'] == true,
        hasCover: json['has_cover'] == true,
      );
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
