import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../providers/config_provider.dart';
import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/auth_service.dart';
import '../../services/credential_storage.dart';
import '../../services/talker.dart';
import '../../services/preferences_storage.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/exam_utils.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import '../../services/learning_repository.dart';
import '../../services/control_service.dart';
import 'exam_query_page.dart';
import 'grade_query_page.dart';
import 'campus_card_page.dart';
import 'network_management_page.dart';
import 'power_query_page.dart';
import 'repair_page.dart';
import 'teacher_evaluation_page.dart';
import 'school_calendar_page.dart';
import 'learning_center_page.dart';

class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  static final globalKey = GlobalKey<ToolsPageState>();

  @override
  ConsumerState<ToolsPage> createState() => ToolsPageState();
}

class ToolsPageState extends ConsumerState<ToolsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _manager = ToolsDataManager.instance;
  Timer? _controlHealthTimer;
  bool _controlAvailable = false;
  bool _refreshingTabData = false;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManagerUpdate);
    unawaited(_refreshControlAvailability());
    _controlHealthTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_refreshControlAvailability()),
    );
  }

  @override
  void dispose() {
    _controlHealthTimer?.cancel();
    _manager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshControlAvailability() async {
    if (!mounted) return;
    if (ref
        .read(appSettingsProvider)
        .hiddenServiceFeatures
        .contains(AppServiceFeature.learning)) {
      if (_controlAvailable) setState(() => _controlAvailable = false);
      return;
    }
    final available = await ControlService.instance.checkHealth();
    if (!mounted) return;
    setState(() {
      _controlAvailable = available;
    });
  }

  Future<void> refreshData() async {
    if (_refreshingTabData) return;
    setState(() => _refreshingTabData = true);
    unawaited(_refreshControlAvailability());
    try {
      final config = ref.read(configProvider);
      if (config.studentId == null || config.studentId!.isEmpty) return;
      final password = await CredentialStorage.getSavedPassword();
      if (password == null || password.isEmpty) return;

      final prefs = ref.read(preferencesStorageProvider);
      final hidden = ref.read(appSettingsProvider).hiddenServiceFeatures;
      bool visible(AppServiceFeature feature) => !hidden.contains(feature);
      await _manager.refreshOnTabSwitch(
        studentId: config.studentId!,
        password: password,
        prefs: prefs,
        roomId: prefs.getSavedPowerRoomId(),
        loadYktData: visible(AppServiceFeature.campusCard),
        loadPowerData: visible(AppServiceFeature.power),
        loadExamData: visible(AppServiceFeature.exams),
      );
    } finally {
      if (mounted) setState(() => _refreshingTabData = false);
    }
  }

  // ── Open methods ──

  Future<({String studentId, String password})?> _ensureCredentials() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      showAppSnackBar(context, '此功能需登录使用', severity: ToastSeverity.warning);
      return null;
    }
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, '此功能需登录使用', severity: ToastSeverity.warning);
      }
      return null;
    }
    return (studentId: config.studentId!, password: password);
  }

  Future<void> _openTool<T>({
    required bool loading,
    required String logLabel,
    required String routeName,
    required T? Function() getData,
    required Future<bool> Function(
      String sid,
      String pwd,
      PreferencesStorage prefs,
    )
    load,
    required Widget Function(T data, String sid, String pwd) buildPage,
    bool requiresCampus = false,
  }) async {
    if (loading) return;
    talker.info('[ACTION] $logLabel');

    final hasNet = await _manager.checkInternetAvailable();
    if (!hasNet) {
      if (mounted) {
        showAppSnackBar(context, '请连接网络', severity: ToastSeverity.warning);
      }
      return;
    }

    if (requiresCampus) {
      final campusOk = await _manager.checkCampusNetwork();
      if (!campusOk) {
        if (mounted) {
          showAppSnackBar(context, '请连接校园网', severity: ToastSeverity.warning);
        }
        return;
      }
    }

    final creds = await _ensureCredentials();
    if (creds == null || !mounted) return;

    final hadData = getData() != null;
    if (!hadData) {
      final prefs = ref.read(preferencesStorageProvider);
      await load(creds.studentId, creds.password, prefs);
      if (!mounted || getData() == null) return;
    }
    Navigator.of(context).push(
      appRoute(
        name: routeName,
        builder: (_) =>
            buildPage(getData() as T, creds.studentId, creds.password),
      ),
    );
  }

  Future<void> _openExamQuery() => _openTool(
    loading: _manager.examLoading,
    logLabel: '打开考试查询',
    routeName: AppRouteNames.exams,
    getData: () => _manager.exams,
    load: _manager.loadExam,
    buildPage: (data, sid, pwd) => ExamQueryPage(
      result: data,
      studentId: sid,
      password: pwd,
      preferencesStorage: ref.read(preferencesStorageProvider),
    ),
  );

  Future<void> _openYkt() => _openTool(
    loading: _manager.yktLoading,
    logLabel: '打开一卡通查询',
    routeName: AppRouteNames.campusCard,
    getData: () => _manager.ykt,
    load: _manager.loadYkt,
    buildPage: (data, sid, pwd) => CampusCardPage(
      result: data,
      studentId: sid,
      password: pwd,
      preferencesStorage: ref.read(preferencesStorageProvider),
    ),
  );

  Future<void> _openRepair() => _openTool(
    loading: _manager.repairLoading,
    logLabel: '打开极速报修',
    routeName: AppRouteNames.repair,
    getData: () => _manager.repair,
    load: _manager.loadRepair,
    buildPage: (data, sid, pwd) => RepairPage(
      initialResult: data,
      studentId: sid,
      password: pwd,
      preferencesStorage: ref.read(preferencesStorageProvider),
    ),
  );

  Future<void> _openLearningCenter() async {
    final control = ControlService.instance;
    if (!_controlAvailable) return;
    final repository = LearningRepository(
      preferencesStorage: ref.read(preferencesStorageProvider),
      bankFetcher: control.isConfigured
          ? control.fetchLearningQuestionBanks
          : null,
      cdkRedeemer: control.isConfigured ? control.redeemLibraryCdk : null,
    );
    if (!mounted) return;
    unawaited(
      control.track(
        'library_open',
        properties: const {'screen': 'learning_center'},
      ),
    );
    Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.learning,
        builder: (_) => LearningCenterPage(repository: repository),
      ),
    );
  }

  Future<void> _openNetAuth() => _openTool(
    loading: _manager.netAuthLoading,
    logLabel: '打开网络管理',
    routeName: AppRouteNames.networkManagement,
    getData: () => _manager.netAuth,
    load: _manager.loadNetAuth,
    buildPage: (data, sid, pwd) => NetworkManagementPage(
      result: data,
      account: sid,
      password: pwd,
      preferencesStorage: ref.read(preferencesStorageProvider),
    ),
  );

  Future<void> _openSchoolCalendar() async {
    await Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.schoolCalendar,
        builder: (_) => const SchoolCalendarPage(),
      ),
    );
  }

  Future<void> _openJp() async {
    if (!_manager.isCampusNetworkAvailable) return;
    await _openTool(
      loading: _manager.jpLoading,
      logLabel: '打开教师评价',
      routeName: AppRouteNames.teacherEvaluation,
      getData: () => _manager.jp,
      load: _manager.loadJp,
      requiresCampus: true,
      buildPage: (data, _, _) => TeacherEvaluationPage(result: data),
    );
  }

  Future<void> _openGradeQuery() async {
    final hasNet = await _manager.checkInternetAvailable();
    if (!hasNet) {
      if (mounted) {
        showAppSnackBar(context, '请连接网络', severity: ToastSeverity.warning);
      }
      return;
    }
    final creds = await _ensureCredentials();
    if (creds == null || !mounted) return;
    Navigator.of(context).push(
      appRoute(
        name: AppRouteNames.academic,
        builder: (_) => GradeQueryPage(
          studentId: creds.studentId,
          password: creds.password,
          preferencesStorage: ref.read(preferencesStorageProvider),
        ),
      ),
    );
  }

  // ── Power refresh (manual) ──

  Future<void> _refreshPower() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      showAppSnackBar(context, '此功能需登录使用', severity: ToastSeverity.warning);
      return;
    }

    if (!_manager.isCampusNetworkAvailable) {
      showAppSnackBar(context, '请连接校园网', severity: ToastSeverity.warning);
      return;
    }

    final hasNet = await _manager.checkInternetAvailable();
    if (!hasNet) {
      if (mounted) {
        showAppSnackBar(context, '请连接网络', severity: ToastSeverity.warning);
      }
      return;
    }

    final prefs = ref.read(preferencesStorageProvider);
    final roomId = prefs.getSavedPowerRoomId();
    if (roomId == null || roomId.isEmpty) return;

    await _manager.loadPower(roomId, prefs);
    if (!mounted) return;
    if (_manager.powerError != null) {
      showAppSnackBar(
        context,
        _manager.powerError!,
        severity: ToastSeverity.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = context.theme;
    final settings = ref.watch(appSettingsProvider);
    final hidden = settings.hiddenServiceFeatures;
    bool visible(AppServiceFeature feature) => !hidden.contains(feature);
    final roomId = ref.watch(savedRoomIdProvider);
    final hasRoom = roomId != null && roomId.isNotEmpty;
    final campusAvailable = _manager.isCampusNetworkAvailable;
    final config = ref.watch(configProvider);
    final learningLoggedIn = config.studentId?.isNotEmpty == true;
    final learningEnabled = _controlAvailable && learningLoggedIn;

    ref.listen(savedRoomIdProvider, (prev, next) {
      _manager.clearPower();
      if (visible(AppServiceFeature.power) && next != null && next.isNotEmpty) {
        final prefs = ref.read(preferencesStorageProvider);
        unawaited(_manager.loadPower(next, prefs));
      }
    });

    final cards = <Widget>[];
    void addCard(Widget card) {
      if (cards.isNotEmpty) cards.add(const SizedBox(height: AppSpacing.md));
      cards.add(card);
    }

    final showCampusCard = visible(AppServiceFeature.campusCard);
    final showPower = visible(AppServiceFeature.power);
    if (showCampusCard && showPower) {
      addCard(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildYktCard(theme)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _buildPowerCard(theme, hasRoom, roomId)),
            ],
          ),
        ),
      );
    } else if (showCampusCard) {
      addCard(_buildYktCard(theme));
    } else if (showPower) {
      addCard(_buildPowerCard(theme, hasRoom, roomId));
    }

    if (visible(AppServiceFeature.exams)) addCard(_buildExamCard(theme));
    if (visible(AppServiceFeature.academic)) {
      addCard(
        _buildSimpleCard(
          theme,
          icon: FLucideIcons.graduationCap,
          title: '学业情况',
          onTap: _openGradeQuery,
        ),
      );
    }
    if (visible(AppServiceFeature.network)) {
      addCard(
        _buildSimpleCard(
          theme,
          icon: FLucideIcons.wifi,
          title: '网络管理',
          onTap: _manager.netAuthLoading ? null : _openNetAuth,
        ),
      );
    }
    if (visible(AppServiceFeature.repair)) {
      addCard(
        _buildSimpleCard(
          theme,
          icon: FLucideIcons.wrench,
          title: '极速报修',
          onTap: _manager.repairLoading ? null : _openRepair,
        ),
      );
    }
    if (visible(AppServiceFeature.learning)) {
      addCard(
        _buildSimpleCard(
          theme,
          icon: FLucideIcons.graduationCap,
          title: '学习中心',
          onTap: learningEnabled ? _openLearningCenter : null,
        ),
      );
    }
    if (visible(AppServiceFeature.calendar)) {
      addCard(
        _buildSimpleCard(
          theme,
          icon: FLucideIcons.calendarDays,
          title: '学校校历',
          onTap: _openSchoolCalendar,
        ),
      );
    }
    if (visible(AppServiceFeature.teacherEvaluation)) {
      addCard(
        _buildSimpleCard(
          theme,
          icon: FLucideIcons.messageSquareMore,
          title: '教师评价',
          onTap: campusAvailable && !_manager.jpLoading ? _openJp : null,
        ),
      );
    }

    return AppPage(
      title: '便捷服务',
      root: true,
      headerStyle: FHeaderStyleDelta.delta(
        titleTextStyle: TextStyleDelta.value(
          context.theme.typography.display.xl.copyWith(
            color: context.theme.colors.foreground,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: cards,
      ),
    );
  }

  Widget _buildSimpleCard(
    FThemeData theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    bool loading = false,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null && !loading;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onPress: enabled ? onTap : null,
      child: Row(
        children: [
          Icon(
            icon,
            color: enabled
                ? theme.colors.primary
                : theme.colors.mutedForeground,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.typography.tileTitle.copyWith(
                    color: enabled
                        ? theme.colors.foreground
                        : theme.colors.mutedForeground,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.typography.bodySmall.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
            )
          else if (enabled)
            Icon(
              FLucideIcons.chevronRight,
              color: theme.colors.mutedForeground,
            ),
        ],
      ),
    );
  }

  Widget _buildExamCard(FThemeData theme) {
    final now = DateTime.now();
    final exams =
        _manager.exams?.exams.where((e) {
          final d = parseExamDate(e.time);
          return d == null || !d.isBefore(now);
        }).toList()?..sort((a, b) {
          final da = parseExamDate(a.time);
          final db = parseExamDate(b.time);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
    final nextExam = exams != null && exams.isNotEmpty ? exams.first : null;

    String examTimeLabel(ExamItem exam) {
      final d = parseExamDate(exam.time);
      if (d == null) return exam.time;
      final today = DateTime.now();
      final days = DateTime(
        d.year,
        d.month,
        d.day,
      ).difference(DateTime(today.year, today.month, today.day)).inDays;
      if (days < 0) return exam.time;
      final tag = switch (days) {
        0 => '今天',
        1 => '明天',
        2 => '后天',
        _ => '剩 $days 天',
      };
      return '${exam.time} [$tag]';
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onPress: _manager.examLoading ? null : _openExamQuery,
      child: Row(
        children: [
          Expanded(
            child: nextExam != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FLucideIcons.fileQuestion,
                            color: theme.colors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '考试查询',
                            style: theme.typography.bodySmall.copyWith(
                              color: theme.colors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        nextExam.title,
                        style: theme.typography.tileTitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (nextExam.time.isNotEmpty)
                        Text(
                          examTimeLabel(nextExam),
                          style: theme.typography.bodySmall.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        FLucideIcons.fileQuestion,
                        color: theme.colors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text('考试查询', style: theme.typography.tileTitle),
                    ],
                  ),
          ),
          if (_manager.examLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
            )
          else
            Icon(
              FLucideIcons.chevronRight,
              color: theme.colors.mutedForeground,
            ),
        ],
      ),
    );
  }

  Widget _buildYktCard(FThemeData theme) {
    final balance = _manager.ykt?.balance;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onPress: _manager.yktLoading ? null : _openYkt,
      child: Row(
        children: [
          Expanded(
            child: balance != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FLucideIcons.creditCard,
                            size: 16,
                            color: theme.colors.mutedForeground,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '一卡通查询',
                            style: theme.typography.bodySmall.copyWith(
                              color: theme.colors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${balance.balance} 元',
                        style: theme.typography.metric,
                      ),
                    ],
                  )
                : Text('一卡通查询', style: theme.typography.tileTitle),
          ),
          if (_manager.yktLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
            )
          else
            Icon(
              FLucideIcons.chevronRight,
              color: theme.colors.mutedForeground,
            ),
        ],
      ),
    );
  }

  Widget _buildPowerCard(FThemeData theme, bool hasRoom, String? roomId) {
    final data = _manager.power;
    final campusAvailable = _manager.isCampusNetworkAvailable;
    final campusChecking =
        _manager.campusNetworkStatus == CampusNetworkStatus.checking;

    String statusText;
    TextStyle? statusStyle;
    // 先检测校园网连接，再考虑是否已填写宿舍号。
    if (!campusAvailable) {
      statusText = campusChecking ? '正在检测校园网' : '请连接校园网';
      statusStyle = theme.typography.bodySmall.copyWith(
        color: theme.colors.mutedForeground,
      );
    } else if (!hasRoom) {
      statusText = '请先在「我的」中设置宿舍号';
      statusStyle = theme.typography.bodySmall.copyWith(
        color: theme.colors.mutedForeground,
      );
    } else if (data != null) {
      statusText = '${data.available} 度';
      statusStyle = theme.typography.metric;
    } else if (_manager.powerLoading) {
      statusText = '';
      statusStyle = null;
    } else {
      statusText = '暂无数据，点击刷新';
      statusStyle = theme.typography.bodySmall.copyWith(
        color: theme.colors.mutedForeground,
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onPress: hasRoom && data != null
          ? () => Navigator.of(context).push(
              appRoute(
                name: AppRouteNames.electricity,
                builder: (_) => PowerQueryPage(
                  result: data,
                  roomId: roomId,
                  preferencesStorage: ref.read(preferencesStorageProvider),
                ),
              ),
            )
          : hasRoom && campusAvailable && !_manager.powerLoading
          ? _refreshPower
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      FLucideIcons.zap,
                      size: 16,
                      color: theme.colors.mutedForeground,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '电费查询',
                      style: theme.typography.bodySmall.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                if (statusText.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    statusText,
                    style: statusStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (_manager.powerLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
            )
          else if (hasRoom && data != null)
            Icon(FLucideIcons.chevronRight, color: theme.colors.mutedForeground)
          else if (hasRoom && campusAvailable && !_manager.powerLoading)
            AppIconButton(
              icon: FLucideIcons.refreshCw,
              onPress: _refreshPower,
              tooltip: '刷新电费',
              size: FButtonSizeVariant.xs,
            ),
        ],
      ),
    );
  }
}
