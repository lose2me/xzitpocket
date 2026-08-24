import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/notice_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import 'notice_detail_page.dart';
import 'hqgl_notice_tab.dart';

import 'package:webview_flutter/webview_flutter.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  static final globalKey = GlobalKey<NoticePageState>();

  @override
  State<NoticePage> createState() => NoticePageState();
}

class NoticePageState extends State<NoticePage> {
  final _service = NoticeService();
  final _scrollController = ScrollController();

  List<NoticeItem> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      unawaited(_loadMore());
    }
  }

  Future<void> refreshData() => _refresh();

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final result = await _service.fetchList(page: 1);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _page = 1;
        _hasMore = result.items.isNotEmpty && _page < result.totalPages;
      });
    } on Exception catch (e, stackTrace) {
      talker.error('公告列表加载失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '公告加载失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _refreshing) return;
    setState(() => _loading = true);
    try {
      final result = await _service.fetchList(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...result.items];
        _page = result.page;
        _hasMore = result.items.isNotEmpty && result.page < result.totalPages;
      });
    } on Exception catch (e, stackTrace) {
      talker.error('公告列表翻页失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '加载更多失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail(NoticeItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoticeDetailPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppPage(
      title: '通知公告',
      root: true,
      headerStyle: FHeaderStyleDelta.delta(
        titleTextStyle: TextStyleDelta.value(
          context.theme.typography.display.xl.copyWith(
            color: context.theme.colors.foreground,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
      child: AppPageBody(
        maxWidth: AppLayout.contentMaxWidth,
        child: FTabs(
          expands: true,
          style: const FTabsStyleDelta.delta(spacing: 0),
          children: [
            FTabEntry(label: const Text('通知公告'), child: _buildNoticeTab(theme)),
            FTabEntry(label: const Text('后勤处'), child: const HqglNoticeTab()),
            FTabEntry(label: const Text('指南'), child: const NoticeGuideTab()),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeTab(FThemeData theme) {
    if (_items.isEmpty) {
      return AppPageBody(
        maxWidth: AppLayout.resultMaxWidth,
        child: AppStateView(
          icon: FLucideIcons.bell,
          title: _refreshing ? '加载中…' : '暂无公告',
        ),
      );
    }
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      controller: _scrollController,
      children: [
        for (final item in _items) _buildNoticeCard(theme, item),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: FCircularProgress(size: FCircularProgressSizeVariant.md),
            ),
          ),
      ],
    );
  }

  Widget _buildNoticeCard(FThemeData theme, NoticeItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        onPress: () => _openDetail(item),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.tileTitle.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  if (item.date.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.date,
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              FLucideIcons.chevronRight,
              size: 18,
              color: theme.colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

/// 指南 Tab：内嵌 VuePress 构建的在线指南（https://xuda.live/guide/）。
class NoticeGuideTab extends StatefulWidget {
  const NoticeGuideTab({super.key});

  @override
  State<NoticeGuideTab> createState() => _NoticeGuideTabState();
}

class _NoticeGuideTabState extends State<NoticeGuideTab> {
  late final WebViewController _controller;
  ({String background, String foreground, String border, String mode})?
  _themeConfig;
  bool _loading = true;
  bool _pageReady = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_initController());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colors = context.theme.colors;
    final nextConfig = (
      background: _hex(colors.background),
      foreground: _hex(colors.foreground),
      border: _hex(colors.border),
      mode: colors.brightness == Brightness.dark ? 'dark' : 'light',
    );
    final themeChanged = nextConfig != _themeConfig;
    _themeConfig = nextConfig;

    if (_pageReady && themeChanged) {
      unawaited(_applyPageCustomizations());
    }
  }

  String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  Future<void> _initController() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          _pageReady = false;
          unawaited(_primePageTheme());
        },
        onPageFinished: (_) {
          _pageReady = true;
          unawaited(_finishPageLoad());
        },
        onNavigationRequest: (request) {
          final url = request.url;
          if (url.startsWith('https://xuda.live/guide/') ||
              url == 'https://xuda.live/guide') {
            return NavigationDecision.navigate;
          }
          // 非指南页：重定向回指南首页。
          unawaited(
            _controller.loadRequest(Uri.parse('https://xuda.live/guide/')),
          );
          return NavigationDecision.prevent;
        },
      ),
    );
    await _controller.loadRequest(Uri.parse('https://xuda.live/guide/'));
  }

  Future<void> _finishPageLoad() async {
    await _applyPageCustomizations();
    if (mounted && _loading) {
      setState(() => _loading = false);
    }
  }

  // 尽早写入站点自己的主题偏好，供后续页面初始化脚本读取。
  Future<void> _primePageTheme() async {
    final config = _themeConfig;
    if (config == null) return;
    await _runJavaScript('''
      (function(){
        try {
          var mode='${config.mode}';
          localStorage.setItem('vuepress-theme-hope-scheme', mode);
          document.documentElement.setAttribute('data-theme', mode);
          document.documentElement.style.setProperty('color-scheme', mode, 'important');
        } catch(e) {}
      })();
    ''');
  }

  // 页面加载后注入：隐藏无关导航、限制站外跳转，并同步 app 主题。
  Future<void> _applyPageCustomizations() async {
    final config = _themeConfig;
    if (config == null) return;
    await _runJavaScript('''
      (function(){
        var GUIDE='https://xuda.live/guide/';
        var STYLE_ID='xzitpocket-guide-theme';
        window.__xzitPocketGuideConfig={
          background:'${config.background}',
          foreground:'${config.foreground}',
          border:'${config.border}',
          mode:'${config.mode}'
        };

        function hidePageChrome(){
          var sel='footer,.vp-footer-wrapper,.vp-footer,.vp-copyright,.vp-page-nav,.pager,.vp-breadcrumb';
          var ns=document.querySelectorAll(sel);
          for(var i=0;i<ns.length;i++){ns[i].style.setProperty('display','none','important');}
          var links=document.querySelectorAll('a');
          for(var j=0;j<links.length;j++){
            if((links[j].textContent||'').trim()==='聚合APP'){
              links[j].style.setProperty('display','none','important');
            }
          }
        }

        function applyAppTheme(){
          try {
            var config=window.__xzitPocketGuideConfig;
            var mode=config.mode;
            var html=document.documentElement;
            try{localStorage.setItem('vuepress-theme-hope-scheme',mode);}catch(e){}
            if(html.getAttribute('data-theme')!==mode){html.setAttribute('data-theme',mode);}

            var meta=document.querySelector('meta[name="color-scheme"]');
            if(!meta){meta=document.createElement('meta');meta.name='color-scheme';document.head.appendChild(meta);}
            meta.content=mode;

            var style=document.getElementById(STYLE_ID);
            if(!style){
              style=document.createElement('style');
              style.id=STYLE_ID;
              (document.head||html).appendChild(style);
            }
            var css=':root{color-scheme:'+mode+' !important;'+
              '--vp-c-bg:'+config.background+' !important;'+
              '--vp-c-text:'+config.foreground+' !important;'+
              '--navbar-c-bg:'+config.background+' !important;}'+
              'html,body,#app,.vp-page,.vp-page-wrapper,main#main-content{'+
              'background-color:'+config.background+' !important;}'+
              'body{color:'+config.foreground+' !important;}'+
              '.vp-navbar{background:'+config.background+' !important;'+
              'border-bottom:1px solid '+config.border+' !important;'+
              'box-shadow:none !important;backdrop-filter:none !important;'+
              '-webkit-backdrop-filter:none !important;}'+
              '.vp-toggle-sidebar-button:before,'+
              '.vp-toggle-sidebar-button:after,'+
              '.vp-toggle-sidebar-button .icon,'+
              '.vp-toggle-navbar-button .vp-top,'+
              '.vp-toggle-navbar-button .vp-middle,'+
              '.vp-toggle-navbar-button .vp-bottom{'+
              'background:'+config.foreground+' !important;}';
            if(style.textContent!==css){style.textContent=css;}
          } catch(e){}
        }

        hidePageChrome();
        applyAppTheme();

        if(!window.__xzitPocketGuideInstalled){
          window.__xzitPocketGuideInstalled=true;
          var refreshPending=false;
          new MutationObserver(function(){
            if(refreshPending)return;
            refreshPending=true;
            requestAnimationFrame(function(){
              refreshPending=false;
              hidePageChrome();
              applyAppTheme();
            });
          }).observe(document.documentElement,{
            childList:true,
            subtree:true,
            attributes:true,
            attributeFilter:['data-theme']
          });
          document.addEventListener('click',function(ev){
            var a=ev.target.closest&&ev.target.closest('a');
            if(!a)return;
            var abs=a.href||'';
            if(!abs||abs.indexOf(GUIDE)===0)return;
            ev.preventDefault();
            location.href=GUIDE;
          });
        }
      })();
    ''');
  }

  Future<void> _runJavaScript(String script) async {
    try {
      await _controller.runJavaScript(script);
    } catch (error, stackTrace) {
      talker.warning('指南页面定制脚本执行失败', error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: FCircularProgress());
    }
    return WebViewWidget(controller: _controller);
  }
}
