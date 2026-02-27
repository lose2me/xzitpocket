class UserConfig {
  final DateTime? semesterStartDate;
  final String? studentId;
  final String? studentName;
  final int? year;
  final int? term;

  const UserConfig({
    this.semesterStartDate,
    this.studentId,
    this.studentName,
    this.year,
    this.term,
  });

  UserConfig copyWith({
    DateTime? semesterStartDate,
    String? studentId,
    String? studentName,
    int? year,
    int? term,
  }) {
    return UserConfig(
      semesterStartDate: semesterStartDate ?? this.semesterStartDate,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      year: year ?? this.year,
      term: term ?? this.term,
    );
  }
}
