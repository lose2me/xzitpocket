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
import 'learning_question_list_page.dart';
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
  final _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  /// Courses from the local timetable, enriched with the remote row when the
  /// same code exists there so counts, covers and versions are preserved.
  List<ResourceCourse> get _myCourses {
    final remoteByCode = <String, ResourceCourse>{
      for (final course in _courses)
        if (course.code.trim().isNotEmpty) course.code.trim(): course,
    };
    final seen = <String>{};
    return [
      for (final course in widget.localCourses)
        if (course.code.trim().isNotEmpty && seen.add(course.code.trim()))
          remoteByCode[course.code.trim()] ?? course,
    ];
  }

  List<ResourceCourse> get _otherCourses {
    final mine = {for (final course in _myCourses) course.code.trim()};
    return [
      for (final course in _courses)
        if (course.code.trim().isNotEmpty && !mine.contains(course.code.trim()))
          course,
    ];
  }

  bool _matches(ResourceCourse course) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return course.name.toLowerCase().contains(query) ||
        course.code.toLowerCase().contains(query);
  }

  List<_ResourceRow> get _rows {
    final mine = [
      for (final course in _myCourses)
        if (_matches(course)) course,
    ];
    final others = [
      for (final course in _otherCourses)
        if (_matches(course)) course,
    ];
    return [
      for (final course in mine) _ResourceRow.course(course),
      if (mine.isNotEmpty && others.isNotEmpty) const _ResourceRow.divider(),
      for (final course in others) _ResourceRow.course(course),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = AppLayout.pageGutter(context);
          final contentWidth = (constraints.maxWidth - gutter * 2)
              .clamp(0.0, AppLayout.resultMaxWidth)
              .toDouble();
          final horizontal = (constraints.maxWidth - contentWidth) / 2;
          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    AppSpacing.lg,
                    horizontal,
                    AppSpacing.md,
                  ),
                  child: _buildSearchField(),
                ),
                Expanded(child: _buildBody(horizontal)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() => AppTextField(
    controller: _searchController,
    hint: '搜索课程名或课程编号',
    prefix: const Icon(FLucideIcons.search),
    clearable: true,
    onChanged: (value) => setState(() => _query = value),
  );

  Widget _buildBody(double horizontal) {
    if (_loading) return _buildSkeleton(horizontal);
    final rows = _rows;
    if (rows.isEmpty) return _buildEmpty(horizontal);
    final children = <Widget>[
      _buildCollectionActions(),
      for (final row in rows)
        if (row.course == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Container(
              height: 1,
              color: context.theme.colors.primary.withValues(alpha: 0.22),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.listGap),
            child: _CourseCard(
              course: row.course!,
              coverPath: _covers[row.course!.code],
              onTap: () => unawaited(_openCourse(context, row.course!)),
            ),
          ),
      const SizedBox(height: AppSpacing.xxl),
    ];
    return _buildRefreshable([
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        sliver: SliverList(delegate: SliverChildListDelegate(children)),
      ),
    ]);
  }

  Widget _buildRefreshable(List<Widget> slivers) => AppRefreshIndicator(
    onRefresh: _refresh,
    child: Scrollbar(
      controller: _scrollController,
      thumbVisibility: false,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    ),
  );

  Widget _buildCollectionActions() => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: AppDashedButton(
            icon: FLucideIcons.circleAlert,
            label: '错题集',
            onPress: () => _openCollection(LearningListKind.wrong),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppDashedButton(
            icon: FLucideIcons.bookmark,
            label: '收藏集',
            onPress: () => _openCollection(LearningListKind.favorite),
          ),
        ),
      ],
    ),
  );

  Widget _buildEmpty(double horizontal) {
    final searching = _query.trim().isNotEmpty;
    return _buildRefreshable([
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        sliver: SliverToBoxAdapter(child: _buildCollectionActions()),
      ),
      SliverFillRemaining(
        hasScrollBody: false,
        child: AppStateView(
          icon: searching ? FLucideIcons.searchX : FLucideIcons.packageOpen,
          title: searching ? '没有匹配的课程' : '暂无资源',
          description: searching ? '换个关键词再试试' : (_error ?? '暂时没有可用的题库、试卷或电子教材'),
        ),
      ),
    ]);
  }

  void _openCollection(LearningListKind kind) {
    Navigator.of(context).push(
      appRoute(
        name: kind == LearningListKind.wrong
            ? AppRouteNames.learningWrongQuestions
            : AppRouteNames.learningFavorites,
        builder: (_) =>
            LearningQuestionListPage(repository: widget.repository, kind: kind),
      ),
    );
  }

  Widget _buildSkeleton(double horizontal) => ListView(
    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, AppSpacing.xxl),
    children: [
      _buildCollectionActions(),
      AppSkeleton(
        label: '正在加载资源',
        child: Column(
          children: [
            for (var index = 0; index < 5; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.listGap),
                child: const _CourseCardSkeleton(),
              ),
          ],
        ),
      ),
    ],
  );

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
          ownCourseCodes: {
            for (final course in widget.localCourses)
              if (course.code.trim().isNotEmpty) course.code.trim(),
          },
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
    return const AppCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppSkeletonBox(width: 46, height: 62, radius: 8),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 150, height: 16),
                SizedBox(height: AppSpacing.sm),
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
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onPress: onTap,
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
                  style: theme.typography.tileTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
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

class _ResourceRow {
  final ResourceCourse? course;

  const _ResourceRow.course(ResourceCourse this.course);
  const _ResourceRow.divider() : course = null;
}
