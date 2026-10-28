import 'dart:io';

/// Validates an lcov report and fails when coverage is below the given floors.
///
/// Usage:
///   dart tool/check_coverage.dart `lcov.info [min-line-percent] [min-branch-percent]`
///
/// Line coverage is computed from LF/LH records. Branch coverage is computed
/// from BRDA records (Dart emits branch records when the suite runs with
/// `--branch-coverage`). A report without branch records is considered
/// incomplete and fails, so a partial upload cannot look healthy.
void main(List<String> args) {
  if (args.isEmpty || args.length > 3) {
    stderr.writeln(
      'usage: dart tool/check_coverage.dart <lcov.info> '
      '[min-line-percent] [min-branch-percent]',
    );
    exit(2);
  }

  final report = File(args.first);
  if (!report.existsSync()) {
    stderr.writeln('coverage report not found: ${args.first}');
    exit(2);
  }

  final lineFloor = args.length >= 2 ? double.parse(args[1]) : 0;
  final branchFloor = args.length == 3 ? double.parse(args[2]) : null;

  var lines = 0;
  var linesHit = 0;
  var branches = 0;
  var branchesHit = 0;
  var sources = 0;
  for (final line in report.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      sources += 1;
    } else if (line.startsWith('LF:')) {
      lines += int.tryParse(line.substring(3).trim()) ?? 0;
    } else if (line.startsWith('LH:')) {
      linesHit += int.tryParse(line.substring(3).trim()) ?? 0;
    } else if (line.startsWith('BRDA:')) {
      // BRDA:<line>,<block>,<branch>,<taken>; "-" means the branch is
      // unreachable (for example a guard around a const) and is not counted.
      final taken = line.substring(5).split(',')[3].trim();
      if (taken == '-') continue;
      branches += 1;
      if (taken != '0') branchesHit += 1;
    }
  }

  if (lines == 0 || sources == 0) {
    stderr.writeln('no coverage data in ${args.first}');
    exit(2);
  }

  final linePercent = linesHit / lines * 100;
  stdout.writeln(
    'line coverage: $linesHit/$lines = ${linePercent.toStringAsFixed(2)}% '
    '(floor ${lineFloor.toStringAsFixed(2)}%, sources $sources)',
  );

  if (branches == 0) {
    stderr.writeln(
      'no branch coverage in ${args.first}; run flutter test with '
      '--branch-coverage so the uploaded report is complete',
    );
    exit(2);
  }
  final branchPercent = branchesHit / branches * 100;
  stdout.writeln(
    'branch coverage: $branchesHit/$branches = '
    '${branchPercent.toStringAsFixed(2)}%'
    '${branchFloor == null ? '' : ' (floor ${branchFloor.toStringAsFixed(2)}%)'}',
  );

  var failed = false;
  if (linePercent < lineFloor) {
    stderr.writeln('line coverage is below the floor');
    failed = true;
  }
  if (branchFloor != null && branchPercent < branchFloor) {
    stderr.writeln('branch coverage is below the floor');
    failed = true;
  }
  if (failed) exit(1);
}
