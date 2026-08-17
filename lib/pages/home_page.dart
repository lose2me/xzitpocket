import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'tools/tools_page.dart';
import 'timetable/timetable_page.dart';
import 'profile/profile_page.dart';
import 'notices/notice_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  /// Global key to access state from widget click handler.
  static final globalKey = GlobalKey<HomePageState>();

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  void switchToTimetable() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
    TimetablePage.globalKey.currentState?.jumpToCurrentWeek();
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      footer: FBottomNavigationBar(
        index: _currentIndex,
        onChange: (i) {
          if (_currentIndex == 3 && i != 3) {
            ProfilePage.globalKey.currentState?.finishRoomIdEditing();
          }
          setState(() => _currentIndex = i);
          if (i == 1) {
            final refresh = ToolsPage.globalKey.currentState?.refreshData();
            if (refresh != null) unawaited(refresh);
          } else if (i == 2) {
            final refresh = NoticePage.globalKey.currentState?.refreshData();
            if (refresh != null) unawaited(refresh);
          }
        },
        children: const [
          FBottomNavigationBarItem(
            icon: Icon(FLucideIcons.calendarDays),
            label: Text('课表'),
          ),
          FBottomNavigationBarItem(
            icon: Icon(FLucideIcons.layoutGrid),
            label: Text('服务'),
          ),
          FBottomNavigationBarItem(
            icon: Icon(FLucideIcons.megaphone),
            label: Text('通知'),
          ),
          FBottomNavigationBarItem(
            icon: Icon(FLucideIcons.userRound),
            label: Text('我的'),
          ),
        ],
      ),
      child: MediaQuery.removePadding(
        // 外层 FScaffold 的 footer 已包含底部手势条区域，
        // 移除内层页面的底部安全区，避免导航栏上方出现多余空白。
        context: context,
        removeBottom: true,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            TickerMode(
              enabled: _currentIndex == 0,
              child: TimetablePage(key: TimetablePage.globalKey),
            ),
            ToolsPage(key: ToolsPage.globalKey),
            NoticePage(key: NoticePage.globalKey),
            ProfilePage(key: ProfilePage.globalKey),
          ],
        ),
      ),
    );
  }
}
