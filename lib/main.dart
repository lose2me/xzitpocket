import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'app.dart';
import 'constants/semester_config.dart';
import 'models/school_calendar.dart';
import 'pages/home_page.dart';
import 'providers/config_provider.dart';
import 'services/course_storage.dart';
import 'services/control_service.dart';
import 'services/preferences_storage.dart';
import 'services/talker.dart';
import 'services/talker_network_reporter.dart';
import 'services/tools_data_manager.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupErrorHooks(talker);
  TalkerNetworkReporter.instance.initialize();

  final courseStorage = CourseStorage();
  final preferencesStorage = PreferencesStorage();
  // These are the only startup operations required to build the first page.
  // Run them concurrently; platform widget sync and network probes happen
  // after the first frame so a cold launch can paint immediately.
  await Future.wait([courseStorage.init(), preferencesStorage.init()]);

  // Cross-version preference migration must run before any provider reads
  // stored settings, so incompatible values never reach the first frame.
  var settingsMigrated = false;
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    settingsMigrated = await preferencesStorage.migrateForVersionCode(
      packageInfo.buildNumber,
    );
  } catch (error, stackTrace) {
    talker.warning('配置版本迁移失败，继续使用现有配置', error, stackTrace);
  }

  // Central control gate: no control communication while logged out.
  ControlService.instance.updateLoginGate(preferencesStorage.getStudentId());

  // Apply the last successfully downloaded calendar before the first frame;
  // the bundled calendar remains the fallback when no cache is available.
  final cachedCalendar = preferencesStorage.getSchoolCalendarCache();
  if (cachedCalendar != null) {
    try {
      semesterCalendar.replaceDays(schoolCalendarDaysFromJson(cachedCalendar));
    } catch (error, stackTrace) {
      talker.warning('本地校历缓存无效，继续使用内置校历', error, stackTrace);
    }
  }

  // Defer widget navigation until the first frame. A cold launch can deliver
  // the widget intent before HomePage has mounted, which otherwise drops the
  // navigation request or competes with the initial PageView layout.
  HomeWidget.widgetClicked.listen(_handleWidgetLaunch);

  runApp(
    ProviderScope(
      overrides: [
        courseStorageProvider.overrideWithValue(courseStorage),
        preferencesStorageProvider.overrideWithValue(preferencesStorage),
      ],
      child: App(courseStorage: courseStorage),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_handleInitialWidgetLaunch());
    unawaited(
      _finishStartup(courseStorage, preferencesStorage, settingsMigrated),
    );
  });
}

DateTime? _lastWidgetLaunchAt;

void _handleWidgetLaunch(Uri? uri) {
  if (uri == null) return;
  final now = DateTime.now();
  if (_lastWidgetLaunchAt != null &&
      now.difference(_lastWidgetLaunchAt!) <
          const Duration(milliseconds: 500)) {
    return;
  }
  _lastWidgetLaunchAt = now;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(ToolsDataManager.instance.checkCampusNetwork(force: true));
    // 小组件入口：直接跳到主课表当前周，不播放翻页动画。
    HomePage.globalKey.currentState?.switchToTimetable(animate: false);
  });
}

Future<void> _handleInitialWidgetLaunch() async {
  try {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handleWidgetLaunch(uri);
  } catch (error, stackTrace) {
    talker.debug('读取小组件启动参数失败', error, stackTrace);
  }
}

Future<void> _finishStartup(
  CourseStorage courseStorage,
  PreferencesStorage preferencesStorage,
  bool settingsMigrated,
) async {
  ToolsDataManager.instance.initialize(preferencesStorage);
  await ControlService.instance.initialize();
  try {
    final calendarChanged = await ControlService.instance
        .refreshSchoolCalendarIfChanged(preferencesStorage);
    if (calendarChanged &&
        preferencesStorage.getUseCloudTimetableAdjustments()) {
      await courseStorage.applyCloudAdjustments(
        days: semesterCalendar.days,
        semesterStart: semesterStartDate,
      );
    }
  } catch (error, stackTrace) {
    talker.warning('读取在线校历失败，继续使用本地校历', error, stackTrace);
  }
  final controlAvailable = ControlService.instance.serviceAvailable;
  final studentId = preferencesStorage.getStudentId();
  if (controlAvailable && studentId != null && studentId.isNotEmpty) {
    // After a cross-version migration the stored profile may have been
    // cleaned up, so force control to re-record student id/name/class/college.
    unawaited(
      ControlService.instance.syncAfterOaLogin(
        studentId: studentId,
        displayName: preferencesStorage.getStudentName() ?? '',
        collegeName: preferencesStorage.getCollegeName() ?? '',
        className: preferencesStorage.getClassName() ?? '',
        forceProfileUpdate: settingsMigrated,
      ),
    );
  }
  await WidgetService.init();
  try {
    await WidgetService.updateWidget(
      courses: courseStorage.getCourses(),
      semesterStart: semesterStartDate,
    );
  } on WidgetSyncException catch (e) {
    talker.error('Initial widget sync failed', e);
  }
}
