class UserConfig {
  final String? studentId;
  final String? studentName;
  final String? collegeName;
  final String? className;
  final String? majorName;

  const UserConfig({
    this.studentId,
    this.studentName,
    this.collegeName,
    this.className,
    this.majorName,
  });

  UserConfig copyWith({
    String? studentId,
    String? studentName,
    String? collegeName,
    String? className,
    String? majorName,
  }) {
    return UserConfig(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      collegeName: collegeName ?? this.collegeName,
      className: className ?? this.className,
      majorName: majorName ?? this.majorName,
    );
  }
}
