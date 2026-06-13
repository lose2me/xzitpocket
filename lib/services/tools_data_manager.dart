import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'cas_service.dart';
import 'debug_log_service.dart';
import 'jp_service.dart';
import 'netauth_service.dart';
import 'power_service.dart';
import 'preferences_storage.dart';
import 'repair_service.dart';
import 'ykt_service.dart';

class ToolsDataManager extends ChangeNotifier {
  ToolsDataManager._();
  static final instance = ToolsDataManager._();

  // ── Power ──
  PowerQueryData? power;
  bool powerLoading = false;
  String? powerError;

  // ── YKT ──
  YktDetailResult? ykt;
  bool yktLoading = false;

  // ── Exam ──
  ExamResult? exams;
  bool examLoading = false;

  // ── Repair ──
  RepairResult? repair;
  bool repairLoading = false;

  // ── NetAuth ──
  NetAuthResult? netAuth;
  bool netAuthLoading = false;

  // ── JP ──
  JpStatusResult? jp;
  bool jpLoading = false;

  // ── Campus network ──
  bool? campusNetAvailable;

  static const _powerTtl = Duration(days: 1);
  static const _jpTtl = Duration(hours: 3);
  static const _repairTtl = Duration(hours: 1);
  static const _refreshCooldown = Duration(seconds: 60);

  DateTime? _lastYktFetch;
  DateTime? _lastExamFetch;

  // ── Public API ──

  void setExams(ExamResult result, PreferencesStorage prefs) {
    exams = result;
    prefs.setExamCache(jsonEncode(result.toJson()));
    notifyListeners();
  }

  void clearPower() {
    power = null;
    powerError = null;
    notifyListeners();
  }

  void clear() {
    power = null;
    powerLoading = false;
    powerError = null;
    ykt = null;
    yktLoading = false;
    exams = null;
    examLoading = false;
    repair = null;
    repairLoading = false;
    netAuth = null;
    netAuthLoading = false;
    jp = null;
    jpLoading = false;
    campusNetAvailable = null;
    _lastYktFetch = null;
    _lastExamFetch = null;
    notifyListeners();
  }

  Future<void> startBackgroundLoading({
    required String studentId,
    required String password,
    required PreferencesStorage prefs,
    String? roomId,
  }) async {
    DebugLogService.instance
        .log(DebugLogCategory.action, '后台数据加载', '开始');

    final campusOk = await checkCampusNetwork();

    final futures = <Future>[];

    if (campusOk) {
      if (roomId != null && roomId.isNotEmpty) {
        futures.add(loadPower(roomId, prefs));
      }
    } else {
      powerError = '请连接校园网';
      notifyListeners();
    }

    futures.add(loadYkt(studentId, password, prefs));
    futures.add(loadRepair(studentId, password, prefs));
    futures.add(loadNetAuth(studentId, password, prefs));
    futures.add(loadJp(studentId, password, prefs));

    await Future.wait(futures);

    DebugLogService.instance
        .log(DebugLogCategory.action, '后台数据加载', '完成');
  }

  Future<void> refreshOnTabSwitch({
    required String studentId,
    required String password,
    required PreferencesStorage prefs,
    String? roomId,
  }) async {
    final futures = <Future>[];

    if (roomId != null && roomId.isNotEmpty) {
      final campusOk = await checkCampusNetwork();
      if (campusOk) {
        futures.add(loadPower(roomId, prefs));
      } else if (power == null) {
        powerError = '请连接校园网';
        notifyListeners();
      }
    }

    futures.add(loadYkt(studentId, password, prefs));
    futures.add(loadExam(studentId, password, prefs));

    await Future.wait(futures);
  }

  // ── Campus network check ──

  Future<bool> checkCampusNetwork() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasWifi = connectivity.contains(ConnectivityResult.wifi);
      if (!hasWifi) {
        DebugLogService.instance
            .log(DebugLogCategory.action, '校园网检测', '未连接WiFi');
        campusNetAvailable = false;
        notifyListeners();
        return false;
      }

      final reachable = await _tcpPing('211.87.126.94', 80);
      campusNetAvailable = reachable;
      notifyListeners();

      DebugLogService.instance.log(
        DebugLogCategory.action,
        '校园网检测',
        reachable ? '可达' : '不可达',
      );
      return reachable;
    } catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '校园网检测异常', '$e');
      campusNetAvailable = false;
      notifyListeners();
      return false;
    }
  }

  static Future<bool> _tcpPing(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Individual loaders ──

  Future<void> loadPower(String roomId, PreferencesStorage prefs) async {
    if (powerLoading) return;

    final cacheTime = prefs.getPowerCacheTime();
    if (PreferencesStorage.isCacheValid(cacheTime, _powerTtl)) {
      final cached = prefs.getPowerCache();
      if (cached != null && power == null) {
        power = PowerQueryData.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        powerError = null;
        notifyListeners();
        return;
      }
      if (power != null) return;
    }

    powerLoading = true;
    powerError = null;
    notifyListeners();

    try {
      final result = await PowerService().queryRoom(roomId);
      power = result;
      powerError = null;
      await prefs.setPowerCache(
        jsonEncode(result.toJson()),
        _todayString(),
      );
    } on PowerQueryException catch (e) {
      powerError = e.message;
    } catch (_) {
      powerError = '查询失败';
    } finally {
      powerLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadYkt(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    if (yktLoading) return;

    if (_lastYktFetch != null &&
        ykt != null &&
        DateTime.now().difference(_lastYktFetch!) < _refreshCooldown) {
      return;
    }

    if (ykt == null) {
      final cached = prefs.getYktCache();
      if (cached != null) {
        ykt = YktDetailResult.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        notifyListeners();
      }
    }

    yktLoading = true;
    notifyListeners();

    try {
      final result = await YktService().getDetail(studentId, password);
      ykt = result;
      _lastYktFetch = DateTime.now();
      await prefs.setYktCache(jsonEncode(result.toJson()));
    } on AuthException catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '一卡通后台加载失败', e.message);
    } catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '一卡通后台加载异常', '$e');
    } finally {
      yktLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadExam(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    if (examLoading) return;

    if (_lastExamFetch != null &&
        exams != null &&
        DateTime.now().difference(_lastExamFetch!) < _refreshCooldown) {
      return;
    }

    if (exams == null) {
      final cached = prefs.getExamCache();
      if (cached != null) {
        exams = ExamResult.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        notifyListeners();
      }
    }

    examLoading = true;
    notifyListeners();

    try {
      final result = await AuthService().fetchExams(studentId, password);
      exams = result;
      _lastExamFetch = DateTime.now();
      await prefs.setExamCache(jsonEncode(result.toJson()));
    } on AuthException catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '考试后台加载失败', e.message);
    } catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '考试后台加载异常', '$e');
    } finally {
      examLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRepair(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    if (repairLoading) return;

    if (repair == null) {
      final cached = prefs.getRepairCache();
      if (cached != null) {
        repair = RepairResult.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        notifyListeners();
      }
    }

    final cacheTime = prefs.getRepairCacheTime();
    if (PreferencesStorage.isCacheValid(cacheTime, _repairTtl) &&
        repair != null) {
      return;
    }

    repairLoading = true;
    notifyListeners();

    try {
      final service = RepairService();
      RepairResult result;
      try {
        result = await service.fetchAll(studentId, password);
      } on AuthException {
        await Future.delayed(const Duration(seconds: 1));
        result = await service.fetchAll(studentId, password);
      }
      repair = result;
      await prefs.setRepairCache(jsonEncode(result.toJson()));
    } on AuthException catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '报修后台加载失败', e.message);
    } catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '报修后台加载异常', '$e');
    } finally {
      repairLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNetAuth(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    if (netAuthLoading) return;

    if (netAuth == null) {
      final cached = prefs.getNetauthCache();
      if (cached != null) {
        netAuth = NetAuthResult.fromCache(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        notifyListeners();
      }
    }

    netAuthLoading = true;
    notifyListeners();

    try {
      NetAuthResult result;
      try {
        result = await NetAuthService().login(studentId, password);
      } on AuthException {
        await Future.delayed(const Duration(seconds: 1));
        result = await NetAuthService().login(studentId, password);
      }
      netAuth = result;
      await prefs.setNetauthCache(jsonEncode(result.toJson()));
    } on AuthException catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '网络管理后台加载失败', e.message);
    } catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '网络管理后台加载异常', '$e');
    } finally {
      netAuthLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadJp(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    if (jpLoading) return;

    if (jp == null) {
      final cached = prefs.getJpCache();
      if (cached != null) {
        jp = JpStatusResult.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        notifyListeners();
      }
    }

    final cacheTime = prefs.getJpCacheTime();
    if (PreferencesStorage.isCacheValid(cacheTime, _jpTtl) && jp != null) {
      return;
    }

    jpLoading = true;
    notifyListeners();

    try {
      final service = JpService();
      JpStatusResult result;
      try {
        result = await service.queryStatus(studentId, password);
      } on AuthException {
        await Future.delayed(const Duration(seconds: 1));
        result = await service.queryStatus(studentId, password);
      }
      jp = result;
      await prefs.setJpCache(jsonEncode(result.toJson()));
    } on AuthException catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '教师评价后台加载失败', e.message);
    } catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '教师评价后台加载异常', '$e');
    } finally {
      jpLoading = false;
      notifyListeners();
    }
  }

  // ── Helpers ──

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
