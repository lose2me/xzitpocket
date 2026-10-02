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
      title: '功能启用',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          ProfileSettingsGroup(
            children: [
              for (final feature in AppServiceFeature.values)
                ProfileSettingsCheckboxTile(
                  icon: _featureIcon(feature),
                  title: feature.title,
                  value: !settings.hiddenServiceFeatures.contains(feature),
                  onChange: (visible) => ref
                      .read(appSettingsProvider.notifier)
                      .setServiceFeatureVisible(feature, visible),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _featureIcon(AppServiceFeature feature) => switch (feature) {
    AppServiceFeature.campusCard => FLucideIcons.creditCard,
    AppServiceFeature.power => FLucideIcons.zap,
    AppServiceFeature.exams => FLucideIcons.fileQuestion,
    AppServiceFeature.academic => FLucideIcons.graduationCap,
    AppServiceFeature.network => FLucideIcons.wifi,
    AppServiceFeature.repair => FLucideIcons.wrench,
    AppServiceFeature.learning => FLucideIcons.layoutGrid,
    AppServiceFeature.calendar => FLucideIcons.calendarDays,
    AppServiceFeature.teacherEvaluation => FLucideIcons.messageSquareMore,
  };
}
