DateTime? parseExamDate(String time) {
  final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(time);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    23, 59, 59,
  );
}
