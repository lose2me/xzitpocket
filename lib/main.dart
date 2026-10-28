import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'app.dart';
import 'models/school_calendar.dart';
import 'pages/home_page.dart';
import 'providers/config_provider.dart';
import 'services/course_storage.dart';
import 'services/control_service.dart';
import 'services/preferences_storage.dart';
import 'services/talker.dart';
import 'services/talker_network_reporter.dart';
import 'services/tools_data_manager.dart';
import 'utils/orientation_lock.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phones stay in portrait; tablets may rotate. The shortest side is used so
  // a phone launched in landscape is still recognised as a phone.
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  if (view != null) {
    final logicalSize = Size(
      view.physicalSize.width / view.devicePixelRatio,
      view.physicalSize.height / view.devicePixelRatio,
    );
    await applyOrientationPolicy(logicalSize);
  }

  await setupErrorHooks(talker);
  TalkerNetworkReporter.instance.initialize();

  final courseStorage = CourseStorage();
  final preferencesStorage = PreferencesStorage();
  // These are the only startup operations required to build the first page.
  // Run them concurrently; platform widget sync and network probes happen
  // after the first frame so a cold launch can paint immediately.
  await Future.wait([courseStorage.init(), preferencesStorage.init()]);

  // Central control gate: no control communication while logged out.
  ControlService.instance.updateLoginGate(preferencesStorage.getStudentId());

  // Apply the last successfully downloaded calendar before the first frame;
  // the bundled calendar remains the fallback when no cache is available.
  final cachedCalendar = preferencesStorage.getSchoolCalendarCache();
  if (cachedCalendar != null) {
    try {
      final payload = schoolCalendarPayloadFromJson(cachedCalendar);
      semesterCalendar.replaceDays(payload.days);
      semesterCalendar.replaceSlots(payload.slots);
    } catch (error, stackTrace) {
      talker.warning('本地校历缓存无效，继续使用内置校历', error, stackTrace);
    }
  }

  // Restore the pending calendar-update reminder so the timetable banner
  // survives a restart until the user dismisses it.
  if (preferencesStorage.getSchoolCalendarUpdateNotice()) {
    semesterCalendar.setCalendarUpdateNotice(true);
  }

  // Defer widget navigation until the first frame. A cold launch can deliver
  // the widget intent before HomePage has mounted, which otherwise drops the
  // navigation request or competes with the initial PageView layout.
  HomeWidget.widgetClicked.listen(
    (uri) => _handleWidgetLaunch(uri, preferencesStorage),
  );

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
    unawaited(_handleInitialWidgetLaunch(preferencesStorage));
  });
}

DateTime? _lastWidgetLaunchAt;

void _handleWidgetLaunch(Uri? uri, PreferencesStorage prefs) {
  if (uri == null) return;
  final now = DateTime.now();
  if (_lastWidgetLaunchAt != null &&
      now.difference(_lastWidgetLaunchAt!) <
          const Duration(milliseconds: 500)) {
    return;
  }
  _lastWidgetLaunchAt = now;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final studentId = prefs.getStudentId();
    if (studentId == null || studentId.isEmpty) {
      // 未登录：小组件进入直接落在登录页，不做校园网探测。
      HomePage.globalKey.currentState?.switchToProfile();
      return;
    }
    unawaited(ToolsDataManager.instance.checkCampusNetwork(force: true));
    // 小组件入口：直接跳到主课表当前周，不播放翻页动画。
    HomePage.globalKey.currentState?.switchToTimetable(animate: false);
  });
}

Future<void> _handleInitialWidgetLaunch(PreferencesStorage prefs) async {
  try {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handleWidgetLaunch(uri, prefs);
  } catch (error, stackTrace) {
    talker.debug('读取小组件启动参数失败', error, stackTrace);
  }
}
