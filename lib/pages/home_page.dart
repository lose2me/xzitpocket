import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../models/app_settings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/config_provider.dart';
import '../services/talker.dart';
import '../ui/app_components.dart';
import 'about/disclaimer_page.dart';
import 'tools/tools_page.dart';
import 'timetable/timetable_page.dart';
import '../ui/home_layout.dart';
import 'profile/profile_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  /// Global key to access state from widget click handler.
  static final globalKey = GlobalKey<HomePageState>();

  @override
  ConsumerState<HomePage> createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  static const _navigationDiagnostics = bool.fromEnvironment(
    'NAV_LAYOUT_DIAGNOSTICS',
  );

  int _currentIndex = 0;
  final _navigationKey = _navigationDiagnostics ? GlobalKey() : null;
  late final PageController _pageController;
  late final PageController _backgroundPageController;

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
    // 未登录时（冷启动/小组件进入）直接落在登录页（「我的」标签）。
    final studentId = ref.read(preferencesStorageProvider).getStudentId();
    _currentIndex = (studentId == null || studentId.isEmpty) ? 2 : 0;
    _pageController = PageController(initialPage: _currentIndex);
    _backgroundPageController = PageController(initialPage: _currentIndex);
    _timetablePage = TimetablePage(key: TimetablePage.globalKey);
    _toolsPage = ToolsPage(key: ToolsPage.globalKey);
    _profilePage = ProfilePage(key: ProfilePage.globalKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowDisclaimer());
    });
  }

  /// First-install compliance gate: the disclaimer route cannot be dismissed
  /// by back navigation, only by its own buttons. Accepting persists the flag
  /// permanently, so this is a no-op on every later launch.
  Future<void> _maybeShowDisclaimer() async {
    if (!mounted) return;
    final prefs = ref.read(preferencesStorageProvider);
    if (prefs.getDisclaimerAccepted()) return;
    final accepted = await Navigator.of(context).push<bool>(
      appRoute(
        name: AppRouteNames.disclaimer,
        fullscreenDialog: true,
        builder: (_) => const DisclaimerPage(),
      ),
    );
    // 同意后直接进入登录页（「我的」标签）。
    if (accepted == true) switchToProfile();
  }

  /// 切换到「我的」标签（登录页 / 个人中心）。
  void switchToProfile() {
    if (!mounted) return;
    if (_currentIndex != 2) {
      setState(() => _currentIndex = 2);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients && _pageController.page?.round() != 2) {
        _pageController.jumpToPage(2);
      }
      if (_backgroundPageController.hasClients &&
          _backgroundPageController.page?.round() != 2) {
        _backgroundPageController.jumpToPage(2);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _backgroundPageController.dispose();
    super.dispose();
  }

  void switchToTimetable({bool animate = true}) {
    if (!mounted) return;
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients && _pageController.page?.round() != 0) {
        _pageController.jumpToPage(0);
      }
      if (_backgroundPageController.hasClients &&
          _backgroundPageController.page?.round() != 0) {
        _backgroundPageController.jumpToPage(0);
      }
      TimetablePage.globalKey.currentState?.jumpToCurrentWeek(animate: animate);
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
    final timetableBackgroundPath = settings.timetableBackgroundFor(
      Theme.of(context).brightness,
    );
    final hasBackgroundAsset =
        timetableBackgroundPath != null && timetableBackgroundPath.isNotEmpty;
    final showGlobalBackground = hasBackgroundAsset && _currentIndex == 0;
    final backgroundVisibleBehindNavigation =
        showGlobalBackground && _currentIndex == 0;
    if (hasBackgroundAsset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_backgroundPageController.hasClients) {
          return;
        }
        if (_backgroundPageController.page?.round() != _currentIndex) {
          _backgroundPageController.jumpToPage(_currentIndex);
        }
      });
    }
    final shell = FScaffold(
      scaffoldStyle: showGlobalBackground
          ? const FScaffoldStyleDelta.delta(
              backgroundColor: Color(0x00000000),
              sidebarBackgroundColor: Color(0x00000000),
              footerDecoration: DecorationDelta.value(BoxDecoration()),
            )
          : const FScaffoldStyleDelta.delta(
              footerDecoration: DecorationDelta.value(BoxDecoration()),
            ),
      resizeToAvoidBottomInset: false,
      childPad: false,
      footer: buildHomeNavigationBar(
        key: _navigationKey,
        showServices: showServices,
        transparent: backgroundVisibleBehindNavigation,
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
          if (_backgroundPageController.hasClients) {
            _backgroundPageController.jumpToPage(targetTab);
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
            // Profile needs the live keyboard inset, but must keep the page's
            // consumed safe-area padding. Restoring the entire ambient query
            // reserves the bottom safe area again above the shell footer.
            // The page instances are cached above, so the shell rebuild no
            // longer cascades into the page subtrees on each IME frame.
            final pageWithInsets = index == 2
                ? MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(viewInsets: ambientMediaQuery.viewInsets),
                    child: page,
                  )
                : page;
            return TickerMode(enabled: isActive, child: pageWithInsets);
          },
        ),
      ),
    );

    if (_navigationDiagnostics) {
      _scheduleNavigationDiagnostics(
        ambientMediaQuery,
        hasBackgroundAsset: hasBackgroundAsset,
        showGlobalBackground: showGlobalBackground,
      );
    }

    // Keep the shell's own inset at zero. Profile injects the live inset into
    // its dedicated root scaffold; this prevents the nav shell and timetable
    // render tree from participating in the keyboard animation.
    if (!hasBackgroundAsset) return shell;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: PageView.builder(
              controller: _backgroundPageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                if (index != 0) return const SizedBox.expand();
                return Image.file(
                  File(timetableBackgroundPath),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  // 背景加载失败时必须回退到主题背景色：透明 scaffold +
                  // 透明占位会让整屏变成白屏（个性化设置返回白屏的路径之一）。
                  errorBuilder: (context, error, stackTrace) =>
                      ColoredBox(color: context.theme.colors.background),
                );
              },
            ),
          ),
        ),
        shell,
      ],
    );
  }

  void _scheduleNavigationDiagnostics(
    MediaQueryData ambientMediaQuery, {
    required bool hasBackgroundAsset,
    required bool showGlobalBackground,
  }) {
    final tab = _currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tab != _currentIndex) return;
      final navigationContext = _navigationKey?.currentContext;
      final box = navigationContext?.findRenderObject();
      if (navigationContext == null || box is! RenderBox || !box.hasSize) {
        return;
      }
      final rawQuery = MediaQueryData.fromView(View.of(navigationContext));
      final navigationQuery = MediaQuery.of(navigationContext);
      final navigation = navigationContext.widget as FBottomNavigationBar;
      final theme = navigationContext.theme;
      final style = navigation.style(theme.bottomNavigationBarStyle);
      final scaffold = navigationContext
          .findAncestorWidgetOfExactType<FScaffold>()!;
      final scaffoldStyle = scaffold.scaffoldStyle(theme.scaffoldStyle);
      final pageContext = switch (tab) {
        0 => TimetablePage.globalKey.currentContext,
        1 => ToolsPage.globalKey.currentContext,
        _ => ProfilePage.globalKey.currentContext,
      };
      final pageQuery = pageContext == null ? null : MediaQuery.of(pageContext);
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final message =
          '[NAV_LAYOUT] ${jsonEncode({
            'tab': const ['课表', '服务', '我的'][tab],
            'backgroundConfigured': hasBackgroundAsset,
            'backgroundVisible': showGlobalBackground,
            'brightness': Theme.of(navigationContext).brightness.name,
            'rect': [rect.left, rect.top, rect.width, rect.height],
            'raw': _diagnosticMediaQuery(rawQuery),
            'normalized': _diagnosticMediaQuery(ambientMediaQuery),
            'navigation': _diagnosticMediaQuery(navigationQuery),
            'page': pageQuery == null ? null : _diagnosticMediaQuery(pageQuery),
            'decoration': style.decoration.toString(),
            'footerDecoration': scaffoldStyle.footerDecoration.toString(),
            'padding': style.padding.toString(),
            'shellSystemOverlay': _diagnosticSystemOverlay(scaffoldStyle.systemOverlayStyle),
          })}';
      // Talker is disabled by default. Keep the opt-in measurements available
      // in flutter run / adb logcat even before enabling the in-app log viewer.
      debugPrint(message);
      talker.info(message);
    });
  }

  static Map<String, Object> _diagnosticMediaQuery(MediaQueryData query) => {
    'size': [query.size.width, query.size.height],
    'dpr': query.devicePixelRatio,
    'paddingBottom': query.padding.bottom,
    'viewPaddingBottom': query.viewPadding.bottom,
    'viewInsetsBottom': query.viewInsets.bottom,
    'textScale': query.textScaler.scale(10) / 10,
  };

  static Map<String, Object?> _diagnosticSystemOverlay(
    SystemUiOverlayStyle style,
  ) => {
    'navigationBarColor': style.systemNavigationBarColor?.toARGB32(),
    'navigationBarDividerColor': style.systemNavigationBarDividerColor
        ?.toARGB32(),
    'navigationBarIconBrightness':
        style.systemNavigationBarIconBrightness?.name,
    'navigationBarContrastEnforced': style.systemNavigationBarContrastEnforced,
  };
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
    // Android freeform/split windows can report system insets that are larger
    // than the available content height. Capping them keeps the page body
    // from being laid out at zero height while retaining a small safe margin.
    final normalizedMediaQuery = normalizeHomeMediaQuery(mediaQuery);
    return MediaQuery(
      data: normalizedMediaQuery.copyWith(viewInsets: EdgeInsets.zero),
      child: Builder(
        builder: (context) => builder(context, normalizedMediaQuery),
      ),
    );
  }
}
