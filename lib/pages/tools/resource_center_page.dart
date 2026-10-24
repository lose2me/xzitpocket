import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';

import '../../models/resource_center.dart';
import '../../services/control_service.dart';
import '../../services/learning_repository.dart';
import '../../services/preferences_storage.dart';
import '../../services/resource_center_cache.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../ui/resource_tag.dart';
import '../../utils/snackbar_helper.dart';
import 'learning_center_page.dart';
import 'resource_upload_page.dart';

class ResourceCenterPage extends StatefulWidget {
  final LearningRepository repository;

  /// Courses from the local timetable, which also lets a course receive its
  /// first upload before the resource centre lists it.
  final List<ResourceCourse> localCourses;

  final PreferencesStorage preferencesStorage;

  const ResourceCenterPage({
    super.key,
    required this.repository,
    required this.preferencesStorage,
    this.localCourses = const [],
  });

  @override
  State<ResourceCenterPage> createState() => _ResourceCenterPageState();
}

class _ResourceCenterPageState extends State<ResourceCenterPage> {
  final _searchController = TextEditingController();
  List<ResourceCourse> _courses = const [];
  Map<String, String> _covers = const {};
  ResourceCenterSnapshot? _snapshot;
  String _query = '';
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _restoreCache();
    unawaited(_load());
  }

  /// Shows the last successful response immediately, so the page works offline
  /// and never flashes a skeleton on a warm start.
  void _restoreCache() {
    final snapshot = ResourceCenterSnapshot.decode(
      widget.preferencesStorage.getResourceCenterCache(),
    );
    if (snapshot == null) return;
    _snapshot = snapshot;
    _courses = snapshot.courses;
    _loading = false;
    unawaited(_loadCovers(snapshot.courses));
  }

  Future<void> _loadCovers(List<ResourceCourse> courses) async {
    final covers = await ResourceCoverCache.instance.displayPaths(courses);
    if (!mounted) return;
    setState(() => _covers = covers);
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

  Future<void> _load({bool force = false}) async {
    final generation = ++_loadGeneration;
    if (_courses.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final control = ControlService.instance;
      if (!force) {
        final cached = _snapshot;
        if (cached != null && cached.version.isNotEmpty) {
          final versions = await control.fetchConfigVersions();
          if (!mounted || generation != _loadGeneration) return;
          if (versions.resourceCenter == cached.version) {
            final covers = await ResourceCoverCache.instance.displayPaths(
              cached.courses,
            );
            final coversComplete = cached.courses.every(
              (course) =>
                  course.coverUrl.trim().isEmpty ||
                  covers.containsKey(course.code),
            );
            if (coversComplete) {
              setState(() {
                _courses = cached.courses;
                _covers = covers;
                _loading = false;
                _error = null;
              });
              return;
            }
          }
        }
      }
      final result = await control.fetchResourceCourses();
      if (!mounted || generation != _loadGeneration) return;
      final snapshot = ResourceCenterSnapshot(
        version: result.version,
        courses: result.courses,
      );
      await widget.preferencesStorage.setResourceCenterCache(snapshot.encode());
      if (!mounted || generation != _loadGeneration) return;
      final covers = await ResourceCoverCache.instance.displayPaths(
        result.courses,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _snapshot = snapshot;
        _courses = result.courses;
        _covers = covers;
        _loading = false;
        _error = null;
      });
      unawaited(_downloadCovers(result.courses));
    } catch (error, stackTrace) {
      talker.warning('资源中心加载失败', error, stackTrace);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        if (_courses.isEmpty) _error = '资源加载失败，请稍后重试';
      });
      if (_courses.isNotEmpty) {
        showAppSnackBar(
          context,
          '刷新失败，正在显示已缓存的数据',
          severity: ToastSeverity.warning,
        );
      }
    }
  }

  Future<void> _downloadCovers(List<ResourceCourse> courses) async {
    final pending = [
      for (final course in courses)
        if (course.coverUrl.trim().isNotEmpty &&
            !_covers.containsKey(course.code))
          course,
    ];
    // A few small WebP files at a time keeps a several-hundred-course list
    // responsive without opening hundreds of sockets at once.
    var next = 0;
    Future<void> worker() async {
      while (mounted) {
        final index = next++;
        if (index >= pending.length) return;
        final course = pending[index];
        final path = await ResourceCoverCache.instance.ensure(course);
        if (path != null && mounted) {
          setState(() => _covers = {..._covers, course.code: path});
        }
      }
    }

    await Future.wait([for (var i = 0; i < 6; i++) worker()]);
    await ResourceCoverCache.instance.prune(courses);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _load(force: true);
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
          icon: FLucideIcons.plus,
          onPress: _loading ? null : () => unawaited(_openUpload()),
          tooltip: '上传教材或试卷',
        ),
      ],
      child: _loading
          ? _buildSkeleton()
          : _courses.isEmpty
          ? AppPageBody(
              maxWidth: AppLayout.contentMaxWidth,
              onRefresh: _refresh,
              child: AppStateView(
                icon: FLucideIcons.packageOpen,
                title: '暂无资源',
                description: _error ?? '暂时没有可用的题库、试卷或电子教材',
              ),
            )
          : _buildCourseList(context),
    );
  }

  Widget _buildSkeleton() {
    return AppPageBody(
      maxWidth: AppLayout.contentMaxWidth,
      child: AppSkeleton(
        label: '正在加载资源',
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: AppSkeletonBox(
                width: double.infinity,
                height: 46,
                radius: 8,
              ),
            ),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                itemCount: 5,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, _) => const _CourseCardSkeleton(),
              ),
            ),
          ],
        ),
      ),
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
                : AppRefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                          coverPath: _covers[course.code],
                          onTap: () => unawaited(_openCourse(context, course)),
                        );
                      },
                    ),
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
        builder: (_) => ResourceUploadPage(
          courses: courses,
          preferencesStorage: widget.preferencesStorage,
        ),
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
        builder: (_) => LearningCenterPage(
          repository: widget.repository,
          course: course,
          preferencesStorage: widget.preferencesStorage,
        ),
      ),
    );
  }
}

class _CourseCardSkeleton extends StatelessWidget {
  const _CourseCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      // 7 + the 1dp border reproduces the 76dp real card height.
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: const [
          AppSkeletonBox(width: 46, height: 62, radius: 8),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 150, height: 14),
                SizedBox(height: 8),
                AppSkeletonBox(width: 92, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final ResourceCourse course;
  final String? coverPath;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.onTap,
    this.coverPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final code = shortCourseCode(course.code);
    final name = course.name.trim();
    final title = name.isNotEmpty ? name : (code.isNotEmpty ? code : '课程');
    final tags = <Widget>[
      if (code.isNotEmpty)
        ResourceTag(
          label: code,
          background: theme.colors.primary.withValues(alpha: 0.18),
          foreground: theme.colors.primary,
        ),
      if (course.textbookCount > 0)
        ResourceTag(
          label: '教材',
          background: theme.colors.destructive.withValues(alpha: 0.12),
          foreground: theme.colors.destructive,
        ),
      if (course.questionBankCount > 0)
        ResourceTag(
          label: '题库',
          background: theme.colors.semantic.warning.withValues(alpha: 0.14),
          foreground: theme.colors.semantic.warning,
        ),
      if (course.resourceCount > 0)
        ResourceTag(
          label: '试卷',
          background: theme.colors.semantic.info.withValues(alpha: 0.12),
          foreground: theme.colors.semantic.info,
        ),
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
              _CourseCover(
                url: course.coverUrl,
                localPath: coverPath,
                width: 46,
                height: 62,
              ),
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
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: tags,
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
  final String? localPath;
  final double width;
  final double height;

  const _CourseCover({
    required this.url,
    required this.width,
    required this.height,
    this.localPath,
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
    final cached = localPath?.trim() ?? '';
    if (cached.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(cached),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        ),
      );
    }
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
