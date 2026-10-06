import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Scrollbar;
import 'package:forui/forui.dart';

import '../../models/book_list.dart';
import '../../services/auth_service.dart';
import '../../services/cas_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

const _scoreBandLabels = ['不及格', '及格', '良好', '优秀'];

class GradeQueryPage extends StatefulWidget {
  final String studentId;
  final String password;
  final PreferencesStorage preferencesStorage;

  const GradeQueryPage({
    super.key,
    required this.studentId,
    required this.password,
    required this.preferencesStorage,
  });

  @override
  State<GradeQueryPage> createState() => _GradeQueryPageState();
}

class _GradeQueryPageState extends State<GradeQueryPage> {
  static const _cacheTtl = Duration(minutes: 5);

  GradeResult? _result;
  AcademicStatus? _academic;
  bool _loading = false;
  bool _refreshSucceeded = false;
  String? _selectedSemesterKey;
  GradeResult? _semesterOptionsSource;
  BookListSemesterCatalog? _semesterCatalogCache;

  @override
  void initState() {
    super.initState();
    _restoreCache();
    unawaited(_load());
  }

  void _restoreCache() {
    try {
      final gradeJson = widget.preferencesStorage.getGradeCache();
      final academicJson = widget.preferencesStorage.getAcademicCache();
      if (gradeJson != null && gradeJson.isNotEmpty) {
        _result = GradeResult.fromJson(
          jsonDecode(gradeJson) as Map<String, dynamic>,
        );
        _selectedSemesterKey = _semesterCatalog.current?.key;
      }
      if (academicJson != null && academicJson.isNotEmpty) {
        _academic = AcademicStatus.fromJson(
          jsonDecode(academicJson) as Map<String, dynamic>,
        );
      }
    } catch (error, stackTrace) {
      talker.warning('学业缓存解析失败', error, stackTrace);
      _result = null;
      _academic = null;
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final hasFreshCache =
        _result != null &&
        _academic != null &&
        PreferencesStorage.isCacheValid(
          widget.preferencesStorage.getGradeCacheTime(),
          _cacheTtl,
        ) &&
        PreferencesStorage.isCacheValid(
          widget.preferencesStorage.getAcademicCacheTime(),
          _cacheTtl,
        ) &&
        _academic?.parserVersion == AcademicStatus.currentParserVersion;
    if (!forceRefresh && hasFreshCache) return;

    setState(() => _loading = true);
    try {
      final (grades, academic) = await AuthService().fetchGradesAndAcademic(
        widget.studentId,
        widget.password,
      );
      await Future.wait([
        widget.preferencesStorage.setGradeCache(jsonEncode(grades.toJson())),
        widget.preferencesStorage.setAcademicCache(
          jsonEncode(academic.toJson()),
        ),
      ]);
      if (!mounted) return;
      final gradesChanged =
          jsonEncode(_result?.toJson()) != jsonEncode(grades.toJson());
      final academicChanged =
          jsonEncode(_academic?.toJson()) != jsonEncode(academic.toJson());
      setState(() {
        if (gradesChanged) _result = grades;
        if (academicChanged) _academic = academic;
        _refreshSucceeded = true;
        if (gradesChanged) {
          _semesterOptionsSource = null;
          _semesterCatalogCache = null;
          _selectedSemesterKey = _semesterCatalog.current?.key;
        }
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('学业情况查询失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, e.message, severity: ToastSeverity.error);
      }
    } catch (e, stackTrace) {
      talker.error('学业情况查询异常', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '加载失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  BookListSemesterCatalog get _semesterCatalog {
    final result = _result;
    if (result == null) {
      return const BookListSemesterCatalog(options: []);
    }
    if (identical(result, _semesterOptionsSource) &&
        _semesterCatalogCache != null) {
      return _semesterCatalogCache!;
    }
    final catalog = buildBookListSemesterCatalog(result, widget.studentId);
    _semesterOptionsSource = result;
    _semesterCatalogCache = catalog;
    return catalog;
  }

  BookListSemesterOption? get _selectedSemester {
    final options = _gradedSemesterOptions;
    final key = _selectedSemesterKey;
    if (key != null) {
      for (final option in options) {
        if (option.key == key) return option;
      }
    }
    return options.isEmpty ? _semesterCatalog.current : options.first;
  }

  /// 成绩页只展示已经有成绩的学期；书单页还会额外展示当前未出成绩学期。
  List<BookListSemesterOption> get _gradedSemesterOptions {
    final options = <BookListSemesterOption>[];
    for (final option in _semesterCatalog.options) {
      if (_hasGradesFor(option)) options.add(option);
    }
    return options;
  }

  bool _hasGradesFor(BookListSemesterOption option) {
    final result = _result;
    final academicYear = int.tryParse(option.academicYear);
    if (result == null || academicYear == null) return false;
    final term = option.termCode == '3' ? 1 : 2;
    return result.grades.any((grade) {
      final gradeYear = int.tryParse(
        RegExp(r'20\d{2}').firstMatch(grade.year)?.group(0) ?? '',
      );
      return gradeYear == academicYear && _gradeTermNumber(grade.term) == term;
    });
  }

  List<GradeItem> get _filtered {
    if (_result == null) return [];
    final semester = _selectedSemester;
    if (semester == null) return [];
    final academicYear = int.tryParse(semester.academicYear);
    final term = semester.termCode == '3' ? 1 : 2;
    if (academicYear == null) return [];
    return _result!.grades.where((grade) {
      final gradeYear = int.tryParse(
        RegExp(r'20\d{2}').firstMatch(grade.year)?.group(0) ?? '',
      );
      final gradeTerm = _gradeTermNumber(grade.term);
      return gradeYear == academicYear && gradeTerm == term;
    }).toList();
  }

  bool get _hideSemesterSelector {
    final current = _semesterCatalog.current;
    if (current == null || _gradedSemesterOptions.isNotEmpty) return false;
    final enrollmentYear = _studentEnrollmentYear(widget.studentId);
    return enrollmentYear != null &&
        current.academicYear == enrollmentYear.toString() &&
        current.termCode == '3';
  }

  int? _studentEnrollmentYear(String value) {
    final match = RegExp(r'^(?:20)?(\d{2})').firstMatch(value.trim());
    final year = int.tryParse(match?.group(1) ?? '');
    return year == null ? null : 2000 + year;
  }

  int? _gradeTermNumber(String value) {
    final term = value.trim();
    if (term == '1' || term == '3' || term.contains('一')) return 1;
    if (term == '2' || term == '12' || term.contains('二')) return 2;
    return int.tryParse(term);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppPage(
      title: '学业情况',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _loading ? null : () => _load(forceRefresh: true),
          tooltip: '刷新成绩',
          loading: _loading,
          completed: _refreshSucceeded,
        ),
      ],
      child: AppPageBody(
        maxWidth: AppLayout.contentMaxWidth,
        child: FTabs(
          expands: true,
          children: [
            FTabEntry(label: const Text('学科成绩'), child: _buildGradeTab(theme)),
            FTabEntry(
              label: const Text('学业总览'),
              child: _buildAcademicTab(theme),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grade Tab ──

  Widget _buildGradeTab(FThemeData theme) {
    final grades = _filtered;
    if (_loading && _result == null) {
      return const Center(child: FCircularProgress());
    }
    if (grades.isEmpty) {
      return AppPageBody(
        maxWidth: AppLayout.resultMaxWidth,
        safeArea: false,
        child: Column(
          children: [
            _buildHeader(theme, grades),
            Expanded(child: _buildEmptyGradeState(theme)),
          ],
        ),
      );
    }
    return AppPageBody(
      maxWidth: AppLayout.resultMaxWidth,
      safeArea: false,
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.xs,
        bottomPadding: AppSpacing.xxl,
        safeArea: false,
        children: [
          _buildHeader(theme, grades),
          for (final grade in grades) _buildGradeTile(theme, grade),
        ],
      ),
    );
  }

  Widget _buildHeader(FThemeData theme, List<GradeItem> grades) {
    var totalCredit = 0.0;
    var weightedSum = 0.0;
    for (final g in grades) {
      if (g.gradePoint > 0) {
        totalCredit += g.credit;
        weightedSum += g.credit * g.gradePoint;
      }
    }
    final gpa = totalCredit > 0 ? weightedSum / totalCredit : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_hideSemesterSelector) _buildSemesterSelector(theme),
          if (grades.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  _buildSummaryRow(theme, totalCredit, gpa),
                  const SizedBox(height: AppSpacing.md),
                  _buildScoreDistribution(theme, grades),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _optionLabel(String key) {
    for (final option in _gradedSemesterOptions) {
      if (option.key == key) return option.label;
    }
    return _gradedSemesterOptions.isEmpty
        ? ''
        : _gradedSemesterOptions.first.label;
  }

  Widget _buildSemesterSelector(FThemeData theme) {
    final options = _gradedSemesterOptions;
    if (options.isEmpty) return const SizedBox.shrink();
    final selectedKey = _selectedSemester?.key ?? options.first.key;

    return SizedBox(
      width: double.infinity,
      child: FSelect<String>.rich(
        control: FSelectControl.lifted(
          value: selectedKey,
          onChange: (key) {
            if (key == null) return;
            for (final option in options) {
              if (option.key == key) {
                setState(() => _selectedSemesterKey = option.key);
                return;
              }
            }
          },
        ),
        format: _optionLabel,
        children: [
          for (final o in options)
            FSelectItem.item(title: Text(o.label), value: o.key),
        ],
      ),
    );
  }

  /// 学分 / 绩点摘要行。
  Widget _buildSummaryRow(FThemeData theme, double totalCredit, double gpa) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '该学期学分 ${totalCredit.toStringAsFixed(1)}',
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        Text(
          '该学期绩点 ${gpa.toStringAsFixed(2)} / 5.0',
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreDistribution(FThemeData theme, List<GradeItem> grades) {
    final counts = List<int>.filled(4, 0);
    for (final grade in grades) {
      final band = _scoreBandIndex(grade.score);
      if (band != null) counts[band]++;
    }
    final total = counts.fold<int>(0, (sum, count) => sum + count);
    final visibleBands = [
      for (var index = 0; index < counts.length; index++)
        if (counts[index] > 0) index,
    ];
    final distributionLabel = visibleBands.isEmpty
        ? '暂无可识别成绩'
        : visibleBands
              .map((index) => '${_scoreBandLabels[index]}${counts[index]}门')
              .join('，');
    return Column(
      children: [
        Semantics(
          label: '成绩分布：$distributionLabel',
          child: SizedBox(
            width: double.infinity,
            height: 10,
            child: total == 0
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colors.muted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final index in visibleBands)
                        Expanded(
                          flex: counts[index],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.micro,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _scoreBandColors(theme)[index],
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (visibleBands.isNotEmpty)
          Row(
            children: [
              for (final index in visibleBands)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _scoreBandColors(theme)[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          _scoreBandLabels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.body.xs.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyGradeState(FThemeData theme) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _hideSemesterSelector
              ? FLucideIcons.clock3
              : FLucideIcons.graduationCap,
          size: 48,
          color: theme.colors.mutedForeground,
        ),
        const SizedBox(height: 12),
        Text(
          _hideSemesterSelector ? '暂未开始考试' : '暂无成绩',
          style: theme.typography.tileTitle.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    ),
  );

  Widget _buildGradeTile(FThemeData theme, GradeItem grade) {
    final details = [
      grade.courseCode.trim(),
      grade.department.trim(),
    ].where((value) => value.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grade.name,
                    style: theme.typography.tileTitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details.isEmpty ? '课程信息暂缺' : details,
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            SizedBox(
              width: 76,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_fmtNum(grade.credit)} 学分',
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 34,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        grade.score,
                        style: theme.typography.metric.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _scoreColor(theme, grade.score),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(FThemeData theme, String score) {
    final band = _scoreBandIndex(score);
    return band == null
        ? theme.colors.foreground
        : _scoreBandColors(theme)[band];
  }

  List<Color> _scoreBandColors(FThemeData theme) => [
    // Soft macaron red, yellow, blue and green with enough foreground blend
    // to remain readable on both light and dark surfaces.
    Color.lerp(theme.colors.foreground, const Color(0xFFF3A6B8), 0.82)!,
    Color.lerp(theme.colors.foreground, const Color(0xFFF2D98B), 0.82)!,
    Color.lerp(theme.colors.foreground, const Color(0xFFA9C9F5), 0.82)!,
    Color.lerp(theme.colors.foreground, const Color(0xFFA5DDB8), 0.82)!,
  ];

  // ── Academic Tab ──

  Widget _buildAcademicTab(FThemeData theme) {
    if (_loading && _academic == null) {
      return const Center(child: FCircularProgress());
    }
    final status = _academic;
    if (status == null) {
      return const Center(child: Text('点击刷新加载'));
    }

    final progress = status.totalRequired > 0
        ? status.totalEarned / status.totalRequired
        : 0.0;

    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      safeArea: false,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: _buildGpaRow(theme, status),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '总学分进度 ${(progress * 100).toStringAsFixed(1)}%',
                          style: theme.typography.body.sm.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${status.totalEarned} / ${status.totalRequired}',
                          style: theme.typography.body.md.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: FDeterminateProgress(
                        value: progress.clamp(0.0, 1.0),
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < status.categories.length; i++) ...[
                if (i > 0) const FDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: _AcademicCategoryNode(
                    key: ValueKey('root:$i:${status.categories[i].name}'),
                    category: status.categories[i],
                    theme: theme,
                    depth: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGpaRow(FThemeData theme, AcademicStatus status) {
    final progress = (status.gpa / 5.0).clamp(0.0, 1.0);
    final pct = (progress * 100).toInt();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GPA',
                style: theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${status.gpa.toStringAsFixed(2)} / 5.0',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        _RingProgress(
          progress: progress,
          size: 36,
          trackColor: theme.colors.border,
          color: theme.colors.primary,
          center: Text(
            '$pct%',
            style: theme.typography.body.xs.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }
}

/// 确定圆形进度环，中心展示 [center]（通常为百分比）。
class _RingProgress extends StatelessWidget {
  const _RingProgress({
    required this.progress,
    this.size = 36,
    required this.trackColor,
    required this.color,
    this.center,
  });

  final double progress;
  final double size;
  final Color trackColor;
  final Color color;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              trackColor: trackColor,
              color: color,
            ),
          ),
          ?center,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.color,
  });

  final double progress;
  final Color trackColor;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.12;
    if (stroke <= 0) return;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final arc = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.color != color;
  }
}

/// 学业分类的树形可折叠节点：目录可展开/收起，叶子展示学分进度环。
class _AcademicCategoryNode extends StatefulWidget {
  const _AcademicCategoryNode({
    super.key,
    required this.category,
    required this.theme,
    this.depth = 0,
  });

  final AcademicCategory category;
  final FThemeData theme;
  final int depth;

  @override
  State<_AcademicCategoryNode> createState() => _AcademicCategoryNodeState();
}

class _AcademicCategoryNodeState extends State<_AcademicCategoryNode> {
  // 课程树默认展开到有课程明细的分支，用户仍可手动收起。
  late bool _expanded = _academicCategoryHasCourses(widget.category);

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final theme = widget.theme;
    final hasChildren = cat.children.isNotEmpty;
    final noRequirement = cat.reqCredits <= 0;
    final progress = cat.reqCredits > 0
        ? (cat.earnedCredits / cat.reqCredits).clamp(0.0, 1.0)
        : 0.0;
    final pct = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hasChildren
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: EdgeInsets.only(
              left: widget.depth * 16.0,
              top: 6,
              bottom: 6,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: hasChildren
                      ? AnimatedRotation(
                          turns: _expanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          child: Icon(
                            FLucideIcons.chevronRight,
                            size: 18,
                            color: theme.colors.mutedForeground,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noRequirement ? '${cat.name}[无需]' : cat.name,
                        style: theme.typography.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!noRequirement) ...[
                        const SizedBox(height: 2),
                        Text(
                          '已${_fmtNum(cat.earnedCredits)} / 需${_fmtNum(cat.reqCredits)}',
                          style: theme.typography.body.xs.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!noRequirement)
                  _RingProgress(
                    progress: progress,
                    size: 30,
                    trackColor: theme.colors.border,
                    color: theme.colors.primary,
                    center: Text(
                      '$pct%',
                      style: theme.typography.body.xs.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_expanded && hasChildren)
          Column(
            children: [
              for (var i = 0; i < cat.children.length; i++)
                _AcademicCategoryNode(
                  key: ValueKey('${widget.depth}:$i:${cat.children[i].name}'),
                  category: cat.children[i],
                  theme: theme,
                  depth: widget.depth + 1,
                ),
            ],
          ),
        if (!hasChildren && cat.courses.isNotEmpty)
          _AcademicCourseTable(courses: cat.courses, theme: theme),
      ],
    );
  }
}

bool _academicCategoryHasCourses(AcademicCategory category) =>
    category.courses.isNotEmpty ||
    category.children.any(_academicCategoryHasCourses);

class _AcademicCourseTable extends StatefulWidget {
  const _AcademicCourseTable({required this.courses, required this.theme});

  final List<AcademicCourse> courses;
  final FThemeData theme;

  @override
  State<_AcademicCourseTable> createState() => _AcademicCourseTableState();
}

class _AcademicCourseTableState extends State<_AcademicCourseTable> {
  final _horizontalController = ScrollController();

  static const _columns = <(String, double)>[
    ('成绩学年', 96),
    ('学期', 52),
    ('课程号', 112),
    ('课程名称', 190),
    ('学时', 138),
    ('课程性质', 76),
    ('学分', 62),
    ('课程类别', 128),
    ('最大成绩', 78),
    ('绩点', 62),
    ('成绩', 62),
    ('补考', 76),
    ('重修', 76),
    ('建议修读学年', 116),
    ('学期', 52),
    ('课程重要性系数', 112),
  ];

  double get _tableWidth =>
      _columns.fold<double>(0, (total, column) => total + column.$2);

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return SizedBox(
        width: constraints.maxWidth,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: AppSpacing.sm),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.theme.colors.border.withValues(alpha: 0.7),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AcademicTableRow(
                        values: [for (final column in _columns) column.$1],
                        widths: [for (final column in _columns) column.$2],
                        theme: widget.theme,
                        header: true,
                      ),
                      for (final course in widget.courses)
                        _AcademicTableRow(
                          values: _courseValues(course),
                          widths: [for (final column in _columns) column.$2],
                          theme: widget.theme,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  List<String> _courseValues(AcademicCourse course) => [
    course.academicYear,
    course.term,
    course.courseCode,
    course.name,
    course.hours,
    course.nature,
    course.credit,
    course.category,
    course.maxScore,
    course.gradePoint,
    course.score,
    course.makeup,
    course.retake,
    course.suggestedYear,
    course.suggestedTerm,
    course.importance,
  ];
}

class _AcademicTableRow extends StatelessWidget {
  const _AcademicTableRow({
    required this.values,
    required this.widths,
    required this.theme,
    this.header = false,
  });

  final List<String> values;
  final List<double> widths;
  final FThemeData theme;
  final bool header;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: header
          ? theme.colors.muted
          : theme.colors.muted.withValues(alpha: 0.28),
      border: Border(
        bottom: BorderSide(color: theme.colors.border.withValues(alpha: 0.7)),
      ),
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < values.length; index++)
            SizedBox(
              width: widths[index],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: theme.colors.border.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 7,
                  ),
                  child: Text(
                    values[index].isEmpty ? '暂无' : values[index],
                    textAlign: header ? TextAlign.center : TextAlign.start,
                    style: theme.typography.body.xs.copyWith(
                      color: header
                          ? theme.colors.foreground
                          : theme.colors.mutedForeground,
                      fontWeight: header ? FontWeight.w700 : FontWeight.normal,
                    ),
                    softWrap: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Maps numeric and common textual grades to the four display bands.
int? _scoreBandIndex(String raw) {
  final value = raw.trim();
  final score = double.tryParse(value);
  if (score != null) {
    if (score < 60) return 0;
    if (score < 80) return 1;
    if (score < 90) return 2;
    return 3;
  }

  if (value.contains('优秀')) return 3;
  if (value.contains('良好')) return 2;
  if (value.contains('不及格') ||
      value.contains('不合格') ||
      value.contains('未通过') ||
      value.contains('挂科')) {
    return 0;
  }
  if (value.contains('中等') ||
      value.contains('一般') ||
      value.contains('及格') ||
      value.contains('合格') ||
      value.contains('通过')) {
    return 1;
  }
  return null;
}

/// 学分数字格式化：整数不带小数，其余保留 1 位。
String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
