import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/config_provider.dart';
import '../../services/auth_service.dart';
import '../../services/credential_storage.dart';
import '../../services/debug_log_service.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/snackbar_helper.dart';
import 'exam_query_page.dart';
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

  Future<void> _openExamQuery() async {
    if (_manager.examLoading) return;
    DebugLogService.instance.log(DebugLogCategory.action, '打开考试查询');
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      showAppSnackBar(context, '此功能需登录使用');
      return;
    }
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) {
      if (mounted) showAppSnackBar(context, '此功能需登录使用');
      return;
    }

    if (_manager.exams == null) {
      final prefs = ref.read(preferencesStorageProvider);
      await _manager.loadExam(config.studentId!, password, prefs);
      if (!mounted || _manager.exams == null) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamQueryPage(
          result: _manager.exams!,
          studentId: config.studentId!,
          password: password,
        ),
      ),
    );
  }

  Future<void> _openYkt() async {
    if (_manager.yktLoading) return;
    DebugLogService.instance.log(DebugLogCategory.action, '打开一卡通查询');
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      showAppSnackBar(context, '此功能需登录使用');
      return;
    }
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) {
      if (mounted) showAppSnackBar(context, '此功能需登录使用');
      return;
    }

    if (_manager.ykt == null) {
      final prefs = ref.read(preferencesStorageProvider);
      await _manager.loadYkt(config.studentId!, password, prefs);
      if (!mounted || _manager.ykt == null) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YktPage(
          result: _manager.ykt!,
          studentId: config.studentId!,
          password: password,
        ),
      ),
    );
  }

  Future<void> _openRepair() async {
    if (_manager.repairLoading) return;
    DebugLogService.instance.log(DebugLogCategory.action, '打开极速报修');
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      showAppSnackBar(context, '此功能需登录使用');
      return;
    }
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) {
      if (mounted) showAppSnackBar(context, '此功能需登录使用');
      return;
    }

    if (_manager.repair == null) {
      final prefs = ref.read(preferencesStorageProvider);
      await _manager.loadRepair(config.studentId!, password, prefs);
      if (!mounted || _manager.repair == null) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepairPage(
          initialResult: _manager.repair!,
          studentId: config.studentId!,
          password: password,
        ),
      ),
    );
  }

  Future<void> _openNetAuth() async {
    if (_manager.netAuthLoading) return;
    DebugLogService.instance.log(DebugLogCategory.action, '打开网络管理');
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      showAppSnackBar(context, '此功能需登录使用');
      return;
    }
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) {
      if (mounted) showAppSnackBar(context, '此功能需登录使用');
      return;
    }

    if (!mounted) return;
    if (_manager.netAuth != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NetAuthPage(
            result: _manager.netAuth!,
            account: config.studentId!,
            password: password,
          ),
        ),
      );
      return;
    }

    await _manager.loadNetAuth(config.studentId!, password,
        ref.read(preferencesStorageProvider));
    if (!mounted || _manager.netAuth == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NetAuthPage(
          result: _manager.netAuth!,
          account: config.studentId!,
          password: password,
        ),
      ),
    );
  }

  Future<void> _openJp() async {
    if (_manager.jpLoading) return;
    DebugLogService.instance.log(DebugLogCategory.action, '打开教师评价');
    if (_manager.jp != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => JpPage(result: _manager.jp!)),
      );
      return;
    }
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      showAppSnackBar(context, '此功能需登录使用');
      return;
    }
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) {
      if (mounted) showAppSnackBar(context, '此功能需登录使用');
      return;
    }

    final prefs = ref.read(preferencesStorageProvider);
    await _manager.loadJp(config.studentId!, password, prefs);
    if (!mounted || _manager.jp == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JpPage(result: _manager.jp!)),
    );
  }

  // ── Power refresh (manual) ──

  Future<void> _refreshPower() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      showAppSnackBar(context, '此功能需登录使用');
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

  static DateTime? _parseExamDate(String time) {
    final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(time);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      23, 59, 59,
    );
  }

  Widget _buildExamCard(ThemeData theme) {
    final now = DateTime.now();
    final exams = _manager.exams?.exams
        .where((e) {
          final d = _parseExamDate(e.time);
          return d == null || !d.isBefore(now);
        })
        .toList()
      ?..sort((a, b) {
        final da = _parseExamDate(a.time);
        final db = _parseExamDate(b.time);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    final nextExam = exams != null && exams.isNotEmpty ? exams.first : null;

    String examTimeLabel(ExamItem exam) {
      final d = _parseExamDate(exam.time);
      if (d == null) return exam.time;
      final today = DateTime.now();
      final days = DateTime(d.year, d.month, d.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      return days >= 0 ? '${exam.time} [剩 $days 天]' : exam.time;
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
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: !hasRoom
                    ? Text(
                        '请先在「我的」中设置宿舍号',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : campusError
                        ? Text(
                            '请连接校园网',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          )
                        : data != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '电费查询',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${data.available} 度',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : _manager.powerLoading
                                ? Text(
                                    '电费查询',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : Text(
                                    '暂无数据，点击刷新',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
              ),
              if (hasRoom && _manager.powerLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasRoom && data != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              else if (hasRoom && !campusError)
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
