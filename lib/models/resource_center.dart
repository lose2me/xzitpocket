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
  final int sizeBytes;

  const CourseResourceItem({
    required this.id,
    required this.name,
    this.tags = '',
    this.hasPdf = false,
    this.sizeBytes = 0,
  });

  factory CourseResourceItem.fromJson(Map<String, dynamic> json) =>
      CourseResourceItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '试卷',
        tags: json['tags']?.toString() ?? '',
        hasPdf: json['has_pdf'] == true,
        sizeBytes: _asInt(json['size_bytes']),
      );
}

class UploadTextbook {
  final String id;
  final String name;
  final String tags;
  final List<String> courseCodes;
  final bool hasPdf;

  const UploadTextbook({
    required this.id,
    required this.name,
    this.tags = '',
    this.courseCodes = const [],
    this.hasPdf = false,
  });

  String get primaryCourseCode => courseCodes.isEmpty ? '' : courseCodes.first;

  @override
  bool operator ==(Object other) => other is UploadTextbook && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory UploadTextbook.fromJson(Map<String, dynamic> json) => UploadTextbook(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    tags: json['tags']?.toString() ?? '',
    courseCodes: [
      for (final code in (json['course_codes'] as List? ?? const []))
        if (code?.toString().trim().isNotEmpty ?? false) code.toString().trim(),
    ],
    hasPdf: json['has_pdf'] == true,
  );

  factory UploadTextbook.fromCourseTextbook(
    CourseTextbookItem item,
    String courseCode,
  ) => UploadTextbook(
    id: item.id,
    name: item.name,
    tags: item.tags,
    courseCodes: [if (courseCode.trim().isNotEmpty) courseCode.trim()],
    hasPdf: item.hasPdf,
  );
}

class CourseTextbookItem {
  final String id;
  final String name;
  final String tags;
  final bool hasPdf;
  final bool hasCover;
  final int sizeBytes;

  const CourseTextbookItem({
    required this.id,
    required this.name,
    this.tags = '',
    this.hasPdf = false,
    this.hasCover = false,
    this.sizeBytes = 0,
  });

  factory CourseTextbookItem.fromJson(Map<String, dynamic> json) =>
      CourseTextbookItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '教材',
        tags: json['tags']?.toString() ?? '',
        hasPdf: json['has_pdf'] == true,
        hasCover: json['has_cover'] == true,
        sizeBytes: _asInt(json['size_bytes']),
      );
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
