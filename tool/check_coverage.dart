import 'dart:io';

/// Fails when total line coverage in an lcov report is below the given floor.
///
/// Usage: `dart tool/check_coverage.dart <lcov.info> [min-percent]`
void main(List<String> args) {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln(
      'usage: dart run tool/check_coverage.dart <lcov.info> [min-percent]',
    );
    exit(2);
  }

  final report = File(args.first);
  if (!report.existsSync()) {
    stderr.writeln('coverage report not found: ${args.first}');
    exit(2);
  }

  final floor = args.length == 2 ? double.parse(args[1]) : 0;
  var total = 0;
  var hit = 0;
  for (final line in report.readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      total += int.tryParse(line.substring(3).trim()) ?? 0;
    } else if (line.startsWith('LH:')) {
      hit += int.tryParse(line.substring(3).trim()) ?? 0;
    }
  }

  if (total == 0) {
    stderr.writeln('no coverage data in ${args.first}');
    exit(2);
  }

  final percent = hit / total * 100;
  stdout.writeln(
    'coverage: $hit/$total = ${percent.toStringAsFixed(2)}% '
    '(floor ${floor.toStringAsFixed(2)}%)',
  );
  if (percent < floor) {
    stderr.writeln('coverage is below the floor');
    exit(1);
  }
}
