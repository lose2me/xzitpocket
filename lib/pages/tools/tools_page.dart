import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/config_provider.dart';
import '../../services/auth_service.dart';
import '../../services/cas_service.dart';
import '../../services/credential_storage.dart';
import '../../services/netauth_service.dart';
import '../../services/power_service.dart';
import '../../services/repair_service.dart';
import '../../services/ykt_service.dart';
import '../../utils/snackbar_helper.dart';
import 'exam_query_page.dart';
import 'jp_page.dart';
import 'netauth_page.dart';
import 'power_query_page.dart';
import 'repair_page.dart';
import 'ykt_page.dart';

class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage> {
  final _powerService = PowerService();
  final _yktService = YktService();

  bool _isLoading = false;
  PowerQueryData? _cachedData;

  bool _examLoading = false;
  bool _yktLoading = false;
  bool _repairLoading = false;
  bool _netAuthLoading = false;

  ExamResult? _cachedExams;
  YktDetailResult? _cachedYkt;

  @override
  void initState() {
    super.initState();
    _loadPowerData();
    _loadExamData();
    _loadYktData();
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadPowerData() async {
    final prefs = ref.read(preferencesStorageProvider);
    final roomId = prefs.getSavedPowerRoomId();
    if (roomId == null || roomId.isEmpty) return;

    final cacheDate = prefs.getPowerCacheDate();
    final cacheJson = prefs.getPowerCache();
    if (cacheDate == _todayString() && cacheJson != null) {
      setState(() {
        _cachedData = PowerQueryData.fromJson(
          jsonDecode(cacheJson) as Map<String, dynamic>,
        );
      });
      return;
    }

    await _refreshPowerData();
  }

  Future<void> _refreshPowerData() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) {
      if (mounted) showAppSnackBar(context, '此功能需登录使用');
      return;
    }

    final prefs = ref.read(preferencesStorageProvider);
    final roomId = prefs.getSavedPowerRoomId();
    if (roomId == null || roomId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await _powerService.queryRoom(roomId);
      if (!mounted) return;
      await prefs.setPowerCache(jsonEncode(result.toJson()), _todayString());
      setState(() => _cachedData = result);
    } on PowerQueryException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '查询失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExamData() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) return;
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) return;

    setState(() => _examLoading = true);
    try {
      final result = await AuthService().fetchExams(config.studentId!, password);
      if (!mounted) return;
      setState(() => _cachedExams = result);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _examLoading = false);
    }
  }

  Future<void> _loadYktData() async {
    final config = ref.read(configProvider);
    if (config.studentId == null || config.studentId!.isEmpty) return;
    final password = await CredentialStorage.getSavedPassword();
    if (password == null || password.isEmpty) return;

    setState(() => _yktLoading = true);
    try {
      final result = await _yktService.getDetail(config.studentId!, password);
      if (!mounted) return;
      setState(() => _cachedYkt = result);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _yktLoading = false);
    }
  }

  Future<void> _openExamQuery() async {
    if (_examLoading) return;
    if (_cachedExams != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ExamQueryPage(result: _cachedExams!)),
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

    setState(() => _examLoading = true);
    try {
      final result = await AuthService().fetchExams(config.studentId!, password);
      if (!mounted) return;
      setState(() => _cachedExams = result);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ExamQueryPage(result: result)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '查询失败');
    } finally {
      if (mounted) setState(() => _examLoading = false);
    }
  }

  Future<void> _openYkt() async {
    if (_yktLoading) return;
    if (_cachedYkt != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => YktPage(result: _cachedYkt!)),
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

    setState(() => _yktLoading = true);
    try {
      final result = await _yktService.getDetail(config.studentId!, password);
      if (!mounted) return;
      setState(() => _cachedYkt = result);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => YktPage(result: result)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '查询失败');
    } finally {
      if (mounted) setState(() => _yktLoading = false);
    }
  }

  Future<void> _openRepair() async {
    if (_repairLoading) return;
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

    setState(() => _repairLoading = true);
    try {
      final service = RepairService();
      RepairResult result;
      try {
        result = await service.fetchAll(config.studentId!, password);
      } on AuthException {
        await Future.delayed(const Duration(seconds: 1));
        result = await service.fetchAll(config.studentId!, password);
      }
      if (!mounted) return;
      final session = await service.login(config.studentId!, password);
      if (!mounted) {
        session.close();
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RepairPage(
            session: session,
            initialResult: result,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '加载失败');
    } finally {
      if (mounted) setState(() => _repairLoading = false);
    }
  }

  Future<void> _openNetAuth() async {
    if (_netAuthLoading) return;
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

    setState(() => _netAuthLoading = true);
    try {
      NetAuthResult result;
      try {
        result = await NetAuthService().login(config.studentId!, password);
      } on AuthException {
        await Future.delayed(const Duration(seconds: 1));
        result = await NetAuthService().login(config.studentId!, password);
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NetAuthPage(
            result: result,
            account: config.studentId!,
            password: password,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '加载失败');
    } finally {
      if (mounted) setState(() => _netAuthLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomId = ref.watch(savedRoomIdProvider);
    final hasRoom = roomId != null && roomId.isNotEmpty;

    ref.listen(savedRoomIdProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        _loadPowerData();
      } else {
        setState(() => _cachedData = null);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('邪恶比格叫叫叫'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildYktCard(theme)),
                const SizedBox(width: 8),
                Expanded(child: _buildPowerCard(theme, hasRoom, roomId)),
              ],
            ),
            const SizedBox(height: 12),
            _buildExamCard(theme),
            const SizedBox(height: 12),
            _buildSimpleCard(
              theme,
              icon: Icons.wifi_outlined,
              title: '网络管理',
              loading: _netAuthLoading,
              onTap: _openNetAuth,
            ),
            const SizedBox(height: 12),
            _buildSimpleCard(
              theme,
              icon: Icons.build_outlined,
              title: '极速报修',
              loading: _repairLoading,
              onTap: _openRepair,
            ),
            const SizedBox(height: 12),
            _buildSimpleCard(
              theme,
              icon: Icons.rate_review_outlined,
              title: '教师评价',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JpPage()),
              ),
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
    final exams = _cachedExams?.exams;
    final nextExam = exams != null && exams.isNotEmpty ? exams.first : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _examLoading ? null : _openExamQuery,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.quiz_outlined, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: nextExam != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '考试查询',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
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
                              nextExam.time,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      )
                    : Text(
                        '考试查询',
                        style: theme.textTheme.bodyLarge,
                      ),
              ),
              if (_examLoading)
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
    final balance = _cachedYkt?.balance;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _yktLoading ? null : _openYkt,
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
              if (_yktLoading)
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: hasRoom && _cachedData != null
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PowerQueryPage(result: _cachedData!, roomId: roomId),
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
                    : _cachedData != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '电费查询',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_cachedData!.available} 度',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : _isLoading
                            ? Text(
                                '电费查询',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Text(
                                '暂无数据，点击刷新',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
              ),
              if (hasRoom && _isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasRoom && _cachedData != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              else if (hasRoom)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _refreshPowerData,
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
