import 'dart:async';

import 'package:flutter/material.dart';

import 'tools/tools_page.dart';
import 'timetable/timetable_page.dart';
import 'me/me_page.dart';

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

  void switchToMe() {
    if (_currentIndex != 2) {
      setState(() => _currentIndex = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TickerMode(
            enabled: _currentIndex == 0,
            child: TimetablePage(key: TimetablePage.globalKey),
          ),
          ToolsPage(key: ToolsPage.globalKey),
          MePage(key: MePage.globalKey),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            indicatorColor: Colors.transparent,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(
                  color: Theme.of(context).colorScheme.primary,
                );
              }
              return IconThemeData(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                );
              }
              return TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              );
            }),
          ),
        ),
        child: NavigationBar(
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) {
            if (_currentIndex == 2 && i != 2) {
              MePage.globalKey.currentState?.resetUnsavedRoomId();
            }
            setState(() => _currentIndex = i);
            if (i == 1) {
              final refresh = ToolsPage.globalKey.currentState?.refreshData();
              if (refresh != null) unawaited(refresh);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: '课表',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: '比格',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
