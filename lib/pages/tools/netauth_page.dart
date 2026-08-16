import 'package:flutter/material.dart';

import '../../services/cas_service.dart';
import '../../services/netauth_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/snackbar_helper.dart';
import 'operator_bind_page.dart';

class NetAuthPage extends StatefulWidget {
  final NetAuthResult result;
  final String account;
  final String password;
  final PreferencesStorage preferencesStorage;

  const NetAuthPage({
    super.key,
    required this.result,
    required this.account,
    required this.password,
    required this.preferencesStorage,
  });

  @override
  State<NetAuthPage> createState() => _NetAuthPageState();
}

class _NetAuthPageState extends State<NetAuthPage> {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解绑设备'),
        content: Text('确定要解绑 ${device.mac} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('网络管理'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refresh,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '账号信息',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCell(theme, '套餐', _info.group),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCell(theme, '状态', _info.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCell(
                            theme,
                            '已用时长',
                            '${_info.usedHours.toStringAsFixed(1)} 小时',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCell(
                            theme,
                            '已用流量',
                            '${_info.usedFlowGb.toStringAsFixed(2)} GB',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '在线设备 (${_devices.length}/${_info.maxDevices})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      '暂无在线设备',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ..._devices.map((d) => _buildDeviceTile(theme, d)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OperatorBindPage(
                        account: widget.account,
                        password: widget.password,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.sim_card_outlined),
                  label: const Text('绑定运营商'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCell(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(110),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(ThemeData theme, NetAuthDevice device) {
    final isUnbinding = _unbindingMac == device.mac;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              device.online ? Icons.wifi : Icons.wifi_off,
              color: device.online
                  ? Colors.green
                  : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.mac,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.type}  ${device.ip}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    device.lastTime,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isUnbinding)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.link_off, size: 20),
                onPressed: () => _unbind(device),
                tooltip: '解绑',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}
