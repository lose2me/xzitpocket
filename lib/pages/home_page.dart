import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../models/app_settings.dart';
import '../providers/app_settings_provider.dart';
import 'tools/tools_page.dart';
import 'timetable/timetable_page.dart';
import 'profile/profile_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  /// Global key to access state from widget click handler.
  static final globalKey = GlobalKey<HomePageState>();

  @override
  ConsumerState<HomePage> createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  late final PageController _pageController;

  /// The three tab pages are built once and the SAME widget instances are
  /// reused across rebuilds. The IME (viewInsets) animation rebuilds the
  /// home shell on every frame (because [_KeyboardIsolatedShell] reads
  /// `MediaQuery.of(context)` to re-inject the live inset into the profile
  /// page). Reusing the identical page instances lets the PageView's
  /// `updateChild` short-circuit, so the timetable / tools / profile subtrees
  /// are NOT rebuilt or re-laid-out on every keyboard frame.
  late final Widget _timetablePage;
  late final Widget _toolsPage;
  late final Widget _profilePage;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timetablePage = TimetablePage(key: TimetablePage.globalKey);
    _toolsPage = ToolsPage(key: ToolsPage.globalKey);
    _profilePage = ProfilePage(key: ProfilePage.globalKey);
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
    final settings = ref.watch(appSettingsProvider);
    final showServices = !AppServiceFeature.values.every(
      settings.hiddenServiceFeatures.contains,
    );
    final visibleTabs = showServices ? const [0, 1, 2] : const [0, 2];
    final selectedNavigationIndex = visibleTabs.contains(_currentIndex)
        ? visibleTabs.indexOf(_currentIndex)
        : 0;
    final shell = FScaffold(
      resizeToAvoidBottomInset: false,
      childPad: false,
      footer: FBottomNavigationBar(
        index: selectedNavigationIndex,
        onChange: (i) {
          final targetTab = visibleTabs[i];
          if (_currentIndex == 2 && targetTab != 2) {
            ProfilePage.globalKey.currentState?.finishRoomIdEditing();
          }
          if (_currentIndex == targetTab) return;
          setState(() => _currentIndex = targetTab);
          if (_pageController.hasClients) {
            _pageController.jumpToPage(targetTab);
          }
          if (targetTab == 1) {
            // The page is lazy-built, so its state may not exist until the
            // jump has been laid out.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final refresh = ToolsPage.globalKey.currentState?.refreshData();
              if (refresh != null) unawaited(refresh);
            });
          }
        },
        children: [
          FBottomNavigationBarItem(
            icon: Icon(FLucideIcons.calendarDays),
            label: Text('课表'),
          ),
          if (showServices)
            const FBottomNavigationBarItem(
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
            final isActive = _currentIndex == index;
            final page = switch (index) {
              0 => _timetablePage,
              1 => _toolsPage,
              _ => _profilePage,
            };
            // The profile page is the only page that contains text fields and
            // must avoid the keyboard. It is always wrapped in MediaQuery with
            // the LIVE inset so its root scaffold resizes correctly (this is
            // exactly what prevents the white/covered strip above the IME).
            // The page instances are cached above, so the shell rebuild no
            // longer cascades into the page subtrees on each IME frame.
            final pageWithInsets = index == 2
                ? MediaQuery(data: ambientMediaQuery, child: page)
                : page;
            return TickerMode(enabled: isActive, child: pageWithInsets);
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
