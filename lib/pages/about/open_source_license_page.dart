import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../ui/app_components.dart';

/// Displays the app and dependency licenses without Flutter's Material
/// [LicensePage] widget.
class OpenSourceLicensePage extends StatefulWidget {
  const OpenSourceLicensePage({super.key});

  @override
  State<OpenSourceLicensePage> createState() => _OpenSourceLicensePageState();
}

class _OpenSourceLicensePageState extends State<OpenSourceLicensePage> {
  late final Future<List<LicenseEntry>> _licenses = _loadLicenses();
  final _expanded = <int>{};

  Future<List<LicenseEntry>> _loadLicenses() async {
    final entries = <LicenseEntry>[];
    await for (final entry in LicenseRegistry.licenses) {
      entries.add(entry);
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '开源许可证',
      child: FutureBuilder<List<LicenseEntry>>(
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

          final entries = snapshot.data ?? const <LicenseEntry>[];
          return AppPageListView(
            maxWidth: AppLayout.resultMaxWidth,
            bottomPadding: AppSpacing.xxl,
            children: [
              FItem(
                title: const Text('掌上徐工'),
                details: const Text('GPL-3.0 License'),
              ),
              const FDivider(),
              for (var index = 0; index < entries.length; index++) ...[
                _LicenseEntryTile(
                  entry: entries[index],
                  expanded: _expanded.contains(index),
                  onPress: () => setState(() {
                    if (!_expanded.add(index)) _expanded.remove(index);
                  }),
                ),
                if (index < entries.length - 1) const FDivider(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LicenseEntryTile extends StatelessWidget {
  final LicenseEntry entry;
  final bool expanded;
  final VoidCallback onPress;

  const _LicenseEntryTile({
    required this.entry,
    required this.expanded,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final paragraphs = entry.paragraphs.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FItem(
          title: Text(entry.packages.join(', ')),
          semanticsExpanded: expanded,
          onPress: onPress,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Text(
              paragraphs.map((paragraph) => paragraph.text).join('\n\n'),
              style: context.theme.typography.bodySmall.copyWith(
                color: context.theme.colors.foreground,
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}
