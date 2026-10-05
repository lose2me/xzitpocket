class BookListItem {
  final String courseName;
  final String textbookName;
  final List<String> textbookTags;

  const BookListItem({
    required this.courseName,
    required this.textbookName,
    required this.textbookTags,
  });

  Map<String, dynamic> toJson() => {
    'courseName': courseName,
    'textbookName': textbookName,
    'textbookTags': textbookTags,
  };

  factory BookListItem.fromJson(Map<String, dynamic> json) => BookListItem(
    courseName: json['courseName'] as String? ?? '',
    textbookName: json['textbookName'] as String? ?? '',
    textbookTags: [
      for (final tag in (json['textbookTags'] as List? ?? const []))
        tag.toString(),
    ],
  );
}

class BookListResult {
  final List<BookListItem> items;

  const BookListResult({required this.items});

  bool get isEmpty => items.isEmpty;

  Map<String, dynamic> toJson() => {
    'items': [for (final item in items) item.toJson()],
  };

  factory BookListResult.fromJson(Map<String, dynamic> json) => BookListResult(
    items: [
      for (final raw in (json['items'] as List? ?? const []))
        BookListItem.fromJson(raw as Map<String, dynamic>),
    ],
  );
}

class BookListSemesterOption {
  final String academicYear;
  final String termCode;
  final String label;

  const BookListSemesterOption({
    required this.academicYear,
    required this.termCode,
    required this.label,
  });

  String get key => '$academicYear|$termCode';

  Map<String, dynamic> toJson() => {
    'academicYear': academicYear,
    'termCode': termCode,
    'label': label,
  };

  factory BookListSemesterOption.fromJson(Map<String, dynamic> json) =>
      BookListSemesterOption(
        academicYear: json['academicYear'] as String? ?? '',
        termCode: json['termCode'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}

class BookListSemesterCatalog {
  final List<BookListSemesterOption> options;
  final BookListSemesterOption? current;

  const BookListSemesterCatalog({required this.options, this.current});
}

class BookListPageResult {
  final List<BookListSemesterOption> semesters;
  final BookListSemesterOption selectedSemester;
  final BookListResult books;

  const BookListPageResult({
    required this.semesters,
    required this.selectedSemester,
    required this.books,
  });

  Map<String, dynamic> toJson() => {
    'semesters': [for (final semester in semesters) semester.toJson()],
    'selectedSemester': selectedSemester.toJson(),
    'books': books.toJson(),
  };

  factory BookListPageResult.fromJson(Map<String, dynamic> json) =>
      BookListPageResult(
        semesters: [
          for (final raw in (json['semesters'] as List? ?? const []))
            BookListSemesterOption.fromJson(raw as Map<String, dynamic>),
        ],
        selectedSemester: BookListSemesterOption.fromJson(
          json['selectedSemester'] as Map<String, dynamic>? ?? const {},
        ),
        books: BookListResult.fromJson(
          json['books'] as Map<String, dynamic>? ?? const {},
        ),
      );
}
