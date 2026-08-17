import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/notice_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import 'notice_detail_page.dart';

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
      if (mounted) showAppSnackBar(context, '公告加载失败');
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
      if (mounted) showAppSnackBar(context, '加载更多失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail(NoticeItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoticeDetailPage(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppPage(
      title: '通知公告',
      root: true,
      // root 无返回键；统一为小号标题（display.xl），居中显示。
      headerStyle: FHeaderStyleDelta.delta(
        titleTextStyle: TextStyleDelta.value(
          context.theme.typography.display.xl.copyWith(
            color: context.theme.colors.foreground,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
      child: _items.isEmpty
          ? AppPageBody(
              maxWidth: AppLayout.resultMaxWidth,
              child: AppStateView(
                icon: FLucideIcons.bell,
                title: _refreshing ? '加载中…' : '暂无公告',
              ),
            )
          : AppPageListView(
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
                      child: FCircularProgress(
                        size: FCircularProgressSizeVariant.md,
                      ),
                    ),
                  ),
              ],
            ),
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
