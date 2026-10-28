class ResourceCourse {
  final String code;
  final String name;
  final int questionBankCount;
  final int resourceCount;
  final int textbookCount;

  /// Signed WebP cover of the first textbook with a cover, empty when the
  /// course has no cover yet.
  final String coverUrl;

  /// Server version of the cover image only, so adding an unrelated resource
  /// does not invalidate the downloaded cover.
  final String coverVersion;

  /// Server content version of the course's resources and textbooks. Used to
  /// decide whether a cached course detail is still current.
  final String version;

  const ResourceCourse({
    required this.code,
    required this.name,
    this.questionBankCount = 0,
    this.resourceCount = 0,
    this.textbookCount = 0,
    this.coverUrl = '',
    this.coverVersion = '',
    this.version = '',
  });

  factory ResourceCourse.fromJson(Map<String, dynamic> json) => ResourceCourse(
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    questionBankCount: _asInt(json['question_bank_count']),
    resourceCount: _asInt(json['resource_count']),
    textbookCount: _asInt(json['textbook_count']),
    coverUrl: json['cover_url']?.toString() ?? '',
    coverVersion: json['cover_version']?.toString() ?? '',
    version: json['version']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'question_bank_count': questionBankCount,
    'resource_count': resourceCount,
    'textbook_count': textbookCount,
    'cover_url': coverUrl,
    'cover_version': coverVersion,
    'version': version,
  };
}

class CourseResourceItem {
  final String id;
  final String name;
  final String tags;
  final bool hasPdf;
  final String format;
  final int sizeBytes;
  final String fileVersion;

  /// Server update time, used when deciding whether a cached row is current.
  final String updatedAt;

  /// Analysis modes that have a succeeded report for this paper.
  final List<String> aiModes;

  const CourseResourceItem({
    required this.id,
    required this.name,
    this.tags = '',
    this.hasPdf = false,
    this.format = 'pdf',
    this.sizeBytes = 0,
    this.fileVersion = '',
    this.updatedAt = '',
    this.aiModes = const [],
  });

  factory CourseResourceItem.fromJson(Map<String, dynamic> json) {
    final format = json['format']?.toString().toLowerCase() ?? '';
    return CourseResourceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '试卷',
      tags: json['tags']?.toString() ?? '',
      hasPdf: json['has_pdf'] == true,
      format: format == 'doc' || format == 'docx' ? format : 'pdf',
      sizeBytes: _asInt(json['size_bytes']),
      fileVersion: json['file_version'] as String? ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      aiModes: switch (json['ai_modes']) {
        final List<dynamic> modes => [
          for (final mode in modes) mode.toString(),
        ],
        _ => const [],
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tags': tags,
    'has_pdf': hasPdf,
    'format': format,
    'size_bytes': sizeBytes,
    'file_version': fileVersion,
    'updated_at': updatedAt,
    'ai_modes': aiModes,
  };
}

/// AI analysis of one paper.
class ResourceAIResult {
  final bool available;
  final String mode;
  final String format;
  final String status;
  final String markdown;
  final String updatedAt;
  final int outputSize;
  final int totalPages;
  final int solvable;
  final String precheckNote;
  final String pdfUrl;
  final String fileVersion;
  final String error;

  const ResourceAIResult({
    this.available = false,
    this.mode = 'basic',
    this.format = 'pdf',
    this.status = '',
    this.markdown = '',
    this.updatedAt = '',
    this.outputSize = 0,
    this.totalPages = 0,
    this.solvable = 0,
    this.precheckNote = '',
    this.pdfUrl = '',
    this.fileVersion = '',
    this.error = '',
  });

  bool get processing =>
      status == 'queued' || status == 'running' || status == 'paused';

  factory ResourceAIResult.fromJson(Map<String, dynamic> json) =>
      ResourceAIResult(
        available: json['available'] == true,
        mode: json['mode']?.toString() ?? 'basic',
        format: json['format']?.toString() ?? 'pdf',
        status: json['status']?.toString() ?? '',
        markdown: json['markdown']?.toString() ?? '',
        updatedAt: json['updated_at']?.toString() ?? '',
        outputSize: _asInt(json['output_size']),
        totalPages: _asInt(json['total_pages']),
        solvable: _asInt(json['solvable']),
        precheckNote: json['precheck_note']?.toString() ?? '',
        pdfUrl: json['pdf_url']?.toString() ?? '',
        fileVersion: json['file_version'] as String? ?? '',
        error: json['error']?.toString() ?? '',
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tags': tags,
    'course_codes': courseCodes,
    'has_pdf': hasPdf,
  };

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
  final String fileVersion;

  /// Server update time, used when deciding whether a cached row is current.
  final String updatedAt;

  const CourseTextbookItem({
    required this.id,
    required this.name,
    this.tags = '',
    this.hasPdf = false,
    this.hasCover = false,
    this.sizeBytes = 0,
    this.fileVersion = '',
    this.updatedAt = '',
  });

  factory CourseTextbookItem.fromJson(Map<String, dynamic> json) =>
      CourseTextbookItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '教材',
        tags: json['tags']?.toString() ?? '',
        hasPdf: json['has_pdf'] == true,
        hasCover: json['has_cover'] == true,
        sizeBytes: _asInt(json['size_bytes']),
        fileVersion: json['file_version'] as String? ?? '',
        updatedAt: json['updated_at']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tags': tags,
    'has_pdf': hasPdf,
    'has_cover': hasCover,
    'size_bytes': sizeBytes,
    'file_version': fileVersion,
    'updated_at': updatedAt,
  };
}

/// Course numbers are shown at most 10 characters wide in the app.
String shortCourseCode(String code) {
  final value = code.trim();
  if (value.length <= 10) return value;
  return '${value.substring(0, 9)}…';
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
