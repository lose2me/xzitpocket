class UserConfig {
  final String? studentId;
  final String? studentName;
  final String? majorName;
  final String? className;

  const UserConfig({
    this.studentId,
    this.studentName,
    this.majorName,
    this.className,
  });

  UserConfig copyWith({
    String? studentId,
    String? studentName,
    String? majorName,
    String? className,
  }) {
    return UserConfig(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      majorName: majorName ?? this.majorName,
      className: className ?? this.className,
    );
  }
}
