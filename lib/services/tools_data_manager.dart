import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../utils/in_flight_operation.dart';
import 'auth_service.dart';
import 'cas_service.dart';
import 'credential_storage.dart';
import 'jp_service.dart';
import 'netauth_service.dart';
import 'power_service.dart';
import 'preferences_storage.dart';
import 'repair_service.dart';
import 'talker.dart';
import 'ykt_service.dart';

enum CampusNetworkStatus { checking, available, unavailable }

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

  final _powerOperation = InFlightOperation<void>();
  final _yktOperation = InFlightOperation<bool>();
  final _examOperation = InFlightOperation<bool>();
  final _repairOperation = InFlightOperation<bool>();
  final _netAuthOperation = InFlightOperation<bool>();
  final _jpOperation = InFlightOperation<bool>();

  // ── Campus network ──
  CampusNetworkStatus campusNetworkStatus = CampusNetworkStatus.checking;

  bool get isCampusNetworkAvailable =>
      campusNetworkStatus == CampusNetworkStatus.available;

  bool? get campusNetAvailable => switch (campusNetworkStatus) {
    CampusNetworkStatus.checking => null,
    CampusNetworkStatus.available => true,
    CampusNetworkStatus.unavailable => false,
  };

  static const _powerTtl = Duration(days: 1);
  static const _yktTtl = Duration(minutes: 10);
  static const _examTtl = Duration(minutes: 10);
  static const _repairTtl = Duration(hours: 1);
  static const _netAuthTtl = Duration(minutes: 10);
  static const _jpTtl = Duration(hours: 3);

  // ── Connectivity watch ──
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _connectivityDebounce;
  Future<bool>? _campusProbe;
  int _networkGeneration = 0;
  int _dataGeneration = 0;
  int _powerGeneration = 0;
  bool _initialized = false;
  String? _savedStudentId;
  PreferencesStorage? _savedPrefs;
  String? _savedRoomId;
  String? _powerRoomId;
  List<ConnectivityResult> _lastConnectivity = [];

  // ── Public API ──

  void initialize(PreferencesStorage prefs) {
    if (_initialized) return;
    _initialized = true;
    _savedStudentId = prefs.getStudentId();
    _savedPrefs = prefs;
    _savedRoomId = prefs.getSavedPowerRoomId();
    _loadAllCaches(prefs);
    unawaited(_initializeNetworkMonitoring());
  }

  Future<void> setExams(ExamResult result, PreferencesStorage prefs) async {
    exams = result;
    await prefs.setExamCache(jsonEncode(result.toJson()));
    notifyListeners();
  }

  void clearPower() {
    _powerGeneration++;
    _powerOperation.invalidate();
    _savedRoomId = null;
    power = null;
    _powerRoomId = null;
    powerLoading = false;
    powerError = null;
    notifyListeners();
  }

  void clear() {
    _dataGeneration++;
    _powerGeneration++;
    _invalidateOperations();
    _connectivityDebounce?.cancel();
    _savedStudentId = null;
    _savedPrefs = null;
    _savedRoomId = null;
    power = null;
    _powerRoomId = null;
    powerError = null;
    ykt = null;
    exams = null;
    repair = null;
    netAuth = null;
    jp = null;
    _resetLoadingFlags();
    notifyListeners();
  }

  Future<void> startBackgroundLoading({
    required String studentId,
    required String password,
    required PreferencesStorage prefs,
    String? roomId,
  }) async {
    final generation = ++_dataGeneration;
    _invalidateOperations();
    _resetLoadingFlags();
    _savedStudentId = studentId;
    _savedPrefs = prefs;
    _savedRoomId = roomId;
    initialize(prefs);

    talker.info('[ACTION] 后台数据加载\n开始');

    final hasNet = await checkInternetAvailable();
    if (generation != _dataGeneration) return;
    if (!hasNet) {
      talker.info('[ACTION] 后台数据加载\n无网络, 仅加载缓存');
      _setCampusNetworkStatus(CampusNetworkStatus.unavailable);
      _loadAllCaches(prefs);
      return;
    }

    final campusOk = await checkCampusNetwork();
    if (generation != _dataGeneration) return;
    await _loadBackgroundData(
      studentId: studentId,
      password: password,
      prefs: prefs,
      roomId: roomId,
      campusAvailable: campusOk,
      generation: generation,
    );

    talker.info('[ACTION] 后台数据加载\n完成');
  }

  Future<void> refreshOnTabSwitch({
    required String studentId,
    required String password,
    required PreferencesStorage prefs,
    String? roomId,
  }) async {
    _savedStudentId = studentId;
    _savedPrefs = prefs;
    _savedRoomId = roomId;
    final hasNet = await checkInternetAvailable();
    if (!hasNet) {
      _setCampusNetworkStatus(CampusNetworkStatus.unavailable);
      _loadAllCaches(prefs);
      return;
    }

    final futures = <Future<void>>[];

    if (roomId != null && roomId.isNotEmpty) {
      final campusOk = await checkCampusNetwork();
      if (campusOk) {
        futures.add(loadPower(roomId, prefs));
      } else {
        _restorePowerCache(prefs, roomId: roomId);
        notifyListeners();
      }
    }

    futures.add(loadYkt(studentId, password, prefs));
    futures.add(loadExam(studentId, password, prefs));

    await Future.wait(futures);
  }

  // ── Campus network check ──

  Future<bool> checkInternetAvailable() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<bool> checkCampusNetwork({bool force = false}) async {
    final activeProbe = _campusProbe;
    if (activeProbe != null) return activeProbe;

    if (!force) {
      if (campusNetworkStatus == CampusNetworkStatus.available) return true;
      if (campusNetworkStatus == CampusNetworkStatus.unavailable) return false;
    }

    final probe = _runCampusProbe();
    _campusProbe = probe;
    try {
      return await probe;
    } finally {
      if (identical(_campusProbe, probe)) _campusProbe = null;
    }
  }

  Future<bool> _runCampusProbe() async {
    final generation = _networkGeneration;
    _setCampusNetworkStatus(CampusNetworkStatus.checking);
    try {
      final reachable = await _tcpPing('211.87.126.94', 80);
      if (generation != _networkGeneration) return false;
      _setCampusNetworkStatus(
        reachable
            ? CampusNetworkStatus.available
            : CampusNetworkStatus.unavailable,
      );
      talker.info('[ACTION] 校园网检测\n${reachable ? '可达' : '不可达'}');
      return reachable;
    } catch (e, stackTrace) {
      if (generation != _networkGeneration) return false;
      _setCampusNetworkStatus(CampusNetworkStatus.unavailable);
      talker.error('校园网检测异常', e, stackTrace);
      return false;
    }
  }

  void _setCampusNetworkStatus(CampusNetworkStatus status) {
    if (campusNetworkStatus == status) return;
    campusNetworkStatus = status;
    notifyListeners();
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

  Future<void> loadPower(String roomId, PreferencesStorage prefs) {
    _savedPrefs = prefs;
    _savedRoomId = roomId;
    return _powerOperation.run(() => _loadPower(roomId, prefs));
  }

  Future<PowerQueryData?> refreshPower(
    String roomId,
    PreferencesStorage prefs,
  ) async {
    await _powerOperation.run(
      () => _loadPower(roomId, prefs, forceRefresh: true),
    );
    return powerError == null && _powerRoomId == roomId ? power : null;
  }

  Future<void> _loadPower(
    String roomId,
    PreferencesStorage prefs, {
    bool forceRefresh = false,
  }) async {
    final generation = _dataGeneration;
    final powerGeneration = _powerGeneration;

    _restorePowerCache(prefs, roomId: roomId);
    final cacheTime = prefs.getPowerCacheTime();
    if (!forceRefresh &&
        PreferencesStorage.isCacheValid(cacheTime, _powerTtl) &&
        power != null) {
      powerError = null;
      notifyListeners();
      return;
    }

    if (!isCampusNetworkAvailable) {
      powerError = '请连接校园网';
      notifyListeners();
      return;
    }

    powerLoading = true;
    powerError = null;
    notifyListeners();

    try {
      final result = await PowerService().queryRoom(roomId);
      if (generation != _dataGeneration ||
          powerGeneration != _powerGeneration) {
        return;
      }
      power = result;
      _powerRoomId = roomId;
      powerError = null;
      await prefs.setPowerCache(jsonEncode(result.toJson()), roomId: roomId);
    } on PowerQueryException catch (e, stackTrace) {
      if (generation != _dataGeneration ||
          powerGeneration != _powerGeneration) {
        return;
      }
      powerError = e.message;
      talker.error('电费后台加载失败', e, stackTrace);
    } catch (e, stackTrace) {
      if (generation != _dataGeneration ||
          powerGeneration != _powerGeneration) {
        return;
      }
      powerError = '查询失败';
      talker.error('电费后台加载异常', e, stackTrace);
    } finally {
      if (generation == _dataGeneration &&
          powerGeneration == _powerGeneration) {
        powerLoading = false;
        notifyListeners();
      }
    }
  }

  void _restorePowerCache(PreferencesStorage prefs, {String? roomId}) {
    final requestedRoomId = roomId?.trim();
    if (power != null) {
      if (requestedRoomId == null ||
          requestedRoomId.isEmpty ||
          _powerRoomId == requestedRoomId) {
        return;
      }
      power = null;
      _powerRoomId = null;
    }
    final cached = prefs.getPowerCache();
    if (cached == null) return;
    final cachedRoomId = prefs.getPowerCacheRoomId();
    if (requestedRoomId != null &&
        requestedRoomId.isNotEmpty &&
        (cachedRoomId == null || cachedRoomId != requestedRoomId)) {
      return;
    }
    try {
      power = PowerQueryData.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
      _powerRoomId = cachedRoomId ?? requestedRoomId;
    } catch (e, stackTrace) {
      power = null;
      _powerRoomId = null;
      talker.error('电费缓存解析失败', e, stackTrace);
    }
  }

  Future<void> loadYkt(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    await _yktOperation.run(() => _loadYkt(studentId, password, prefs));
  }

  Future<YktDetailResult?> refreshYkt(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    final success = await _yktOperation.run(
      () => _loadYkt(studentId, password, prefs, forceRefresh: true),
    );
    return success ? ykt : null;
  }

  /// 按指定日期范围查询一卡通流水（不写缓存，也不影响「最近30天」缓存）。
  Future<YktDetailResult?> queryYktRange(
    String studentId,
    String password, {
    required DateTime start,
    required DateTime end,
  }) async {
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      return await YktService().getDetail(
        studentId,
        password,
        start: fmt(start),
        end: fmt(end),
      );
    } on AuthException catch (e, stackTrace) {
      talker.error('一卡通范围查询失败', e, stackTrace);
    } catch (e, stackTrace) {
      talker.error('一卡通范围查询异常', e, stackTrace);
    }
    return null;
  }

  Future<bool> _loadYkt(
    String studentId,
    String password,
    PreferencesStorage prefs, {
    bool forceRefresh = false,
  }) async {
    final generation = _dataGeneration;

    if (ykt == null) {
      final cached = prefs.getYktCache();
      if (cached != null) {
        ykt = _decodeCache(cached, YktDetailResult.fromJson, '一卡通');
        notifyListeners();
      }
    }

    if (!forceRefresh &&
        PreferencesStorage.isCacheValid(prefs.getYktCacheTime(), _yktTtl) &&
        ykt != null) {
      return true;
    }

    yktLoading = true;
    notifyListeners();

    try {
      final result = await YktService().getDetail(studentId, password);
      if (generation != _dataGeneration) return false;
      ykt = result;
      await prefs.setYktCache(jsonEncode(result.toJson()));
      return true;
    } on AuthException catch (e, stackTrace) {
      if (generation != _dataGeneration) return false;
      talker.error('一卡通后台加载失败', e, stackTrace);
    } catch (e, stackTrace) {
      if (generation != _dataGeneration) return false;
      talker.error('一卡通后台加载异常', e, stackTrace);
    } finally {
      if (generation == _dataGeneration) {
        yktLoading = false;
        notifyListeners();
      }
    }
    return false;
  }

  Future<void> loadExam(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    await _examOperation.run(() => _loadExam(studentId, password, prefs));
  }

  Future<ExamResult?> refreshExam(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    final success = await _examOperation.run(
      () => _loadExam(studentId, password, prefs, forceRefresh: true),
    );
    return success ? exams : null;
  }

  Future<bool> _loadExam(
    String studentId,
    String password,
    PreferencesStorage prefs, {
    bool forceRefresh = false,
  }) async {
    final generation = _dataGeneration;

    if (exams == null) {
      final cached = prefs.getExamCache();
      if (cached != null) {
        exams = _decodeCache(cached, ExamResult.fromJson, '考试');
        notifyListeners();
      }
    }

    if (!forceRefresh &&
        PreferencesStorage.isCacheValid(prefs.getExamCacheTime(), _examTtl) &&
        exams != null) {
      return true;
    }

    examLoading = true;
    notifyListeners();

    try {
      final result = await AuthService().fetchExams(studentId, password);
      if (generation != _dataGeneration) return false;
      exams = result;
      await prefs.setExamCache(jsonEncode(result.toJson()));
      return true;
    } on AuthException catch (e, stackTrace) {
      if (generation != _dataGeneration) return false;
      talker.error('考试后台加载失败', e, stackTrace);
    } catch (e, stackTrace) {
      if (generation != _dataGeneration) return false;
      talker.error('考试后台加载异常', e, stackTrace);
    } finally {
      if (generation == _dataGeneration) {
        examLoading = false;
        notifyListeners();
      }
    }
    return false;
  }

  Future<void> loadRepair(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    await _repairOperation.run(() => _loadRepair(studentId, password, prefs));
  }

  Future<RepairResult?> refreshRepair(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    final success = await _repairOperation.run(
      () => _loadRepair(studentId, password, prefs, forceRefresh: true),
    );
    return success ? repair : null;
  }

  Future<bool> _loadRepair(
    String studentId,
    String password,
    PreferencesStorage prefs, {
    bool forceRefresh = false,
  }) async {
    final generation = _dataGeneration;

    if (repair == null) {
      final cached = prefs.getRepairCache();
      if (cached != null) {
        repair = _decodeCache(cached, RepairResult.fromJson, '报修');
        notifyListeners();
      }
    }

    final cacheTime = prefs.getRepairCacheTime();
    if (!forceRefresh &&
        PreferencesStorage.isCacheValid(cacheTime, _repairTtl) &&
        repair != null) {
      return true;
    }

    repairLoading = true;
    notifyListeners();

    try {
      final service = RepairService();
      final result = await _retryOnce(
        () => service.fetchAll(studentId, password),
        canRetry: () => generation == _dataGeneration,
      );
      if (generation != _dataGeneration) return false;
      repair = result;
      await prefs.setRepairCache(jsonEncode(result.toJson()));
      return true;
    } on AuthException catch (e, stackTrace) {
      if (generation != _dataGeneration) return false;
      talker.error('报修后台加载失败', e, stackTrace);
    } catch (e, stackTrace) {
      if (generation != _dataGeneration) return false;
      talker.error('报修后台加载异常', e, stackTrace);
    } finally {
      if (generation == _dataGeneration) {
        repairLoading = false;
        notifyListeners();
      }
    }
    return false;
  }

  Future<void> loadNetAuth(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    await _netAuthOperation.run(() => _loadNetAuth(studentId, password, prefs));
  }

  Future<NetAuthResult?> refreshNetAuth(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    final success = await _netAuthOperation.run(
      () => _loadNetAuth(studentId, password, prefs, forceRefresh: true),
    );
    return success ? netAuth : null;
  }

  Future<bool> _loadNetAuth(
    String studentId,
    String password,
    PreferencesStorage prefs, {
    bool forceRefresh = false,
  }) async {
    final generation = _dataGeneration;

    if (netAuth == null) {
      final cached = prefs.getNetauthCache();
      if (cached != null) {
        netAuth = _decodeCache(cached, NetAuthResult.fromCache, '网络管理');
        notifyListeners();
      }
    }

    if (!forceRefresh &&
        PreferencesStorage.isCacheValid(
          prefs.getNetauthCacheTime(),
          _netAuthTtl,
        ) &&
        netAuth != null) {
      return true;
    }

    netAuthLoading = true;
    notifyListeners();

    try {
      final result = await _retryOnce(
        () => NetAuthService().login(studentId, password),
        canRetry: () => generation == _dataGeneration,
      );
      if (generation != _dataGeneration) return false;
      netAuth = result;
      await prefs.setNetauthCache(jsonEncode(result.toJson()));
      return true;
    } on AuthException catch (e, stackTrace) {
      if (generation != _dataGeneration) return false;
      talker.error('网络管理后台加载失败', e, stackTrace);
    } catch (e, stackTrace) {
      if (generation != _dataGeneration) return false;
      talker.error('网络管理后台加载异常', e, stackTrace);
    } finally {
      if (generation == _dataGeneration) {
        netAuthLoading = false;
        notifyListeners();
      }
    }
    return false;
  }

  Future<void> loadJp(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    await _jpOperation.run(() => _loadJp(studentId, password, prefs));
  }

  Future<JpStatusResult?> refreshJp(
    String studentId,
    String password,
    PreferencesStorage prefs,
  ) async {
    final success = await _jpOperation.run(
      () => _loadJp(studentId, password, prefs, forceRefresh: true),
    );
    return success ? jp : null;
  }

  Future<bool> _loadJp(
    String studentId,
    String password,
    PreferencesStorage prefs, {
    bool forceRefresh = false,
  }) async {
    final generation = _dataGeneration;
    if (!isCampusNetworkAvailable) return false;

    if (jp == null) {
      final cached = prefs.getJpCache();
      if (cached != null) {
        jp = _decodeCache(cached, JpStatusResult.fromJson, '教师评价');
        notifyListeners();
      }
    }

    final cacheTime = prefs.getJpCacheTime();
    if (!forceRefresh &&
        PreferencesStorage.isCacheValid(cacheTime, _jpTtl) &&
        jp != null) {
      return true;
    }

    jpLoading = true;
    notifyListeners();

    try {
      final service = JpService();
      final result = await _retryOnce(
        () => service.queryStatus(studentId, password),
        canRetry: () => generation == _dataGeneration,
      );
      if (generation != _dataGeneration) return false;
      jp = result;
      await prefs.setJpCache(jsonEncode(result.toJson()));
      return true;
    } on AuthException catch (e, stackTrace) {
      if (generation != _dataGeneration) return false;
      talker.error('教师评价后台加载失败', e, stackTrace);
    } catch (e, stackTrace) {
      if (generation != _dataGeneration) return false;
      talker.error('教师评价后台加载异常', e, stackTrace);
    } finally {
      if (generation == _dataGeneration) {
        jpLoading = false;
        notifyListeners();
      }
    }
    return false;
  }

  void _loadAllCaches(PreferencesStorage prefs) {
    ykt ??= _decodeCache(prefs.getYktCache(), YktDetailResult.fromJson, '一卡通');
    _restorePowerCache(prefs, roomId: prefs.getSavedPowerRoomId());
    exams ??= _decodeCache(prefs.getExamCache(), ExamResult.fromJson, '考试');
    repair ??= _decodeCache(
      prefs.getRepairCache(),
      RepairResult.fromJson,
      '报修',
    );
    netAuth ??= _decodeCache(
      prefs.getNetauthCache(),
      NetAuthResult.fromCache,
      '网络管理',
    );
    jp ??= _decodeCache(prefs.getJpCache(), JpStatusResult.fromJson, '教师评价');
    notifyListeners();
  }

  T? _decodeCache<T>(
    String? raw,
    T Function(Map<String, dynamic>) decode,
    String label,
  ) {
    if (raw == null) return null;
    try {
      return decode(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, stackTrace) {
      talker.error('$label缓存解析失败', e, stackTrace);
      return null;
    }
  }

  // ── Connectivity watch ──

  Future<void> _initializeNetworkMonitoring() async {
    try {
      await _probeOnColdStart();
    } catch (e, stackTrace) {
      _setCampusNetworkStatus(CampusNetworkStatus.unavailable);
      talker.error('校园网冷启动检测异常', e, stackTrace);
    } finally {
      _startConnectivityWatch();
    }
  }

  Future<void> _probeOnColdStart() async {
    final current = await Connectivity().checkConnectivity();
    _lastConnectivity = List.of(current);
    await checkCampusNetwork(force: true);
  }

  void _startConnectivityWatch() {
    if (_connSub != null) return;
    _connSub = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  void _onConnectivityChanged(List<ConnectivityResult> current) {
    final changed =
        current.length != _lastConnectivity.length ||
        current.any((result) => !_lastConnectivity.contains(result));
    final wasOffline =
        _lastConnectivity.isEmpty ||
        _lastConnectivity.contains(ConnectivityResult.none);
    final isOffline = current.contains(ConnectivityResult.none);
    _lastConnectivity = List.of(current);
    if (!changed) return;
    _networkGeneration++;
    _powerGeneration++;
    _powerOperation.invalidate();
    if (powerLoading) powerLoading = false;
    _connectivityDebounce?.cancel();

    if (isOffline) {
      _setCampusNetworkStatus(CampusNetworkStatus.unavailable);
      return;
    }

    _setCampusNetworkStatus(CampusNetworkStatus.checking);
    final generation = _networkGeneration;
    _connectivityDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(
        _handleNetworkAvailable(generation: generation, wasOffline: wasOffline),
      );
    });
  }

  Future<void> _handleNetworkAvailable({
    required int generation,
    required bool wasOffline,
  }) async {
    final activeProbe = _campusProbe;
    if (activeProbe != null) await activeProbe;
    if (generation != _networkGeneration) return;

    final campusOk = await checkCampusNetwork(force: true);
    if (generation != _networkGeneration) return;

    talker.info(
      '[ACTION] 网络变化\n${wasOffline ? "恢复连接" : "切换网络"}, '
      '校园网${campusOk ? "可达" : "不可达"}',
    );

    final sid = _savedStudentId;
    final prefs = _savedPrefs;
    final dataGeneration = _dataGeneration;
    if (sid == null || prefs == null) return;

    final pwd = await CredentialStorage.getSavedPassword();
    if (pwd == null ||
        dataGeneration != _dataGeneration ||
        sid != _savedStudentId) {
      return;
    }

    await _loadBackgroundData(
      studentId: sid,
      password: pwd,
      prefs: prefs,
      roomId: _savedRoomId,
      campusAvailable: campusOk,
      generation: dataGeneration,
    );
  }

  // ── Helpers ──

  void _resetLoadingFlags() {
    powerLoading = false;
    yktLoading = false;
    examLoading = false;
    repairLoading = false;
    netAuthLoading = false;
    jpLoading = false;
  }

  void _invalidateOperations() {
    _powerOperation.invalidate();
    _yktOperation.invalidate();
    _examOperation.invalidate();
    _repairOperation.invalidate();
    _netAuthOperation.invalidate();
    _jpOperation.invalidate();
  }

  Future<void> _loadBackgroundData({
    required String studentId,
    required String password,
    required PreferencesStorage prefs,
    required String? roomId,
    required bool campusAvailable,
    required int generation,
  }) async {
    if (generation != _dataGeneration) return;
    final futures = <Future<void>>[];

    if (campusAvailable && roomId != null && roomId.isNotEmpty) {
      futures.add(loadPower(roomId, prefs));
    } else if (!campusAvailable) {
      _restorePowerCache(prefs, roomId: roomId);
      notifyListeners();
    }
    futures.add(loadYkt(studentId, password, prefs));
    futures.add(loadRepair(studentId, password, prefs));
    futures.add(loadNetAuth(studentId, password, prefs));
    if (campusAvailable) {
      futures.add(loadJp(studentId, password, prefs));
    }

    await Future.wait(futures);
  }

  static Future<T> _retryOnce<T>(
    Future<T> Function() fn, {
    bool Function()? canRetry,
  }) async {
    try {
      return await fn();
    } on AuthException {
      if (canRetry != null && !canRetry()) rethrow;
      await Future.delayed(const Duration(seconds: 1));
      if (canRetry != null && !canRetry()) rethrow;
      return await fn();
    }
  }
}
