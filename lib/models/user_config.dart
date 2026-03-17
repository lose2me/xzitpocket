class UserConfig {
  final String? studentId;
  final String? studentName;

  const UserConfig({this.studentId, this.studentName});

  UserConfig copyWith({
    String? studentId,
    String? studentName,
  }) {
    return UserConfig(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
    );
  }
}
