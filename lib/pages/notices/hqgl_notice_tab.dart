import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/hqgl_service.dart';
import '../../services/notice_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import 'hqgl_detail_page.dart';

/// 「后勤处」Tab：后勤管理处的通知公告，通知本身多为 PDF/附件。
class HqglNoticeTab extends StatefulWidget {
  const HqglNoticeTab({super.key});

  @override
  State<HqglNoticeTab> createState() => _HqglNoticeTabState();
}

class _HqglNoticeTabState extends State<HqglNoticeTab> {
  final _service = HqglService();
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
      talker.error('后勤公告列表加载失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '加载失败', severity: ToastSeverity.error);
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
      talker.error('后勤公告翻页失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '加载更多失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail(NoticeItem item) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => HqglDetailPage(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    if (_items.isEmpty) {
      return AppPageBody(
        maxWidth: AppLayout.resultMaxWidth,
        child: AppStateView(
          icon: FLucideIcons.building2,
          title: _refreshing ? '加载中…' : '暂无后勤公告',
        ),
      );
    }
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      controller: _scrollController,
      children: [
        for (final item in _items) _buildCard(theme, item),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(FThemeData theme, NoticeItem item) {
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
