import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/auth_service.dart';
import '../../services/cas_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

typedef _SemesterOption = ({
  int yearIndex,
  int termIndex,
  String label,
  String key,
});

class GradeQueryPage extends StatefulWidget {
  final String studentId;
  final String password;

  const GradeQueryPage({
    super.key,
    required this.studentId,
    required this.password,
  });

  @override
  State<GradeQueryPage> createState() => _GradeQueryPageState();
}

class _GradeQueryPageState extends State<GradeQueryPage> {
  GradeResult? _result;
  AcademicStatus? _academic;
  bool _loading = false;
  int _yearIndex = 0;
  int _termIndex = 0;
  GradeResult? _semesterOptionsSource;
  List<_SemesterOption> _semesterOptionsCache = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final (grades, academic) = await AuthService().fetchGradesAndAcademic(
        widget.studentId,
        widget.password,
      );
      if (!mounted) return;
      setState(() {
        _result = grades;
        _academic = academic;
        _yearIndex = 0;
        // 默认显示最新学期：最新学年 + 该学年最后一个学期
        final latestYear = grades.years.isNotEmpty ? grades.years.first : null;
        final latestTerms = latestYear == null
            ? const <String>[]
            : (grades.termsByYear[latestYear] ?? const <String>[]);
        _termIndex = latestTerms.isEmpty ? 0 : latestTerms.length - 1;
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

  String? get _selectedYear {
    final years = _result?.years;
    if (years == null || years.isEmpty) return null;
    return years[_yearIndex.clamp(0, years.length - 1)];
  }

  List<String> get _terms {
    final year = _selectedYear;
    if (year == null) return [];
    return _result?.termsByYear[year] ?? [];
  }

  String? get _selectedTerm {
    final terms = _terms;
    if (terms.isEmpty) return null;
    return terms[_termIndex.clamp(0, terms.length - 1)];
  }

  List<GradeItem> get _filtered {
    if (_result == null) return [];
    final year = _selectedYear;
    final term = _selectedTerm;
    if (year == null || term == null) return [];
    return _result!.grades
        .where((g) => g.year == year && g.term == term)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppPage(
      title: '学业情况',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _loading ? null : _load,
          tooltip: '刷新成绩',
          loading: _loading,
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
    return AppPageBody(
      maxWidth: AppLayout.resultMaxWidth,
      safeArea: false,
      child: Column(
        children: [
          _buildHeader(theme, grades),
          Expanded(child: _buildList(theme, grades)),
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
      padding: EdgeInsets.fromLTRB(
        AppLayout.pageGutter(context),
        AppSpacing.xs,
        AppLayout.pageGutter(context),
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 学年+学期 二合一：横向滚动选择栏
          _buildSemesterSelector(theme),
          if (grades.isNotEmpty) ...[
            const SizedBox(height: 6),
            // 学分/绩点摘要：无边框、小字号，位于选择栏下方
            _buildSummaryRow(theme, totalCredit, gpa),
          ],
        ],
      ),
    );
  }

  /// 学年 + 学期 合并成单个选项（新→旧），供滚动选择栏直接选择。
  List<_SemesterOption> get _semesterOptions {
    final result = _result;
    if (identical(result, _semesterOptionsSource)) {
      return _semesterOptionsCache;
    }

    final options = <_SemesterOption>[];
    final years = result?.years ?? const <String>[];
    for (var y = 0; y < years.length; y++) {
      final terms = result?.termsByYear[years[y]] ?? const <String>[];
      // 同一学年内按学期倒序，让"最新学期"排在最前。
      for (var t = terms.length - 1; t >= 0; t--) {
        options.add((
          yearIndex: y,
          termIndex: t,
          label: _formatSemesterLabel(years[y], terms[t]),
          key: '$y|$t',
        ));
      }
    }
    _semesterOptionsSource = result;
    _semesterOptionsCache = options;
    return _semesterOptionsCache;
  }

  /// 把学年/学期原始值格式化为下拉显示文本，如 "2025-2026 1" → "25学年第1学期"。
  String _formatSemesterLabel(String year, String term) {
    final startYear = year.split('-').first.trim();
    final short = startYear.length >= 4
        ? startYear.substring(startYear.length - 2)
        : startYear;
    final t = term.trim();
    String semester;
    if (t.startsWith('第')) {
      semester = t;
    } else if (int.tryParse(t) != null) {
      semester = '第$t学期';
    } else {
      semester = t;
    }
    return '$short学年$semester';
  }

  String _optionLabel(String key) {
    for (final o in _semesterOptions) {
      if (o.key == key) return o.label;
    }
    return _semesterOptions.isEmpty ? '' : _semesterOptions.first.label;
  }

  Widget _buildSemesterSelector(FThemeData theme) {
    final options = _semesterOptions;
    if (options.isEmpty) return const SizedBox.shrink();
    final selectedIndex = options.indexWhere(
      (o) => o.yearIndex == _yearIndex && o.termIndex == _termIndex,
    );
    if (selectedIndex < 0) return const SizedBox.shrink();
    final selectedKey = options[selectedIndex].key;

    return SizedBox(
      width: double.infinity,
      child: FSelect<String>.rich(
        control: FSelectControl.lifted(
          value: selectedKey,
          onChange: (key) {
            if (key == null) return;
            for (final o in options) {
              if (o.key == key) {
                setState(() {
                  _yearIndex = o.yearIndex;
                  _termIndex = o.termIndex;
                });
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

  /// 学分 / 绩点摘要行：无边框胶囊、小字号，左对齐。
  Widget _buildSummaryRow(FThemeData theme, double totalCredit, double gpa) {
    // 学分靠左、绩点靠右，与下方成绩卡片左右边缘对齐。
    return SizedBox(
      width: double.infinity,
      child: Row(
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
      ),
    );
  }

  Widget _buildList(FThemeData theme, List<GradeItem> grades) {
    if (grades.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FLucideIcons.graduationCap,
              size: 48,
              color: theme.colors.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无成绩',
              style: theme.typography.tileTitle.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppLayout.pageGutter(context),
        AppSpacing.xs,
        AppLayout.pageGutter(context),
        AppSpacing.xxl,
      ),
      itemCount: grades.length,
      itemBuilder: (_, i) => _buildGradeTile(theme, grades[i]),
    );
  }

  Widget _buildGradeTile(FThemeData theme, GradeItem grade) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grade.name,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${grade.type} · ${grade.credit}学分 · 绩点${grade.gradePoint}',
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              grade.score,
              style: theme.typography.metric.copyWith(
                fontWeight: FontWeight.w700,
                color: _scoreColor(theme, grade.score),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(FThemeData theme, String score) {
    final n = double.tryParse(score);
    if (n == null) return theme.colors.foreground;
    if (n >= 90) return theme.colors.primary;
    if (n >= 60) return theme.colors.foreground;
    return theme.colors.destructive;
  }

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
  // 顶层平台默认展开，更深层的模块/课程组默认折叠。
  late bool _expanded = widget.depth == 0;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final theme = widget.theme;
    final hasChildren = cat.children.isNotEmpty;
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
            padding: const EdgeInsets.symmetric(vertical: 6),
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
                        cat.name,
                        style: theme.typography.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '已${_fmtNum(cat.earnedCredits)} / 需${_fmtNum(cat.reqCredits)}',
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
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
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
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
          ),
      ],
    );
  }
}

/// 学分数字格式化：整数不带小数，其余保留 1 位。
String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
