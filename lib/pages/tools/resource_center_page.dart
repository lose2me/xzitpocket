import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/resource_center.dart';
import '../../services/control_service.dart';
import '../../services/learning_repository.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';
import 'learning_center_page.dart';
import 'resource_upload_page.dart';

class ResourceCenterPage extends StatefulWidget {
  final LearningRepository repository;

  /// Courses from the local timetable, which also lets a course receive its
  /// first upload before the resource centre lists it.
  final List<ResourceCourse> localCourses;

  const ResourceCenterPage({
    super.key,
    required this.repository,
    this.localCourses = const [],
  });

  @override
  State<ResourceCenterPage> createState() => _ResourceCenterPageState();
}

class _ResourceCenterPageState extends State<ResourceCenterPage> {
  final _searchController = TextEditingController();
  List<ResourceCourse> _courses = const [];
  String _query = '';
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ResourceCourse> get _filteredCourses {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _courses;
    return [
      for (final course in _courses)
        if (course.name.toLowerCase().contains(query) ||
            course.code.toLowerCase().contains(query))
          course,
    ];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final courses = await ControlService.instance.fetchResourceCourses();
      if (!mounted) return;
      setState(() => _courses = courses);
    } catch (error, stackTrace) {
      talker.warning('资源中心加载失败', error, stackTrace);
      if (!mounted) return;
      setState(() => _error = '资源加载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '资源中心',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _refreshing ? null : _refresh,
          tooltip: '刷新资源',
          loading: _refreshing,
        ),
        AppIconButton(
          icon: FLucideIcons.plus,
          onPress: _loading ? null : () => unawaited(_openUpload()),
          tooltip: '上传教材或试卷',
        ),
      ],
      child: _loading
          ? const AppStateView(icon: FLucideIcons.library, title: '正在加载资源')
          : _courses.isEmpty
          ? AppStateView(
              icon: FLucideIcons.library,
              title: '暂无资源',
              description: _error ?? '暂时没有可用的题库、试卷或电子教材',
            )
          : _buildCourseList(context),
    );
  }

  Widget _buildCourseList(BuildContext context) {
    final theme = context.theme;
    final courses = _filteredCourses;
    return AppPageBody(
      maxWidth: AppLayout.contentMaxWidth,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: AppTextField(
              controller: _searchController,
              hint: '搜索课程名或课程编号',
              prefix: const Icon(FLucideIcons.search),
              clearable: true,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: courses.isEmpty
                ? Center(
                    child: Text(
                      '没有匹配的课程',
                      style: theme.typography.bodySmall.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.xxl,
                    ),
                    itemCount: courses.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      return _CourseCard(
                        course: course,
                        onTap: () => unawaited(_openCourse(context, course)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUpload() async {
    final byCode = <String, ResourceCourse>{};
    for (final course in [...widget.localCourses, ..._courses]) {
      final code = course.code.trim();
      if (code.isEmpty) continue;
      byCode.putIfAbsent(code, () => course);
    }
    final courses = byCode.values.toList();
    if (courses.isEmpty) {
      showAppSnackBar(context, '暂无可上传的课程', severity: ToastSeverity.warning);
      return;
    }
    final submitted = await Navigator.of(context).push<bool>(
      appRoute(
        name: AppRouteNames.resourceUpload,
        builder: (_) => ResourceUploadPage(courses: courses),
      ),
    );
    if (submitted != true || !mounted) return;
    showAppSnackBar(
      context,
      '已提交审核，通过后会出现在资源中心',
      severity: ToastSeverity.success,
    );
  }

  Future<void> _openCourse(BuildContext context, ResourceCourse course) async {
    // 收起搜索框焦点，返回资源中心时不再自动弹出键盘。
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.learning,
        builder: (_) =>
            LearningCenterPage(repository: widget.repository, course: course),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final ResourceCourse course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final code = course.code.trim();
    final name = course.name.trim();
    final title = code.isNotEmpty ? code : (name.isNotEmpty ? name : '课程');
    final tags = <Widget>[
      if (course.textbookCount > 0)
        _ResourceTypeTag(label: '教材', color: theme.colors.destructive),
      if (course.questionBankCount > 0)
        _ResourceTypeTag(label: '题库', color: theme.colors.primary),
      if (course.resourceCount > 0)
        _ResourceTypeTag(label: '试卷', color: theme.colors.semantic.info),
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _CourseCover(url: course.coverUrl, width: 46, height: 62),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.md.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (code.isNotEmpty && name.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodySmall.copyWith(
                          color: theme.colors.mutedForeground,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(spacing: 4, runSpacing: 2, children: tags),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceTypeTag extends StatelessWidget {
  final String label;
  final Color color;

  const _ResourceTypeTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return ClipPath(
      clipper: const _SwallowtailTagClipper(),
      child: Container(
        height: 18,
        padding: const EdgeInsets.only(left: 10, right: 12),
        color: color,
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.theme.typography.bodySmall.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _SwallowtailTagClipper extends CustomClipper<Path> {
  static const _point = 6.0;
  static const _notch = 5.0;

  const _SwallowtailTagClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(_point, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width - _notch, size.height / 2)
    ..lineTo(size.width, size.height)
    ..lineTo(_point, size.height)
    ..lineTo(0, size.height / 2)
    ..close();

  @override
  bool shouldReclip(covariant _SwallowtailTagClipper oldClipper) => false;
}

class _CourseCover extends StatelessWidget {
  final String url;
  final double width;
  final double height;

  const _CourseCover({
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final placeholder = CustomPaint(
      painter: _DashedBorderPainter(color: theme.colors.border),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Icon(
            FLucideIcons.bookOpen,
            size: 20,
            color: theme.colors.mutedForeground,
          ),
        ),
      ),
    );
    final value = url.trim();
    if (value.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        value,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      );
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + dash, metric.length),
          ),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
