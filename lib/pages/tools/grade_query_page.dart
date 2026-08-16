import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/auth_service.dart';
import '../../services/cas_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

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
        _termIndex = 0;
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('学业情况查询失败', e, stackTrace);
      if (mounted) showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      talker.error('学业情况查询异常', e, stackTrace);
      if (mounted) showAppSnackBar(context, '加载失败');
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
              label: const Text('学业详细'),
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
    final years = _result?.years ?? [];
    final terms = _terms;
    final yi = _yearIndex.clamp(0, years.length - 1);
    final ti = _termIndex.clamp(0, terms.length - 1);

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
        children: [
          if (grades.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '该学期学分',
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(width: 4),
                FBadge(
                  variant: FBadgeVariant.outline,
                  child: Text(totalCredit.toStringAsFixed(1)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '该学期绩点',
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(width: 4),
                FBadge(
                  variant: FBadgeVariant.outline,
                  child: Text('${gpa.toStringAsFixed(2)} / 5.0'),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pager(
                theme,
                label: years.isNotEmpty ? years[yi] : '',
                canPrev: yi > 0,
                canNext: yi < years.length - 1,
                onPrev: () => setState(() {
                  _yearIndex = yi - 1;
                  _termIndex = 0;
                }),
                onNext: () => setState(() {
                  _yearIndex = yi + 1;
                  _termIndex = 0;
                }),
              ),
              const SizedBox(width: 8),
              _pager(
                theme,
                label: terms.isNotEmpty ? '第${terms[ti]}学期' : '',
                canPrev: ti > 0,
                canNext: ti < terms.length - 1,
                onPrev: () => setState(() => _termIndex = ti - 1),
                onNext: () => setState(() => _termIndex = ti + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pager(
    FThemeData theme, {
    required String label,
    required bool canPrev,
    required bool canNext,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(
          icon: FLucideIcons.chevronLeft,
          onPress: canPrev ? onPrev : null,
          tooltip: '上一项',
          size: FButtonSizeVariant.xs,
        ),
        Text(
          label,
          style: theme.typography.body.md.copyWith(fontWeight: FontWeight.w600),
        ),
        AppIconButton(
          icon: FLucideIcons.chevronRight,
          onPress: canNext ? onNext : null,
          tooltip: '下一项',
          size: FButtonSizeVariant.xs,
        ),
      ],
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
                  child: _buildCategoryRow(theme, status.categories[i]),
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
        SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(width: 36, child: FDeterminateProgress(value: progress)),
              Text(
                '$pct%',
                style: theme.typography.body.xs.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(FThemeData theme, AcademicCategory cat) {
    final progress = cat.reqCredits > 0
        ? (cat.earnedCredits / cat.reqCredits).clamp(0.0, 1.0)
        : 0.0;
    final pct = (progress * 100).toInt();

    return Row(
      children: [
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
                '${cat.earnedCredits} / ${cat.reqCredits}',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(width: 36, child: FDeterminateProgress(value: progress)),
              Text(
                '$pct%',
                style: theme.typography.body.xs.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
