import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/resource_center.dart';
import '../../services/control_service.dart';
import '../../services/learning_repository.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import 'learning_center_page.dart';

class ResourceCenterPage extends StatefulWidget {
  final LearningRepository repository;

  const ResourceCenterPage({super.key, required this.repository});

  @override
  State<ResourceCenterPage> createState() => _ResourceCenterPageState();
}

class _ResourceCenterPageState extends State<ResourceCenterPage> {
  List<ResourceCourse> _courses = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
      ],
      child: _loading
          ? const AppStateView(icon: FLucideIcons.library, title: '正在加载资源')
          : _courses.isEmpty
          ? AppStateView(
              icon: FLucideIcons.library,
              title: '暂无资源',
              description: _error ?? '暂时没有可用的题库、试卷或电子教材',
            )
          : AppPageBody(
              maxWidth: AppLayout.contentMaxWidth,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 620 ? 3 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1,
                    ),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) {
                      final course = _courses[index];
                      return _CourseCard(
                        course: course,
                        onTap: () => unawaited(_openCourse(context, course)),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Future<void> _openCourse(BuildContext context, ResourceCourse course) async {
    await Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.learning,
        builder: (_) => LearningCenterPage(
          repository: widget.repository,
          course: course,
          coverUrl: course.coverUrl,
        ),
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
    final name = course.name.trim().isEmpty ? course.code : course.name.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _CourseCover(url: course.coverUrl, width: 64, height: 88),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.md.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (course.code.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        course.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodySmall.copyWith(
                          color: theme.colors.mutedForeground,
                          fontSize: 11,
                        ),
                      ),
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
