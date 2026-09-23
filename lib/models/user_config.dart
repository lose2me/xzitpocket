class UserConfig {
  final String? studentId;
  final String? studentName;
  final String? collegeName;
  final String? className;

  const UserConfig({
    this.studentId,
    this.studentName,
    this.collegeName,
    this.className,
  });

  UserConfig copyWith({
    String? studentId,
    String? studentName,
    String? collegeName,
    String? className,
  }) {
    return UserConfig(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      collegeName: collegeName ?? this.collegeName,
      className: className ?? this.className,
    );
  }
}
