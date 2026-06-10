import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/upgrade_config.dart';
import '../models/update_info.dart';
import '../providers/auth_provider.dart';
import '../providers/schedule_provider.dart';
import '../services/credential_storage.dart';
import '../services/update_service.dart';
import '../services/widget_service.dart';
import '../utils/snackbar_helper.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _sidCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isCheckingUpdate = false;

  @override
  void dispose() {
    _sidCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOpenSourceInfo(theme),
                  const SizedBox(height: 24),
                  if (UpgradeConfig.isConfigured) ...[
                    _buildCheckUpdateButton(),
                    const SizedBox(height: 24),
                  ],
                  Text('登录教务系统', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _sidCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '学号',
                      hintText: '请输入学号',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? '请输入学号' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pwdCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!isLoading) _login();
                    },
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '请输入密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? '请输入密码' : null,
                  ),
                  if (authState.status == AuthStatus.error) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withAlpha(120),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.errorMessage ?? '登录失败',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: isLoading ? null : _login,
                      child: isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('登录', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpenSourceInfo(ThemeData theme) {
    return Column(
      children: [
        Icon(Icons.code, size: 28, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          'github.com/lose2me/xzitpocket',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '';
            return Text(
              'Ver: $version License: GPL-3.0',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCheckUpdateButton() {
    return OutlinedButton.icon(
      onPressed: _isCheckingUpdate ? null : _checkForUpdate,
      icon: _isCheckingUpdate
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.system_update_alt_outlined),
      label: Text(_isCheckingUpdate ? '检查中...' : '检查更新'),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final sid = _sidCtrl.text.trim();
    final pwd = _pwdCtrl.text;

    final result = await ref.read(authProvider.notifier).login(sid, pwd);
    _pwdCtrl.clear();
    if (result != null) {
      await CredentialStorage.setSavedPassword(pwd);

      try {
        await ref
            .read(scheduleProvider.notifier)
            .updateFromLoginResult(
              courses: result.courses,
              studentId: result.studentId ?? sid,
              studentName: result.studentName ?? '',
            );
      } on WidgetSyncException catch (e) {
        if (mounted) {
          showAppSnackBar(context, '登录成功，但$e');
        }
      }
    }
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;

    setState(() => _isCheckingUpdate = true);
    try {
      final result = await UpdateService.checkForUpdate();
      if (!mounted) return;

      if (!result.hasUpdate || result.updateInfo == null) {
        showAppSnackBar(context, result.message ?? '当前已是最新版本');
        return;
      }

      await _showUpdateDialog(result.updateInfo!);
    } on UpdateException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '检查更新失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo updateInfo) {
    final notes = updateInfo.releaseNotes.trim();
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.isForced,
      builder: (ctx) => AlertDialog(
        title: Text(updateInfo.upgradeLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('发现新版本 ${updateInfo.versionName}'),
            const SizedBox(height: 8),
            Text('版本号: ${updateInfo.versionCode}'),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('更新说明'),
              const SizedBox(height: 4),
              Text(notes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (updateInfo.isForced) {
                await SystemNavigator.pop();
                return;
              }
              Navigator.pop(ctx);
            },
            child: Text(updateInfo.isForced ? '取消' : '稍后'),
          ),
          FilledButton(
            onPressed: () async {
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              await _showDownloadDialog(updateInfo);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDownloadDialog(UpdateInfo updateInfo) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDownloadDialog(updateInfo: updateInfo),
    );
  }
}

class _UpdateDownloadDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const _UpdateDownloadDialog({required this.updateInfo});

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  UpdateDownloadProgress _progress = const UpdateDownloadProgress(
    stage: UpdateDownloadStage.preparing,
    message: '准备下载更新包',
  );
  String? _errorMessage;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    setState(() {
      _errorMessage = null;
      _cancelToken = cancelToken;
      _progress = const UpdateDownloadProgress(
        stage: UpdateDownloadStage.preparing,
        message: '准备下载更新包',
      );
    });

    try {
      await UpdateService.downloadAndInstallUpdate(
        widget.updateInfo,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
          });
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '下载更新失败，请稍后重试';
      });
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressValue = _progress.progress;
    final title = switch (_progress.stage) {
      UpdateDownloadStage.preparing => '准备更新',
      UpdateDownloadStage.downloading => '正在下载',
      UpdateDownloadStage.installing => '准备安装',
    };

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(_errorMessage == null ? title : '更新失败'),
        content: _errorMessage == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('发现新版本 ${widget.updateInfo.versionName}'),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(value: progressValue),
                  const SizedBox(height: 12),
                  Text(
                    _progress.message ?? '',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _buildProgressLine(),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_progress.stage == UpdateDownloadStage.downloading) ...[
                    const SizedBox(height: 4),
                    Text(
                      '速率: ${_formatSpeed(_progress.bytesPerSecond)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              )
            : Text(_errorMessage!),
        actions: [
          if (_errorMessage == null && !widget.updateInfo.isForced)
            TextButton(
              onPressed: _cancelDownload,
              child: const Text('取消'),
            ),
          if (_errorMessage != null)
            TextButton(
              onPressed: () async {
                if (widget.updateInfo.isForced) {
                  await SystemNavigator.pop();
                  return;
                }
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: Text(widget.updateInfo.isForced ? '退出应用' : '关闭'),
            ),
          if (_errorMessage != null)
            FilledButton(
              onPressed: _startDownload,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }

  String _buildProgressLine() {
    if (_progress.stage == UpdateDownloadStage.installing) {
      return '已下载 ${_formatBytes(_progress.receivedBytes)}';
    }

    final received = _formatBytes(_progress.receivedBytes);
    if (_progress.totalBytes > 0) {
      final total = _formatBytes(_progress.totalBytes);
      final percent = ((_progress.progress ?? 0) * 100).clamp(0.0, 100.0);
      return '$received / $total  (${percent.toStringAsFixed(1)}%)';
    }
    return received;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final fractionDigits = unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
  }

  String _formatSpeed(double bytesPerSecond) {
    final safeValue = bytesPerSecond.isFinite ? bytesPerSecond : 0;
    return '${_formatBytes(safeValue.round())}/s';
  }
}
