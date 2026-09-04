import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../ui/app_components.dart';
import 'profile_components.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return AppPage(
      title: '主题设置',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          const ProfileSectionLabel(title: '主题模式'),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: FLucideIcons.sunMoon,
                title: '主题模式',
                value: _themeTitle(settings.themePreference),
                onTap: () =>
                    _openThemeSheet(context, ref, settings.themePreference),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProfileSectionLabel(title: '软件主题色'),
          SizedBox(
            height: 32,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final color in AppThemeColor.values) ...[
                    _ThemeColorSwatch(
                      color: color,
                      selected: color == settings.themeColor,
                      onTap: () => ref
                          .read(appSettingsProvider.notifier)
                          .setThemeColor(color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _themeTitle(AppThemePreference preference) =>
      switch (preference) {
        AppThemePreference.system => '跟随系统',
        AppThemePreference.light => '浅色模式',
        AppThemePreference.dark => '深色模式',
      };

  static Future<void> _openThemeSheet(
    BuildContext context,
    WidgetRef ref,
    AppThemePreference current,
  ) async {
    final selected = await showAppSheet<AppThemePreference>(
      context: context,
      builder: (context) => AppOptionSheet<AppThemePreference>(
        title: '主题模式',
        value: current,
        options: const [
          AppOption(
            value: AppThemePreference.system,
            title: '跟随系统',
            subtitle: '自动跟随系统深色/浅色',
            icon: FLucideIcons.settings,
          ),
          AppOption(
            value: AppThemePreference.light,
            title: '浅色模式',
            icon: FLucideIcons.sun,
          ),
          AppOption(
            value: AppThemePreference.dark,
            title: '深色模式',
            icon: FLucideIcons.moon,
          ),
        ],
      ),
    );
    if (selected != null && selected != current) {
      await ref.read(appSettingsProvider.notifier).setThemePreference(selected);
    }
  }
}

class _ThemeColorSwatch extends StatelessWidget {
  final AppThemeColor color;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: color.label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? context.theme.colors.primary
                : context.theme.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
      ),
    ),
  );
}
