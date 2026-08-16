import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/cas_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';

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

class _GradeQueryPageState extends State<GradeQueryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  GradeResult? _result;
  AcademicStatus? _academic;
  bool _loading = false;
  int _yearIndex = 0;
  int _termIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_load());
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学业情况'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '学科成绩'),
            Tab(text: '学业详细'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [_buildGradeTab(theme), _buildAcademicTab(theme)],
        ),
      ),
    );
  }

  // ── Grade Tab ──

  Widget _buildGradeTab(ThemeData theme) {
    final grades = _filtered;
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _buildHeader(theme, grades),
        Expanded(child: _buildList(theme, grades)),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, List<GradeItem> grades) {
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
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Column(
        children: [
          if (grades.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '该学期学分',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    totalCredit.toStringAsFixed(1),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '该学期绩点',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${gpa.toStringAsFixed(2)} / 5.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
    ThemeData theme, {
    required String label,
    required bool canPrev,
    required bool canNext,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            onPressed: canPrev ? onPrev : null,
            icon: const Icon(Icons.chevron_left, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            onPressed: canNext ? onNext : null,
            icon: const Icon(Icons.chevron_right, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }

  Widget _buildList(ThemeData theme, List<GradeItem> grades) {
    if (grades.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无成绩',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: grades.length,
      itemBuilder: (_, i) => _buildGradeTile(theme, grades[i]),
    );
  }

  Widget _buildGradeTile(ThemeData theme, GradeItem grade) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grade.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${grade.type} · ${grade.credit}学分 · 绩点${grade.gradePoint}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              grade.score,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: _scoreColor(theme, grade.score),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(ThemeData theme, String score) {
    final n = double.tryParse(score);
    if (n == null) return theme.colorScheme.onSurface;
    if (n >= 90) return Colors.green;
    if (n >= 60) return theme.colorScheme.onSurface;
    return theme.colorScheme.error;
  }

  // ── Academic Tab ──

  Widget _buildAcademicTab(ThemeData theme) {
    if (_loading && _academic == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final status = _academic;
    if (status == null) {
      return const Center(child: Text('点击刷新加载'));
    }

    final progress = status.totalRequired > 0
        ? status.totalEarned / status.totalRequired
        : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _buildGpaRow(theme, status),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${status.totalEarned} / ${status.totalRequired}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < status.categories.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: _buildCategoryRow(theme, status.categories[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGpaRow(ThemeData theme, AcademicStatus status) {
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
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${status.gpa.toStringAsFixed(2)} / 5.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: status.gpa >= 4.0 ? Colors.green : Colors.amber,
              ),
              Text(
                '$pct%',
                style: theme.textTheme.labelSmall?.copyWith(
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

  Widget _buildCategoryRow(ThemeData theme, AcademicCategory cat) {
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
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${cat.earnedCredits} / ${cat.reqCredits}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: cat.missingCredits <= 0 ? Colors.green : Colors.amber,
              ),
              Text(
                '$pct%',
                style: theme.textTheme.labelSmall?.copyWith(
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
