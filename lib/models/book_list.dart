class BookListItem {
  final String courseName;
  final String textbookName;
  final List<String> textbookTags;

  const BookListItem({
    required this.courseName,
    required this.textbookName,
    required this.textbookTags,
  });
}

class BookListResult {
  final List<BookListItem> items;

  const BookListResult({required this.items});

  bool get isEmpty => items.isEmpty;
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
}
