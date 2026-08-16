import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'tools/tools_page.dart';
import 'timetable/timetable_page.dart';
import 'profile/profile_page.dart';

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
          if (_currentIndex == 2 && i != 2) {
            ProfilePage.globalKey.currentState?.finishRoomIdEditing();
          }
          setState(() => _currentIndex = i);
          if (i == 1) {
            final refresh = ToolsPage.globalKey.currentState?.refreshData();
            if (refresh != null) unawaited(refresh);
          }
        },
        children: const [
          FBottomNavigationBarItem(
            icon: Icon(FLucideIcons.calendarDays),
            label: Text('课表'),
          ),
          FBottomNavigationBarItem(
            icon: Icon(FLucideIcons.megaphone),
            label: Text('比格'),
          ),
          FBottomNavigationBarItem(
            icon: Icon(FLucideIcons.userRound),
            label: Text('我的'),
          ),
        ],
      ),
      child: IndexedStack(
        index: _currentIndex,
        children: [
          TickerMode(
            enabled: _currentIndex == 0,
            child: TimetablePage(key: TimetablePage.globalKey),
          ),
          ToolsPage(key: ToolsPage.globalKey),
          ProfilePage(key: ProfilePage.globalKey),
        ],
      ),
    );
  }
}
