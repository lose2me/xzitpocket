import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../ui/app_components.dart';

/// 开源许可证页面：forui 风格，布局与功能参照 Flutter 官方 [LicensePage]
/// （头部：应用名/版本/版权信息居中；列表：按包分组，副标题显示许可证数量；
///  点击包名进入详情页查看完整许可证段落）。
class OpenSourceLicensePage extends StatefulWidget {
  const OpenSourceLicensePage({super.key});

  @override
  State<OpenSourceLicensePage> createState() => _OpenSourceLicensePageState();
}

class _OpenSourceLicensePageState extends State<OpenSourceLicensePage> {
  late final Future<_LicenseData> _licenses = _loadLicenses();
  Future<_LicenseData> _loadLicenses() async {
    final licenses = <LicenseEntry>[];
    await for (final entry in LicenseRegistry.licenses) {
      licenses.add(entry);
    }
    return _LicenseData(licenses);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '开源许可证',
      child: FutureBuilder<_LicenseData>(
        future: _licenses,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppPageBody(
              maxWidth: AppLayout.resultMaxWidth,
              child: Center(
                child: FCircularProgress(size: FCircularProgressSizeVariant.md),
              ),
            );
          }
          if (snapshot.hasError) {
            return AppPageBody(
              maxWidth: AppLayout.resultMaxWidth,
              child: AppStateView(
                icon: FLucideIcons.circleAlert,
                title: '许可证加载失败',
                description: '${snapshot.error}',
                destructive: true,
              ),
            );
          }

          final data = snapshot.data ?? _LicenseData.empty();
          final packages = data.packages;
          return AppPageListView(
            maxWidth: AppLayout.resultMaxWidth,
            bottomPadding: AppSpacing.xxl,
            children: [
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, info) => _LicensePageHeader(
                  appName: info.data?.appName ?? '掌上徐工',
                  version: info.data?.version ?? '',
                ),
              ),
              const FDivider(),
              for (var index = 0; index < packages.length; index++) ...[
                _LicensePackageTile(
                  packageName: packages[index],
                  licenseCount: data.licenseCountOf(packages[index]),
                  onPress: () => _openPackage(packages[index], data),
                ),
                if (index < packages.length - 1) const FDivider(),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openPackage(String packageName, _LicenseData data) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PackageLicensePage(
          packageName: packageName,
          entries: data.entriesOf(packageName),
        ),
      ),
    );
  }
}

/// 页面头部：应用名 / 版本 居中显示（对应官方 [LicensePage] 的 _AboutProgram）。
class _LicensePageHeader extends StatelessWidget {
  final String appName;
  final String version;

  const _LicensePageHeader({required this.appName, required this.version});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Text(
            appName,
            textAlign: TextAlign.center,
            style: theme.typography.tileTitle.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (version.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '版本 $version',
              textAlign: TextAlign.center,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Powered by Flutter',
            textAlign: TextAlign.center,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// 包列表项：包名 + 「N 份许可证」副标题（对应官方 _LicensePageListTile）。
class _LicensePackageTile extends StatelessWidget {
  final String packageName;
  final int licenseCount;
  final VoidCallback onPress;

  const _LicensePackageTile({
    required this.packageName,
    required this.licenseCount,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FItem(
      title: Text(packageName),
      details: Text(
        '$licenseCount 份许可证',
        style: theme.typography.body.sm.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
      onPress: onPress,
    );
  }
}

/// 包许可证详情页（对应官方 _PackageLicensePage）：
/// 标题为包名，许可证段落间用分隔线，居中段落（如许可证名称）加粗居中。
class _PackageLicensePage extends StatelessWidget {
  final String packageName;
  final List<LicenseEntry> entries;

  const _PackageLicensePage({
    required this.packageName,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AppPage(
      title: '许可证',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              packageName,
              textAlign: TextAlign.center,
              style: theme.typography.pageTitle,
            ),
          ),
          for (final entry in entries) ...[
            const FDivider(),
            const SizedBox(height: AppSpacing.lg),
            for (final paragraph in entry.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  paragraph.text,
                  textAlign: paragraph.indent == LicenseParagraph.centeredIndent
                      ? TextAlign.center
                      : TextAlign.start,
                  style: paragraph.indent == LicenseParagraph.centeredIndent
                      ? theme.typography.body.md.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        )
                      : theme.typography.body.md.copyWith(height: 1.5),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 按包分组的许可证数据（对应官方 _LicenseData）。
class _LicenseData {
  final Map<String, List<LicenseEntry>> _byPackage = {};

  _LicenseData(List<LicenseEntry> licenses) {
    for (final entry in licenses) {
      for (final pkg in entry.packages) {
        _byPackage.putIfAbsent(pkg, () => []).add(entry);
      }
    }
  }

  _LicenseData.empty();

  List<String> get packages {
    final keys = _byPackage.keys.toList()..sort();
    return keys;
  }

  int licenseCountOf(String package) => _byPackage[package]?.length ?? 0;

  List<LicenseEntry> entriesOf(String package) =>
      _byPackage[package] ?? const [];
}
