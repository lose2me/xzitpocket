class UserConfig {
  final DateTime? semesterStartDate;
  final String? studentId;
  final String? studentName;

  const UserConfig({this.semesterStartDate, this.studentId, this.studentName});

  UserConfig copyWith({
    DateTime? semesterStartDate,
    String? studentId,
    String? studentName,
  }) {
    return UserConfig(
      semesterStartDate: semesterStartDate ?? this.semesterStartDate,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
    );
  }
}
