import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/cas_service.dart';
import '../../services/netauth_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import 'operator_binding_page.dart';

class NetworkManagementPage extends StatefulWidget {
  final NetAuthResult result;
  final String account;
  final String password;
  final PreferencesStorage preferencesStorage;

  const NetworkManagementPage({
    super.key,
    required this.result,
    required this.account,
    required this.password,
    required this.preferencesStorage,
  });

  @override
  State<NetworkManagementPage> createState() => _NetworkManagementPageState();
}

class _NetworkManagementPageState extends State<NetworkManagementPage> {
  late NetAuthInfo _info;
  late List<NetAuthDevice> _devices;
  String? _unbindingMac;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _info = widget.result.info;
    _devices = widget.result.devices;
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final result = await ToolsDataManager.instance.refreshNetAuth(
        widget.account,
        widget.password,
        widget.preferencesStorage,
      );
      if (!mounted) return;
      if (result == null) {
        showAppSnackBar(context, '刷新失败');
        return;
      }
      setState(() {
        _info = result.info;
        _devices = result.devices;
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('网络管理详情刷新失败', e, stackTrace);
      if (mounted) showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      talker.error('网络管理详情况刷新异常', e, stackTrace);
      if (mounted) showAppSnackBar(context, '刷新失败');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _unbind(NetAuthDevice device) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '解绑设备',
      message: '确定要解绑 ${device.mac} 吗？',
    );
    if (!confirmed || !mounted) return;

    setState(() => _unbindingMac = device.mac);
    try {
      final msg = await NetAuthService().unbindMac(
        widget.account,
        widget.password,
        device.mac,
      );
      if (!mounted) return;
      showAppSnackBar(context, msg);
      await _refresh();
    } on AuthException catch (e, stackTrace) {
      talker.error('网络管理设备解绑失败', e, stackTrace);
      if (mounted) showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      talker.error('网络管理设备解绑异常', e, stackTrace);
      if (mounted) showAppSnackBar(context, '解绑失败');
    } finally {
      if (mounted) setState(() => _unbindingMac = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppPage(
      title: '网络管理',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _isRefreshing ? null : _refresh,
          tooltip: '刷新网络状态',
          loading: _isRefreshing,
        ),
      ],
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          Text('账号信息', style: theme.typography.pageTitle),
          const SizedBox(height: AppSpacing.md),
          AppAdaptiveGrid(
            children: [
              _buildMetricCell(theme, '套餐', _info.group),
              _buildMetricCell(theme, '状态', _info.status),
              _buildMetricCell(
                theme,
                '已用时长',
                '${_info.usedHours.toStringAsFixed(1)} 小时',
              ),
              _buildMetricCell(
                theme,
                '已用流量',
                '${_info.usedFlowGb.toStringAsFixed(2)} GB',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            '在线设备 (${_devices.length}/${_info.maxDevices})',
            style: theme.typography.pageTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Text(
                  '暂无在线设备',
                  style: theme.typography.bodyText.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
            )
          else
            ..._devices.map((d) => _buildDeviceTile(theme, d)),
          const SizedBox(height: AppSpacing.xxl),
          FButton(
            variant: FButtonVariant.secondary,
            onPress: () => Navigator.of(context).push(
              appRoute(
                name: AppRouteNames.operatorBinding,
                builder: (_) => OperatorBindingPage(
                  account: widget.account,
                  password: widget.password,
                ),
              ),
            ),
            prefix: const Icon(FLucideIcons.creditCard),
            child: const Text('绑定运营商'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell(FThemeData theme, String label, String value) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(FThemeData theme, NetAuthDevice device) {
    final isUnbinding = _unbindingMac == device.mac;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              device.online ? FLucideIcons.wifi : FLucideIcons.wifiOff,
              color: device.online
                  ? theme.colors.primary
                  : theme.colors.mutedForeground,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.mac,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.type}  ${device.ip}',
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  Text(
                    device.lastTime,
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (isUnbinding)
              const SizedBox(
                width: 18,
                height: 18,
                child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
              )
            else
              AppIconButton(
                icon: FLucideIcons.link2Off,
                onPress: () => _unbind(device),
                tooltip: '解绑',
                size: FButtonSizeVariant.xs,
              ),
          ],
        ),
      ),
    );
  }
}
