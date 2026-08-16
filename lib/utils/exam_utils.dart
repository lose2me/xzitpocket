DateTime? parseExamDate(String time) {
  final dateMatch = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(time);
  if (dateMatch == null) return null;
  final year = int.parse(dateMatch.group(1)!);
  final month = int.parse(dateMatch.group(2)!);
  final day = int.parse(dateMatch.group(3)!);
  final endMatch = RegExp(r'\d{1,2}:\d{2}\s*[-—]\s*(\d{1,2}):(\d{2})')
      .firstMatch(time);
  if (endMatch != null) {
    return DateTime(
      year,
      month,
      day,
      int.parse(endMatch.group(1)!),
      int.parse(endMatch.group(2)!),
    );
  }
  return DateTime(year, month, day, 23, 59, 59);
}
