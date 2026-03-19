List<int>? parseSessionRanges(
  String text, {
  required int minSession,
  required int maxSession,
}) {
  final normalized = text
      .trim()
      .replaceAll('，', ',')
      .replaceAll('、', ',')
      .replaceAll('第', '')
      .replaceAll('节', '');
  if (normalized.isEmpty) return null;

  final tokens = normalized
      .split(',')
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return null;

  final sessions = <int>{};
  final tokenPattern = RegExp(r'^(\d+)(?:\s*-\s*(\d+))?$');

  for (final token in tokens) {
    final match = tokenPattern.firstMatch(token);
    if (match == null) return null;

    var start = int.parse(match.group(1)!);
    var end = int.parse(match.group(2) ?? match.group(1)!);
    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }
    if (start < minSession || end > maxSession) {
      return null;
    }

    for (int session = start; session <= end; session++) {
      sessions.add(session);
    }
  }

  if (sessions.isEmpty) return null;
  return sessions.toList()..sort();
}

List<int>? parseWeekRanges(
  String text, {
  required int maxWeek,
  bool emptyMeansAll = false,
  bool allowParity = true,
}) {
  final normalized = text
      .trim()
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll('，', ',')
      .replaceAll('周次', '')
      .replaceAll('周', '');

  if (normalized.isEmpty) {
    return emptyMeansAll ? List.generate(maxWeek, (index) => index + 1) : null;
  }

  final tokens = normalized
      .split(',')
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return null;

  final weeks = <int>{};
  final tokenPattern = RegExp(
    r'^(\d+)(?:\s*-\s*(\d+))?(?:\(([^()]*)\))?$',
  );

  for (final token in tokens) {
    final match = tokenPattern.firstMatch(token);
    if (match == null) return null;

    var start = int.parse(match.group(1)!);
    var end = int.parse(match.group(2) ?? match.group(1)!);
    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }
    if (start < 1 || end > maxWeek) {
      return null;
    }

    var values = List.generate(end - start + 1, (index) => start + index);
    final parity = (match.group(3) ?? '').trim();
    if (parity.isNotEmpty) {
      if (!allowParity) return null;
      if (parity.contains('单')) {
        values = values.where((week) => week.isOdd).toList();
      } else if (parity.contains('双')) {
        values = values.where((week) => week.isEven).toList();
      } else {
        return null;
      }
    }

    if (values.isEmpty) return null;
    weeks.addAll(values);
  }

  if (weeks.isEmpty) return null;
  return weeks.toList()..sort();
}

String formatWeekRanges(List<int> weeks) {
  if (weeks.isEmpty) return '';

  final sorted = [...weeks]..sort();
  final ranges = <String>[];
  int start = sorted.first;
  int end = sorted.first;

  for (int index = 1; index < sorted.length; index++) {
    if (sorted[index] == end + 1) {
      end = sorted[index];
      continue;
    }

    ranges.add(start == end ? '$start' : '$start-$end');
    start = sorted[index];
    end = sorted[index];
  }

  ranges.add(start == end ? '$start' : '$start-$end');
  return ranges.join(',');
}
