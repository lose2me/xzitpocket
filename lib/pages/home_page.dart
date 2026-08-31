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
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void switchToTimetable() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TimetablePage.globalKey.currentState?.jumpToCurrentWeek();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _KeyboardIsolatedShell(builder: _buildShell);
  }

  Widget _buildShell(BuildContext context, MediaQueryData ambientMediaQuery) {
    final shell = FScaffold(
      resizeToAvoidBottomInset: false,
      childPad: false,
      footer: FBottomNavigationBar(
        index: _currentIndex,
        onChange: (i) {
          if (_currentIndex == 2 && i != 2) {
            ProfilePage.globalKey.currentState?.finishRoomIdEditing();
          }
          if (_currentIndex == i) return;
          setState(() => _currentIndex = i);
          if (_pageController.hasClients) {
            _pageController.jumpToPage(i);
          }
          if (i == 1) {
            // The page is lazy-built, so its state may not exist until the
            // jump has been laid out.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final refresh = ToolsPage.globalKey.currentState?.refreshData();
              if (refresh != null) unawaited(refresh);
            });
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
        child: PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          itemBuilder: (context, index) {
            final page = switch (index) {
              0 => TimetablePage(key: TimetablePage.globalKey),
              1 => ToolsPage(key: ToolsPage.globalKey),
              _ => ProfilePage(key: ProfilePage.globalKey),
            };
            final pageWithInsets = index == 2
                ? MediaQuery(data: ambientMediaQuery, child: page)
                : page;
            return TickerMode(
              enabled: _currentIndex == index,
              child: pageWithInsets,
            );
          },
        ),
      ),
    );

    // Keep the shell's own inset at zero. Profile injects the live inset into
    // its dedicated root scaffold; this prevents the nav shell and timetable
    // render tree from participating in the keyboard animation.
    return shell;
  }
}

/// Keeps IME metric updates out of the home state and the timetable/tools
/// render trees. Only the profile page receives the live bottom inset.
class _KeyboardIsolatedShell extends StatelessWidget {
  final Widget Function(BuildContext context, MediaQueryData mediaQuery)
  builder;

  const _KeyboardIsolatedShell({required this.builder});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(viewInsets: EdgeInsets.zero),
      child: Builder(builder: (context) => builder(context, mediaQuery)),
    );
  }
}
