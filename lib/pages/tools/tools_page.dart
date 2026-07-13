import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/config_provider.dart';
import '../../services/auth_service.dart';
import '../../services/credential_storage.dart';
import '../../services/debug_log_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/exam_utils.dart';
import '../../utils/snackbar_helper.dart';
import 'empty_classroom_page.dart';
import 'exam_query_page.dart';
import 'grade_query_page.dart';
import 'jp_page.dart';
import 'netauth_page.dart';
import 'power_query_page.dart';
import 'repair_page.dart';
import 'ykt_page.dart';

class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  static final globalKey = GlobalKey<ToolsPageState>();

  @override
  ConsumerState<ToolsPage> createState() => ToolsPageState();
}

class ToolsPageState extends ConsumerState<ToolsPage> {
  final _manager = ToolsDataManager.instance;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManagerUpdate);
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> refreshData() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) return;
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) return;

    final prefs = ref.read(preferencesStorageProvider);
    _manager.refreshOnTabSwitch(
      studentId: config.studentId!,
      password: password,
      prefs: prefs,
      roomId: prefs.getSavedPowerRoomId(),
    );
  }

  // ── Open methods ──

  Future<({String studentId, String password})?> _ensureCredentials() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      showAppSnackBar(context, '此功能需登录使用');
      return null;
    }
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) {
      if (mounted) showAppSnackBar(context, '此功能需登录使用');
      return null;
    }
    return (studentId: config.studentId!, password: password);
  }

  Future<void> _openTool<T>({
    required bool loading,
    required String logLabel,
    required T? Function() getData,
    required Future<void> Function(String sid, String pwd, PreferencesStorage prefs) load,
    required Widget Function(T data, String sid, String pwd) buildPage,
    bool requiresCampus = false,
  }) async {
    if (loading) return;
    DebugLogService.instance.log(DebugLogCategory.action, logLabel);

    final hasNet = await _manager.checkInternetAvailable();
    if (!hasNet) {
      if (mounted) showAppSnackBar(context, '请连接网络');
      return;
    }

    if (requiresCampus) {
      final campusOk = await _manager.checkCampusNetwork();
      if (!campusOk) {
        if (mounted) showAppSnackBar(context, '请连接校园网');
        return;
      }
    }

    final creds = await _ensureCredentials();
    if (creds == null || !mounted) return;

    if (getData() == null) {
      final prefs = ref.read(preferencesStorageProvider);
      await load(creds.studentId, creds.password, prefs);
      if (!mounted || getData() == null) return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => buildPage(getData() as T, creds.studentId, creds.password),
      ),
    );
  }

  Future<void> _openExamQuery() => _openTool(
    loading: _manager.examLoading,
    logLabel: '打开考试查询',
    getData: () => _manager.exams,
    load: _manager.loadExam,
    buildPage: (data, sid, pwd) =>
        ExamQueryPage(result: data, studentId: sid, password: pwd),
  );

  Future<void> _openYkt() => _openTool(
    loading: _manager.yktLoading,
    logLabel: '打开一卡通查询',
    getData: () => _manager.ykt,
    load: _manager.loadYkt,
    buildPage: (data, sid, pwd) =>
        YktPage(result: data, studentId: sid, password: pwd),
  );

  Future<void> _openRepair() => _openTool(
    loading: _manager.repairLoading,
    logLabel: '打开极速报修',
    getData: () => _manager.repair,
    load: _manager.loadRepair,
    buildPage: (data, sid, pwd) =>
        RepairPage(initialResult: data, studentId: sid, password: pwd),
  );

  Future<void> _openNetAuth() => _openTool(
    loading: _manager.netAuthLoading,
    logLabel: '打开网络管理',
    getData: () => _manager.netAuth,
    load: _manager.loadNetAuth,
    buildPage: (data, sid, pwd) =>
        NetAuthPage(result: data, account: sid, password: pwd),
  );

  Future<void> _openJp() => _openTool(
    loading: _manager.jpLoading,
    logLabel: '打开教师评价',
    getData: () => _manager.jp,
    load: _manager.loadJp,
    requiresCampus: true,
    buildPage: (data, _, _) => JpPage(result: data),
  );

  Future<void> _openEmptyClassroom() async {
    final hasNet = await _manager.checkInternetAvailable();
    if (!hasNet) {
      if (mounted) showAppSnackBar(context, '请连接网络');
      return;
    }
    final creds = await _ensureCredentials();
    if (creds == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmptyClassroomPage(
        studentId: creds.studentId,
        password: creds.password,
      ),
    ));
  }

  Future<void> _openGradeQuery() async {
    final hasNet = await _manager.checkInternetAvailable();
    if (!hasNet) {
      if (mounted) showAppSnackBar(context, '请连接网络');
      return;
    }
    final creds = await _ensureCredentials();
    if (creds == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GradeQueryPage(
        studentId: creds.studentId,
        password: creds.password,
      ),
    ));
  }

  // ── Power refresh (manual) ──

  Future<void> _refreshPower() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      showAppSnackBar(context, '此功能需登录使用');
      return;
    }

    final hasNet = await _manager.checkInternetAvailable();
    if (!hasNet) {
      if (mounted) showAppSnackBar(context, '请连接网络');
      return;
    }

    final prefs = ref.read(preferencesStorageProvider);
    final roomId = prefs.getSavedPowerRoomId();
    if (roomId == null || roomId.isEmpty) return;

    final campusOk = await _manager.checkCampusNetwork();
    if (!campusOk) {
      if (mounted) showAppSnackBar(context, '请连接校园网');
      return;
    }

    await _manager.loadPower(roomId, prefs);
    if (!mounted) return;
    if (_manager.powerError != null) {
      showAppSnackBar(context, _manager.powerError!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomId = ref.watch(savedRoomIdProvider);
    final hasRoom = roomId != null && roomId.isNotEmpty;

    ref.listen(savedRoomIdProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        final prefs = ref.read(preferencesStorageProvider);
        _manager.loadPower(next, prefs);
      } else {
        _manager.clearPower();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('邪恶比格叫叫叫'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildYktCard(theme)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPowerCard(theme, hasRoom, roomId)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildExamCard(theme),
            const SizedBox(height: 12),
            _buildSimpleCard(
              theme,
              icon: Icons.meeting_room_outlined,
              title: '空教室查询',
              onTap: _openEmptyClassroom,
            ),
            const SizedBox(height: 12),
            _buildSimpleCard(
              theme,
              icon: Icons.school_outlined,
              title: '学业情况',
              onTap: _openGradeQuery,
            ),
            const SizedBox(height: 12),
            _buildSimpleCard(
              theme,
              icon: Icons.wifi_outlined,
              title: '网络管理',
              loading: _manager.netAuthLoading,
              onTap: _openNetAuth,
            ),
            const SizedBox(height: 12),
            _buildSimpleCard(
              theme,
              icon: Icons.build_outlined,
              title: '极速报修',
              loading: _manager.repairLoading,
              onTap: _openRepair,
            ),
            const SizedBox(height: 12),
            _buildSimpleCard(
              theme,
              icon: Icons.rate_review_outlined,
              title: '教师评价',
              loading: _manager.jpLoading,
              onTap: _openJp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    bool loading = false,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(ThemeData theme) {
    final now = DateTime.now();
    final exams = _manager.exams?.exams
        .where((e) {
          final d = parseExamDate(e.time);
          return d == null || !d.isBefore(now);
        })
        .toList()
      ?..sort((a, b) {
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
      final days = DateTime(d.year, d.month, d.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      if (days < 0) return exam.time;
      final tag = switch (days) { 0 => '今天', 1 => '明天', 2 => '后天', _ => '剩 $days 天' };
      return '${exam.time} [$tag]';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _manager.examLoading ? null : _openExamQuery,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: nextExam != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.quiz_outlined,
                                  color: theme.colorScheme.primary, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '考试查询',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nextExam.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (nextExam.time.isNotEmpty)
                            Text(
                              examTimeLabel(nextExam),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.quiz_outlined,
                              color: theme.colorScheme.primary, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            '考试查询',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
              ),
              if (_manager.examLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYktCard(ThemeData theme) {
    final balance = _manager.ykt?.balance;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _manager.yktLoading ? null : _openYkt,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: balance != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '一卡通查询',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${balance.balance} 元',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '一卡通查询',
                        style: theme.textTheme.bodyLarge,
                      ),
              ),
              if (_manager.yktLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPowerCard(ThemeData theme, bool hasRoom, String? roomId) {
    final data = _manager.power;
    final campusError =
        _manager.campusNetAvailable == false && data == null && hasRoom;

    String statusText;
    TextStyle? statusStyle;
    if (!hasRoom) {
      statusText = '请先在「我的」中设置宿舍号';
      statusStyle = theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
    } else if (campusError) {
      statusText = '请连接校园网';
      statusStyle = theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      );
    } else if (data != null) {
      statusText = '${data.available} 度';
      statusStyle = theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      );
    } else if (_manager.powerLoading) {
      statusText = '';
      statusStyle = null;
    } else {
      statusText = '暂无数据，点击刷新';
      statusStyle = theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: hasRoom && data != null
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PowerQueryPage(result: data, roomId: roomId),
                  ),
                )
            : hasRoom && !campusError && !_manager.powerLoading
                ? _refreshPower
                : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '电费查询',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_manager.powerLoading && hasRoom)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (statusText.isNotEmpty) ...[
                      const SizedBox(height: 2),
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
              if (hasRoom && data != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              else if (hasRoom && !campusError && !_manager.powerLoading)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _refreshPower,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
