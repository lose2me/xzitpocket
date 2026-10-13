import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/app_settings.dart';
import '../../models/course.dart';
import '../../models/school_calendar.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/secondary_schedule_provider.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../utils/course_text_template.dart';
import '../../utils/snackbar_helper.dart';
import '../profile/profile_components.dart';
import 'timetable_grid.dart';
import 'timetable_providers.dart';

double _backgroundAspectRatio(Size size) {
  final width = size.width.clamp(1.0, double.infinity).toDouble();
  final height = size.height.clamp(1.0, double.infinity).toDouble();
  return width / height;
}

final _styleColors = [
  for (final color in AppThemeColor.values) color.lightColor,
];

final _widgetBackgroundColors = [
  for (final color in AppPageBackgroundColor.values) color.lightColor,
];

class TimetableSettingsPage extends ConsumerStatefulWidget {
  const TimetableSettingsPage({super.key});

  @override
  ConsumerState<TimetableSettingsPage> createState() =>
      _TimetableSettingsPageState();
}

class _TimetableSettingsPageState extends ConsumerState<TimetableSettingsPage> {
  final _imagePicker = ImagePicker();
  bool _ignoreNextBackgroundTap = false;
  // 课程预览默认收起，下拉（或点击）展开。
  bool _previewExpanded = false;
  late final TextEditingController _templateController;
  final _templateFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _templateController = TextEditingController(
      text: ref.read(appSettingsProvider).timetableCourseTextTemplate,
    );
  }

  @override
  void dispose() {
    _templateController.dispose();
    _templateFocusNode.dispose();
    super.dispose();
  }

  /// 课程块文字模板编辑（单行输入，渲染允许多行）+ 复制 AI 提示词。
  Widget _buildTemplateEditor(AppSettings settings) {
    // 重置个性化或导入配置后同步输入框（编辑中不打断光标）。
    if (!_templateFocusNode.hasFocus &&
        _templateController.text != settings.timetableCourseTextTemplate) {
      _templateController.text = settings.timetableCourseTextTemplate;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionLabel(title: '课程块文字'),
        AppTextField(
          controller: _templateController,
          focusNode: _templateFocusNode,
          label: '文字模板（单行输入，\\n 换行）',
          hint: kDefaultCourseTextTemplate,
          maxLines: 1,
          onChanged: (value) => unawaited(
            ref
                .read(appSettingsProvider.notifier)
                .setTimetableCourseTextTemplate(value),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FButton(
          variant: FButtonVariant.outline,
          onPress: _copyTemplateAiPrompt,
          prefix: const Icon(FLucideIcons.copy),
          child: const Text('复制 AI 提示词'),
        ),
        const SizedBox(height: AppSpacing.md),
        const ProfileSettingsHint(
          '变量：{课程} {教师} {地点} {时间}；'
          '样式：[b]加粗、[s12]字号(px)、[c#亮色|#暗色]颜色、[左][中][右]对齐，[/] 关闭当前样式。'
          '# 和 @ 均为普通字符。含变量的行在变量为空时整行省略。',
        ),
        const SizedBox(height: AppSpacing.xl),
        const ProfileSectionLabel(title: '课程块'),
      ],
    );
  }

  Future<void> _copyTemplateAiPrompt() async {
    final prompt = buildCourseTemplateAiPrompt(
      ref.read(appSettingsProvider).timetableCourseTextTemplate,
    );
    await Clipboard.setData(ClipboardData(text: prompt));
    if (mounted) {
      showAppSnackBar(context, 'AI 提示词已复制', severity: ToastSeverity.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final showWeekendColumns = ref.watch(showWeekendColumnsProvider);
    final coursesAsync = ref.watch(scheduleProvider);
    final secondarySchedule = ref.watch(secondaryScheduleProvider);
    final previewCourses = secondarySchedule.active
        ? secondarySchedule.courses
        : (coursesAsync.value ?? const <Course>[]);
    final brightness = Theme.of(context).brightness;
    return AppPage(
      title: '个性化设置',
      actions: [
        AppIconButton(
          icon: FLucideIcons.trash2,
          onPress: _resetAppearance,
          tooltip: '重置个性化设置',
        ),
      ],
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.theme.colors.background,
              border: Border.all(
                color: context.theme.colors.foreground.withValues(alpha: 0.28),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.theme.colors.foreground.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
                BoxShadow(
                  color: context.theme.colors.foreground.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 下拉展开课程预览：默认收起，点击或下拉展开、上滑收起。
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _previewExpanded = !_previewExpanded),
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 0) {
                      setState(() => _previewExpanded = true);
                    } else if (velocity < 0) {
                      setState(() => _previewExpanded = false);
                    }
                  },
                  child: SizedBox(
                    height: 34,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _previewExpanded
                              ? FLucideIcons.chevronUp
                              : FLucideIcons.chevronDown,
                          size: 16,
                          color: context.theme.colors.mutedForeground,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '课程预览',
                          style: context.theme.typography.bodySmall.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _previewExpanded
                      ? ClipRect(
                          child: SizedBox(
                            height:
                                settings.timetableDayHeaderHeight +
                                settings.timetableSectionHeight * 2 +
                                2,
                            child: _TimetableGridPreview(
                              settings: settings,
                              courses: previewCourses,
                              showWeekendColumns: showWeekendColumns,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          Expanded(
            child: FTabs(
              scrollable: true,
              expands: true,
              // 只允许点击切换 Tab，不支持左右滑动（保留切换动画）。
              contentPhysics: const NeverScrollableScrollPhysics(),
              children: [
                FTabEntry(
                  label: const Text('主题外观'),
                  child: _tabList([
                    ProfileSettingsGroup(
                      children: [
                        ProfileSettingsOptionsTile<AppThemePreference>(
                          icon: FLucideIcons.sunMoon,
                          title: '主题模式',
                          value: settings.themePreference,
                          options: const [
                            ProfileSettingsOption(
                              value: AppThemePreference.system,
                              label: '跟随系统',
                            ),
                            ProfileSettingsOption(
                              value: AppThemePreference.light,
                              label: '浅色',
                            ),
                            ProfileSettingsOption(
                              value: AppThemePreference.dark,
                              label: '深色',
                            ),
                          ],
                          onChanged: (value) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setThemePreference(value),
                          ),
                        ),
                        ProfileSettingsColorTile(
                          icon: FLucideIcons.palette,
                          title: '主题色',
                          value:
                              settings.customThemeColor ??
                              settings.themeColor.color,
                          colors: _styleColors,
                          allowReset: false,
                          lastCustomColor: settings.lastCustomThemeColor,
                          onChanged: (color) {
                            if (color == null) return;
                            final selected = AppThemeColor.values.firstWhere(
                              (item) => item.color == color,
                            );
                            unawaited(
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setThemeColor(selected),
                            );
                          },
                          onCustomColorPressed: () => unawaited(
                            _selectCustomColor(
                              settings.lastCustomThemeColor ??
                                  settings.customThemeColor ??
                                  settings.themeColor.color,
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setCustomThemeColor,
                            ),
                          ),
                        ),
                        ProfileSettingsColorTile(
                          icon: FLucideIcons.paintBucket,
                          title: '页面背景色',
                          value:
                              settings.customPageBackgroundColor ??
                              settings.pageBackgroundColor?.resolve(brightness),
                          colors: [
                            for (final color in AppPageBackgroundColor.values)
                              color.resolve(brightness),
                          ],
                          onChanged: (color) {
                            final selected = color == null
                                ? null
                                : AppPageBackgroundColor.values.firstWhere(
                                    (item) =>
                                        item.resolve(brightness).toARGB32() ==
                                        color.toARGB32(),
                                  );
                            unawaited(
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setPageBackgroundColor(selected),
                            );
                          },
                          lastCustomColor:
                              settings.lastCustomPageBackgroundColor,
                          onCustomColorPressed: () => unawaited(
                            _selectCustomColor(
                              settings.lastCustomPageBackgroundColor ??
                                  settings.customPageBackgroundColor ??
                                  settings.pageBackgroundColor?.resolve(
                                    brightness,
                                  ) ??
                                  context.theme.colors.background,
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setCustomPageBackgroundColor,
                            ),
                          ),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.sunMedium,
                          title: '暗色模式沿用浅色背景图',
                          value: settings.timetableUseLightBackgroundInDarkMode,
                          onChange: (value) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setTimetableUseLightBackgroundInDarkMode(
                                  value,
                                ),
                          ),
                        ),
                        ProfileSettingsTile(
                          icon: FLucideIcons.sun,
                          title: '浅色背景图',
                          value: settings.timetableBackgroundPath == null
                              ? '点击选择'
                              : '长按删除',
                          onTap: settings.timetableBackgroundPath == null
                              ? () => _pickBackgroundAfterLongPress(dark: false)
                              : null,
                          onLongPress: settings.timetableBackgroundPath == null
                              ? null
                              : () => _clearBackground(dark: false),
                          onPointerUp: _releaseBackgroundPointer,
                        ),
                        ProfileSettingsTile(
                          icon: FLucideIcons.moon,
                          title: '暗色背景图',
                          value: settings.timetableDarkBackgroundPath == null
                              ? '点击选择'
                              : '长按删除',
                          onTap: settings.timetableDarkBackgroundPath == null
                              ? () => _pickBackgroundAfterLongPress(dark: true)
                              : null,
                          onLongPress:
                              settings.timetableDarkBackgroundPath == null
                              ? null
                              : () => _clearBackground(dark: true),
                          onPointerUp: _releaseBackgroundPointer,
                        ),
                      ],
                    ),
                  ]),
                ),
                FTabEntry(
                  label: const Text('课表网格'),
                  child: _tabList([
                    ProfileSettingsGroup(
                      children: [
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.rows3,
                          title: '课节高度',
                          value: settings.timetableSectionHeight,
                          defaultValue:
                              const AppSettings().timetableSectionHeight,
                          min: 40,
                          max: 140,
                          suffix: ' px',
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableSectionHeight(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.columns3,
                          title: '时间列宽度',
                          value: settings.timetableTimeColumnWidth,
                          defaultValue:
                              const AppSettings().timetableTimeColumnWidth,
                          min: 20,
                          max: 80,
                          suffix: ' px',
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableTimeColumnWidth(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.panelTop,
                          title: '日期栏高度',
                          value: settings.timetableDayHeaderHeight,
                          defaultValue:
                              const AppSettings().timetableDayHeaderHeight,
                          min: 30,
                          max: 80,
                          suffix: ' px',
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableDayHeaderHeight(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.grid2x2,
                          title: '显示网格线',
                          value: settings.showTimetableGridLines,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setShowTimetableGridLines(value),
                        ),
                        ProfileSettingsColorTile(
                          icon: FLucideIcons.square,
                          title: '网格线颜色',
                          value: settings.timetableGridLineColor,
                          colors: _styleColors,
                          lastCustomColor:
                              settings.timetableLastCustomGridLineColor,
                          onChanged: (color) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setTimetableGridLineColor(color),
                          ),
                          onCustomColorPressed: () => unawaited(
                            _selectCustomColor(
                              settings.timetableLastCustomGridLineColor ??
                                  settings.timetableGridLineColor ??
                                  context.theme.colors.border,
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setCustomTimetableGridLineColor,
                            ),
                          ),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.columns3,
                          title: '网格线粗细',
                          value: settings.timetableGridLineWidth,
                          defaultValue:
                              const AppSettings().timetableGridLineWidth,
                          min: 0.5,
                          max: 3,
                          suffix: ' px',
                          displayDecimals: 1,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableGridLineWidth(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.layers,
                          title: '网格线不透明度',
                          value: settings.timetableGridOpacity,
                          defaultValue:
                              const AppSettings().timetableGridOpacity,
                          min: 0,
                          max: 1,
                          suffix: '%',
                          displayMultiplier: 100,
                          displayDecimals: 0,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableGridOpacity(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.calendarDays,
                          title: '显示今日课程边线',
                          value: settings.showTodayGridLines,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setShowTodayGridLines(value),
                        ),
                        ProfileSettingsColorTile(
                          icon: FLucideIcons.palette,
                          title: '今日课程边线颜色',
                          value: settings.timetableTodayLineColor,
                          colors: _styleColors,
                          lastCustomColor:
                              settings.timetableLastCustomTodayLineColor,
                          onChanged: (color) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setTimetableTodayLineColor(color),
                          ),
                          onCustomColorPressed: () => unawaited(
                            _selectCustomColor(
                              settings.timetableLastCustomTodayLineColor ??
                                  settings.timetableTodayLineColor ??
                                  context.theme.colors.primary,
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setCustomTimetableTodayLineColor,
                            ),
                          ),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.move,
                          title: '今日课程边线粗细',
                          value: settings.timetableTodayLineWidth,
                          defaultValue:
                              const AppSettings().timetableTodayLineWidth,
                          min: 0.5,
                          max: 4,
                          suffix: ' px',
                          displayDecimals: 1,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableTodayLineWidth(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.layers,
                          title: '今日课程边线不透明度',
                          value: settings.timetableTodayLineOpacity,
                          defaultValue:
                              const AppSettings().timetableTodayLineOpacity,
                          min: 0,
                          max: 1,
                          suffix: '%',
                          displayMultiplier: 100,
                          displayDecimals: 0,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableTodayLineOpacity(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.alignJustify,
                          title: '今日课程横线标注',
                          value: settings.showTodayHorizontalGridLines,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setShowTodayHorizontalGridLines(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.clock,
                          title: '显示当前时间线',
                          value: settings.showCurrentTimeLine,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setShowCurrentTimeLine(value),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const ProfileSettingsHint(
                      '开启后，今日将要或正在上的课：左侧时间列对应节次以今日颜色标注，'
                      '并在该课上下边界绘制贯通整行的横线（颜色与粗细跟随今日课程边线设置）。',
                    ),
                  ]),
                ),
                FTabEntry(
                  label: const Text('课程块'),
                  child: _tabList([
                    _buildTemplateEditor(settings),
                    const SizedBox(height: AppSpacing.xl),
                    ProfileSettingsGroup(
                      children: [
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.layers,
                          title: '课程字体不透明度',
                          value: settings.timetableCourseTextOpacity,
                          defaultValue:
                              const AppSettings().timetableCourseTextOpacity,
                          min: 0,
                          max: 1,
                          suffix: '%',
                          displayMultiplier: 100,
                          displayDecimals: 0,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCourseTextOpacity(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.cornerDownRight,
                          title: '课程块圆角',
                          value: settings.timetableCourseCornerRadius,
                          defaultValue:
                              const AppSettings().timetableCourseCornerRadius,
                          min: 0,
                          max: 24,
                          suffix: ' px',
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCourseCornerRadius(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.arrowDownUp,
                          title: '课程块内边距',
                          value: settings.timetableCourseInnerPadding,
                          defaultValue:
                              const AppSettings().timetableCourseInnerPadding,
                          min: 0,
                          max: 12,
                          suffix: ' px',
                          displayDecimals: 1,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCourseInnerPadding(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.move,
                          title: '课程块外边距',
                          value: settings.timetableCourseOuterPadding,
                          defaultValue:
                              const AppSettings().timetableCourseOuterPadding,
                          min: 0,
                          max: 8,
                          suffix: ' px',
                          displayDecimals: 1,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCourseOuterPadding(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.layers,
                          title: '课程块不透明度',
                          value: settings.timetableCourseAlpha,
                          defaultValue:
                              const AppSettings().timetableCourseAlpha,
                          min: 0.1,
                          max: 1,
                          suffix: '%',
                          displayMultiplier: 100,
                          displayDecimals: 0,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCourseAlpha(value),
                        ),
                        ProfileSettingsOptionsTile<TimetableBorderType>(
                          icon: FLucideIcons.squareDashed,
                          title: '课程块边框',
                          value: settings.timetableBorderType,
                          options: const [
                            ProfileSettingsOption(
                              value: TimetableBorderType.none,
                              label: '无边框',
                            ),
                            ProfileSettingsOption(
                              value: TimetableBorderType.solid,
                              label: '实线',
                            ),
                            ProfileSettingsOption(
                              value: TimetableBorderType.dashed,
                              label: '虚线',
                            ),
                          ],
                          onChanged: (value) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setTimetableBorderType(value),
                          ),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.squareDashed,
                          title: '虚线边框密度',
                          value: settings.timetableDashedBorderDensity,
                          defaultValue:
                              const AppSettings().timetableDashedBorderDensity,
                          min: 0.5,
                          max: 2,
                          suffix: 'x',
                          displayDecimals: 2,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableDashedBorderDensity(value),
                        ),
                        ProfileSettingsColorTile(
                          icon: FLucideIcons.square,
                          title: '课程块边框颜色',
                          value: settings.timetableCourseBorderColor,
                          colors: _styleColors,
                          lastCustomColor:
                              settings.timetableLastCustomCourseBorderColor,
                          onChanged: (color) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setTimetableCourseBorderColor(color),
                          ),
                          onCustomColorPressed: () => unawaited(
                            _selectCustomColor(
                              settings.timetableLastCustomCourseBorderColor ??
                                  settings.timetableCourseBorderColor ??
                                  context.theme.colors.foreground,
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setCustomTimetableCourseBorderColor,
                            ),
                          ),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.move,
                          title: '课程块边框线粗细',
                          value: settings.timetableCourseBorderWidth,
                          defaultValue:
                              const AppSettings().timetableCourseBorderWidth,
                          min: 0.5,
                          max: 3,
                          suffix: ' px',
                          displayDecimals: 1,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCourseBorderWidth(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.layers,
                          title: '课程块边框不透明度',
                          value: settings.timetableCourseBorderOpacity,
                          defaultValue:
                              const AppSettings().timetableCourseBorderOpacity,
                          min: 0,
                          max: 1,
                          suffix: '%',
                          displayMultiplier: 100,
                          displayDecimals: 0,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCourseBorderOpacity(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.timer,
                          title: '冲突倒计时长度',
                          value: settings.timetableCountdownBarLengthRatio,
                          defaultValue: const AppSettings()
                              .timetableCountdownBarLengthRatio,
                          min: 0.1,
                          max: 1,
                          suffix: '%',
                          displayMultiplier: 100,
                          displayDecimals: 0,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCountdownBarLengthRatio(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.minus,
                          title: '倒计时胶囊圆弧端点',
                          value: settings.timetableCountdownBarRounded,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCountdownBarRounded(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.alignVerticalSpaceAround,
                          title: '倒计时粗细',
                          value: settings.timetableCountdownBarThickness,
                          defaultValue: const AppSettings()
                              .timetableCountdownBarThickness,
                          min: 1,
                          max: 8,
                          suffix: ' px',
                          displayDecimals: 1,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCountdownBarThickness(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.arrowUpToLine,
                          title: '倒计时上边距',
                          value: settings.timetableCountdownBarTopPadding,
                          defaultValue: const AppSettings()
                              .timetableCountdownBarTopPadding,
                          min: 0,
                          max: 8,
                          suffix: ' px',
                          displayDecimals: 1,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCountdownBarTopPadding(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.arrowDownToLine,
                          title: '倒计时下边距',
                          value: settings.timetableCountdownBarBottomPadding,
                          defaultValue: const AppSettings()
                              .timetableCountdownBarBottomPadding,
                          min: 0,
                          max: 8,
                          suffix: ' px',
                          displayDecimals: 1,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableCountdownBarBottomPadding(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.alignCenterHorizontal,
                          title: '课程文字水平居中',
                          value: settings.timetableTextAlignCenterHorizontal,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableTextAlignCenterHorizontal(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.alignCenterVertical,
                          title: '课程文字垂直居中',
                          value: settings.timetableTextAlignCenterVertical,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableTextAlignCenterVertical(value),
                        ),
                      ],
                    ),
                  ]),
                ),
                FTabEntry(
                  label: const Text('页面与文字'),
                  child: _tabList([
                    ProfileSettingsGroup(
                      children: [
                        ProfileSettingsColorTile(
                          icon: FLucideIcons.type,
                          title: '页面文字颜色',
                          value: settings.timetablePageTextFor(brightness),
                          colors: [
                            for (final color in AppThemeColor.values)
                              color.resolve(brightness),
                          ],
                          lastCustomColor:
                              settings.timetableLastCustomPageTextColor,
                          onChanged: (color) {
                            final selected = color == null
                                ? null
                                : AppThemeColor.values.firstWhere(
                                    (item) =>
                                        item.resolve(brightness).toARGB32() ==
                                        color.toARGB32(),
                                  );
                            unawaited(
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setTimetablePageTextColor(
                                    selected?.lightColor,
                                  ),
                            );
                          },
                          onCustomColorPressed: () => unawaited(
                            _selectCustomColor(
                              settings.timetableLastCustomPageTextColor ??
                                  settings.timetablePageTextFor(brightness) ??
                                  context.theme.colors.foreground,
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setCustomTimetablePageTextColor,
                            ),
                          ),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.layers,
                          title: '页面文字不透明度',
                          value: settings.timetablePageTextOpacity,
                          defaultValue:
                              const AppSettings().timetablePageTextOpacity,
                          min: 0,
                          max: 1,
                          suffix: '%',
                          displayMultiplier: 100,
                          displayDecimals: 0,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetablePageTextOpacity(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.clock3,
                          title: '隐藏节次时间',
                          value: settings.timetableHideSectionTime,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableHideSectionTime(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.calendarDays,
                          title: '隐藏日期',
                          value: settings.timetableHideDateUnderDay,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableHideDateUnderDay(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.palette,
                          title: '显示课程改动颜色标识',
                          value: settings.timetableDayColorMarkers,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableDayColorMarkers(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.type,
                          title: '显示课程改动文字标识',
                          value: settings.timetableDayTextMarkers,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableDayTextMarkers(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.type,
                          title: '课程改动文字大小',
                          value: settings.timetableDayTextMarkerSize,
                          defaultValue:
                              const AppSettings().timetableDayTextMarkerSize,
                          min: 4,
                          max: 16,
                          suffix: ' px',
                          displayDecimals: 1,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableDayTextMarkerSize(value),
                        ),
                        ProfileSettingsOptionsTile<TimetableDayMarkerPosition>(
                          icon: FLucideIcons.move,
                          title: '课程改动文字位置',
                          value: settings.timetableDayTextMarkerPosition,
                          options: const [
                            ProfileSettingsOption(
                              value: TimetableDayMarkerPosition.topRight,
                              label: '右上',
                            ),
                            ProfileSettingsOption(
                              value: TimetableDayMarkerPosition.bottomRight,
                              label: '右下',
                            ),
                            ProfileSettingsOption(
                              value: TimetableDayMarkerPosition.topLeft,
                              label: '左上',
                            ),
                            ProfileSettingsOption(
                              value: TimetableDayMarkerPosition.bottomLeft,
                              label: '左下',
                            ),
                          ],
                          onChanged: (value) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setTimetableDayTextMarkerPosition(value),
                          ),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.shrink,
                          title: '课程改动文字内间距',
                          value: settings.timetableDayTextMarkerPadding,
                          defaultValue:
                              const AppSettings().timetableDayTextMarkerPadding,
                          min: 0,
                          max: 8,
                          suffix: ' px',
                          displayDecimals: 1,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setTimetableDayTextMarkerPadding(value),
                        ),
                      ],
                    ),
                  ]),
                ),
                FTabEntry(
                  label: const Text('小组件'),
                  child: _tabList([
                    ProfileSettingsGroup(
                      children: [
                        ProfileSettingsOptionsTile<WidgetThemePreference>(
                          icon: FLucideIcons.sunMoon,
                          title: '小组件主题',
                          value: settings.widgetThemePreference,
                          options: const [
                            ProfileSettingsOption(
                              value: WidgetThemePreference.system,
                              label: '跟随系统',
                            ),
                            ProfileSettingsOption(
                              value: WidgetThemePreference.light,
                              label: '浅色',
                            ),
                            ProfileSettingsOption(
                              value: WidgetThemePreference.dark,
                              label: '深色',
                            ),
                          ],
                          onChanged: (value) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setWidgetThemePreference(value),
                          ),
                        ),
                        ProfileSettingsColorTile(
                          icon: FLucideIcons.paintBucket,
                          title: '小组件背景色',
                          value: settings.widgetBackgroundColor,
                          colors: _widgetBackgroundColors,
                          lastCustomColor:
                              settings.lastCustomWidgetBackgroundColor,
                          onChanged: (color) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setWidgetBackgroundColor(color),
                          ),
                          onCustomColorPressed: () => unawaited(
                            _selectCustomColor(
                              settings.lastCustomWidgetBackgroundColor ??
                                  settings.widgetBackgroundColor ??
                                  context.theme.colors.background,
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setCustomWidgetBackgroundColor,
                            ),
                          ),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.sunMedium,
                          title: '暗色模式沿用浅色背景图',
                          value: settings.widgetUseLightBackgroundInDarkMode,
                          onChange: (value) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setWidgetUseLightBackgroundInDarkMode(value),
                          ),
                        ),
                        ProfileSettingsTile(
                          icon: FLucideIcons.sun,
                          title: '浅色背景图',
                          value: settings.widgetBackgroundPath == null
                              ? '点击选择'
                              : '长按删除',
                          onTap: settings.widgetBackgroundPath == null
                              ? () => _pickBackgroundAfterLongPress(
                                  dark: false,
                                  forWidget: true,
                                )
                              : null,
                          onLongPress: settings.widgetBackgroundPath == null
                              ? null
                              : () => _clearBackground(
                                  dark: false,
                                  forWidget: true,
                                ),
                          onPointerUp: _releaseBackgroundPointer,
                        ),
                        ProfileSettingsTile(
                          icon: FLucideIcons.moon,
                          title: '暗色背景图',
                          value: settings.widgetDarkBackgroundPath == null
                              ? '点击选择'
                              : '长按删除',
                          onTap: settings.widgetDarkBackgroundPath == null
                              ? () => _pickBackgroundAfterLongPress(
                                  dark: true,
                                  forWidget: true,
                                )
                              : null,
                          onLongPress: settings.widgetDarkBackgroundPath == null
                              ? null
                              : () => _clearBackground(
                                  dark: true,
                                  forWidget: true,
                                ),
                          onPointerUp: _releaseBackgroundPointer,
                        ),
                        ProfileSettingsColorTile(
                          icon: FLucideIcons.type,
                          title: '小组件文字颜色',
                          value: settings.widgetTextColor,
                          colors: _styleColors,
                          lastCustomColor: settings.lastCustomWidgetTextColor,
                          onChanged: (color) => unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setWidgetTextColor(color),
                          ),
                          onCustomColorPressed: () => unawaited(
                            _selectCustomColor(
                              settings.lastCustomWidgetTextColor ??
                                  settings.widgetTextColor ??
                                  context.theme.colors.foreground,
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setCustomWidgetTextColor,
                            ),
                          ),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.type,
                          title: '小组件字体缩放',
                          value: settings.widgetFontScale,
                          defaultValue: const AppSettings().widgetFontScale,
                          min: 0.5,
                          max: 2.0,
                          suffix: 'x',
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setWidgetFontScale(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.layers,
                          title: '小组件文字不透明度',
                          value: settings.widgetTextOpacity,
                          defaultValue: const AppSettings().widgetTextOpacity,
                          min: 0,
                          max: 1,
                          suffix: '%',
                          displayMultiplier: 100,
                          displayDecimals: 0,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setWidgetTextOpacity(value),
                        ),
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.layers,
                          title: '小组件背景不透明度',
                          value: settings.widgetBackgroundAlpha,
                          defaultValue:
                              const AppSettings().widgetBackgroundAlpha,
                          min: 0,
                          max: 1,
                          suffix: '%',
                          displayMultiplier: 100,
                          displayDecimals: 0,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setWidgetBackgroundAlpha(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.calendarDays,
                          title: '隐藏小组件日期',
                          value: settings.widgetHideDate,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setWidgetHideDate(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.mapPinOff,
                          title: '隐藏小组件地点',
                          value: settings.widgetHideLocation,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setWidgetHideLocation(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.userRoundX,
                          title: '隐藏小组件教师',
                          value: settings.widgetHideTeacher,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setWidgetHideTeacher(value),
                        ),
                      ],
                    ),
                  ]),
                ),
                FTabEntry(
                  label: const Text('其他'),
                  child: _tabList([
                    ProfileSettingsGroup(
                      children: [
                        ProfileSettingsSliderTile(
                          icon: FLucideIcons.layers,
                          title: 'Toast 不透明度',
                          value: settings.toastOpacity,
                          defaultValue: const AppSettings().toastOpacity,
                          min: 0,
                          max: 1,
                          suffix: '%',
                          displayMultiplier: 100,
                          displayDecimals: 0,
                          onChanged: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setToastOpacity(value),
                        ),
                        ProfileSettingsCheckboxTile(
                          icon: FLucideIcons.text,
                          title: '不受系统文字缩放影响',
                          value: settings.ignoreSystemTextScale,
                          onChange: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setIgnoreSystemTextScale(value),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const ProfileSettingsHint(
                      '开启后，未单独设置字号的文字不随系统字体大小缩放；'
                      '课表课程块、课程改动标记等已有独立字号设置的文字不受影响。',
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 每个分类大项独立一页，可左右滑动；预览固定在上方（需求 10）。
  Widget _tabList(List<Widget> children) => AppPageListView(
    maxWidth: AppLayout.resultMaxWidth,
    topPadding: AppSpacing.md,
    bottomPadding: AppSpacing.xxl,
    safeArea: false,
    children: children,
  );

  Future<void> _selectCustomColor(
    Color initialColor,
    Future<void> Function(Color) onSelected,
  ) async {
    final selected = await showProfileColorPicker(
      context: context,
      initialColor: initialColor,
    );
    if (selected != null) await onSelected(selected);
  }

  Future<void> _pickBackground({
    required bool dark,
    bool forWidget = false,
  }) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;
    try {
      final aspectRatio = forWidget
          ? 2.0
          : _backgroundAspectRatio(MediaQuery.sizeOf(context));
      final sourceBytes = await picked.readAsBytes();
      if (!mounted) return;
      final cropBytes = await _selectBackgroundCrop(sourceBytes, aspectRatio);
      if (cropBytes == null || !mounted) return;
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = p.join(
        directory.path,
        '${forWidget ? 'widget' : 'timetable'}_background_'
        '${dark ? 'dark' : 'light'}_$timestamp.jpg',
      );
      await File(targetPath).writeAsBytes(cropBytes);
      final settings = ref.read(appSettingsProvider);
      final oldPath = forWidget
          ? dark
                ? settings.widgetDarkBackgroundPath
                : settings.widgetBackgroundPath
          : dark
          ? settings.timetableDarkBackgroundPath
          : settings.timetableBackgroundPath;
      final notifier = ref.read(appSettingsProvider.notifier);
      if (forWidget) {
        if (dark) {
          await notifier.setWidgetDarkBackgroundPath(targetPath);
        } else {
          await notifier.setWidgetBackgroundPath(targetPath);
        }
      } else if (dark) {
        await notifier.setTimetableDarkBackgroundPath(targetPath);
      } else {
        await notifier.setTimetableBackgroundPath(targetPath);
      }
      if (oldPath != null && oldPath != targetPath) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      }
      if (mounted) {
        showAppSnackBar(context, '背景图已更新', severity: ToastSeverity.success);
      }
    } catch (error, stackTrace) {
      talker.error('保存${forWidget ? '小组件' : '课表'}背景图失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '背景图保存失败', severity: ToastSeverity.error);
      }
    }
  }

  void _pickBackgroundAfterLongPress({
    required bool dark,
    bool forWidget = false,
  }) {
    if (_ignoreNextBackgroundTap) {
      _ignoreNextBackgroundTap = false;
      return;
    }
    unawaited(_pickBackground(dark: dark, forWidget: forWidget));
  }

  void _releaseBackgroundPointer() {
    if (!_ignoreNextBackgroundTap) return;
    // Let the current gesture finish before allowing a newly rebuilt tile to
    // respond to a later tap.
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _ignoreNextBackgroundTap = false);
    });
  }

  Future<Uint8List?> _selectBackgroundCrop(
    Uint8List sourceBytes,
    double aspectRatio,
  ) => Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      builder: (_) => _BackgroundCropPage(
        sourceBytes: sourceBytes,
        aspectRatio: aspectRatio,
      ),
    ),
  );

  Future<void> _clearBackground({
    required bool dark,
    bool forWidget = false,
  }) async {
    // The long-press callback runs while the finger is still down. Consume
    // the release that follows the deletion so it cannot reopen the picker.
    _ignoreNextBackgroundTap = true;
    final settings = ref.read(appSettingsProvider);
    final path = forWidget
        ? dark
              ? settings.widgetDarkBackgroundPath
              : settings.widgetBackgroundPath
        : dark
        ? settings.timetableDarkBackgroundPath
        : settings.timetableBackgroundPath;
    final notifier = ref.read(appSettingsProvider.notifier);
    if (forWidget) {
      if (dark) {
        await notifier.setWidgetDarkBackgroundPath(null);
      } else {
        await notifier.setWidgetBackgroundPath(null);
      }
    } else if (dark) {
      await notifier.setTimetableDarkBackgroundPath(null);
    } else {
      await notifier.setTimetableBackgroundPath(null);
    }
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (error, stackTrace) {
          talker.warning('删除背景图文件失败', error, stackTrace);
        }
      }
    }
    if (mounted) {
      showAppSnackBar(context, '背景图已清除', severity: ToastSeverity.success);
    }
  }

  Future<void> _resetAppearance() async {
    if (!mounted) return;

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '清空个性化设置',
      message: '将把所有个性化设置恢复为默认值，确定继续吗？',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final settings = ref.read(appSettingsProvider);
    final backgroundPaths = {
      settings.timetableBackgroundPath,
      settings.timetableDarkBackgroundPath,
      settings.widgetBackgroundPath,
      settings.widgetDarkBackgroundPath,
    }.whereType<String>().where((path) => path.isNotEmpty);
    await ref.read(appSettingsProvider.notifier).resetTimetableAppearance();
    for (final backgroundPath in backgroundPaths) {
      final file = File(backgroundPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (error, stackTrace) {
          talker.warning('删除背景图文件失败', error, stackTrace);
        }
      }
    }
    if (mounted) {
      showAppSnackBar(context, '个性化设置已重置', severity: ToastSeverity.success);
    }
  }
}

class _TimetableGridPreview extends StatelessWidget {
  final AppSettings settings;
  final List<Course> courses;
  final bool showWeekendColumns;

  const _TimetableGridPreview({
    required this.settings,
    required this.courses,
    required this.showWeekendColumns,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final backgroundPath = settings.timetableBackgroundFor(
      Theme.of(context).brightness,
    );
    final currentWeek = semesterCalendar
        .weekOf(DateTime.now())
        .clamp(1, math.max(1, semesterCalendar.totalWeeks))
        .toInt();
    // 预览取本周实际课程；本周无课时回退到内置测试课表（不额外提醒）。
    final weekCourses = courses
        .where((course) => course.isInWeek(currentWeek))
        .toList();
    final previewCourses = weekCourses.isEmpty
        ? _previewSampleCourses(currentWeek)
        : weekCourses;
    final previewDates = semesterCalendar.weekDates(currentWeek);
    final previewDayIndex = DateTime.now().weekday
        .clamp(1, showWeekendColumns ? 7 : 5)
        .toInt();
    final previewCurrentDate = previewDates[previewDayIndex - 1];
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundPath != null && backgroundPath.isNotEmpty)
            Image.file(
              File(backgroundPath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: theme.colors.background),
            )
          else
            ColoredBox(color: theme.colors.background),
          TimetableGrid(
            courses: previewCourses,
            week: currentWeek,
            showWeekendColumns: showWeekendColumns,
            currentDate: previewCurrentDate,
            calendar: semesterCalendar,
            slotCount: 14,
            visibleSlots: 2,
            borderColor: theme.colors.foreground,
            courseBorderColor: settings.timetableCourseBorderColor,
            borderWidth: settings.timetableCourseBorderWidth,
            courseOpacity: settings.timetableCourseAlpha,
            courseBorderOpacity: settings.timetableCourseBorderOpacity,
            courseTextSize: settings.timetableCourseTextSize,
            timeTextSize: settings.timetableTimeTextSize,
            dateTextSize: settings.timetableDateTextSize,
            dayTextMarkerSize: settings.timetableDayTextMarkerSize,
            gridOpacity: settings.timetableGridOpacity,
            gridLineColor: settings.timetableGridLineColor,
            gridLineWidth: settings.timetableGridLineWidth,
            showHeaderDivider: backgroundPath == null || backgroundPath.isEmpty,
            showTodayGridLines: settings.showTodayGridLines,
            todayLineColor: settings.timetableTodayLineColor,
            todayLineWidth: settings.timetableTodayLineWidth,
            todayLineOpacity: settings.timetableTodayLineOpacity,
            showTodayHorizontalGridLines: settings.showTodayHorizontalGridLines,
            showGridLines: settings.showTimetableGridLines,
            showBelowFoldIndicator: false,
            suppressDayDrop: true,
            sectionHeight: settings.timetableSectionHeight,
            timeColumnWidth: settings.timetableTimeColumnWidth,
            dayHeaderHeight: settings.timetableDayHeaderHeight,
            courseCornerRadius: settings.timetableCourseCornerRadius,
            courseInnerPadding: settings.timetableCourseInnerPadding,
            courseOuterPadding: settings.timetableCourseOuterPadding,
            courseTextTemplate: settings.timetableCourseTextTemplate,
            countdownBarLengthRatio: settings.timetableCountdownBarLengthRatio,
            countdownBarRounded: settings.timetableCountdownBarRounded,
            countdownBarThickness: settings.timetableCountdownBarThickness,
            countdownBarTopPadding: settings.timetableCountdownBarTopPadding,
            countdownBarBottomPadding:
                settings.timetableCountdownBarBottomPadding,
            showCurrentTimeLine: settings.showCurrentTimeLine,
            dashedBorderDensity: settings.timetableDashedBorderDensity,
            hideSectionTime: settings.timetableHideSectionTime,
            hideDateUnderDay: settings.timetableHideDateUnderDay,
            showDayColorMarkers: settings.timetableDayColorMarkers,
            showDayTextMarkers: settings.timetableDayTextMarkers,
            dayTextMarkerPosition: settings.timetableDayTextMarkerPosition,
            dayTextMarkerPadding: settings.timetableDayTextMarkerPadding,
            textAlignCenterHorizontal:
                settings.timetableTextAlignCenterHorizontal,
            textAlignCenterVertical: settings.timetableTextAlignCenterVertical,
            borderType: settings.timetableBorderType.storageValue,
            pageTextColor: settings.timetablePageTextFor(
              Theme.of(context).brightness,
            ),
            pageTextOpacity: settings.timetablePageTextOpacity,
            courseTextOpacity: settings.timetableCourseTextOpacity,
          ),
        ],
      ),
    );
  }
}

/// 预览在本周没有实际课程时使用的内置测试课表。
List<Course> _previewSampleCourses(int week) => [
  Course(
    title: '高等数学',
    teacher: '张老师',
    weekday: 1,
    sessions: const [1, 2],
    weeks: [week],
    campus: '',
    place: '教1-101',
    colorIndex: 0,
  ),
  Course(
    title: '大学英语',
    teacher: '李老师',
    weekday: 2,
    sessions: const [2],
    weeks: [week],
    campus: '',
    place: '教2-203',
    colorIndex: 1,
  ),
  Course(
    title: '程序设计',
    teacher: '王老师',
    weekday: 3,
    sessions: const [1, 2],
    weeks: [week],
    campus: '',
    place: '机房 A305',
    colorIndex: 2,
  ),
  Course(
    title: '线性代数',
    teacher: '赵老师',
    weekday: 4,
    sessions: const [1],
    weeks: [week],
    campus: '',
    place: '教1-208',
    colorIndex: 3,
  ),
  Course(
    title: '大学物理',
    teacher: '陈老师',
    weekday: 5,
    sessions: const [2],
    weeks: [week],
    campus: '',
    place: '教3-110',
    colorIndex: 4,
  ),
];

Future<ui.Image> _decodeCropPreview(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    const maxDimension = 1800.0;
    final scale = math.min(
      1.0,
      maxDimension / math.max(descriptor.width, descriptor.height),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round().clamp(1, 1800),
      targetHeight: (descriptor.height * scale).round().clamp(1, 1800),
    );
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

class _BackgroundCropPage extends StatefulWidget {
  final Uint8List sourceBytes;
  final double aspectRatio;

  const _BackgroundCropPage({
    required this.sourceBytes,
    required this.aspectRatio,
  });

  @override
  State<_BackgroundCropPage> createState() => _BackgroundCropPageState();
}

class _BackgroundCropPageState extends State<_BackgroundCropPage> {
  ui.Image? _source;
  Object? _loadError;
  bool _isCropping = false;
  Rect? _selectionRect;
  Rect? _gestureStartSelection;
  _BackgroundCropMetrics? _lastMetrics;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSource());
  }

  Future<void> _loadSource() async {
    try {
      // Decode with Flutter's native codec and cap the working image. The
      // old path decoded and JPEG-reencoded the full photo in pure Dart before
      // the crop page could render anything.
      final source = await _decodeCropPreview(widget.sourceBytes);
      if (!mounted) {
        source.dispose();
        return;
      }
      setState(() {
        _source = source;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    _source?.dispose();
    super.dispose();
  }

  _BackgroundCropMetrics _metrics(Size canvasSize) {
    final source = _source!;
    final aspectRatio = widget.aspectRatio.isFinite && widget.aspectRatio > 0
        ? widget.aspectRatio
        : 1.0;
    final imageScale = math.max(
      canvasSize.width / source.width,
      canvasSize.height / source.height,
    );
    final imageRect = Rect.fromCenter(
      center: canvasSize.center(Offset.zero),
      width: source.width * imageScale,
      height: source.height * imageScale,
    );
    final selectionBounds = imageRect.intersect(Offset.zero & canvasSize);
    final maxWidth = math.min(
      selectionBounds.width,
      selectionBounds.height * aspectRatio,
    );
    final defaultWidth = maxWidth * 0.86;
    final defaultHeight = defaultWidth / aspectRatio;
    final defaultRect = Rect.fromCenter(
      center: selectionBounds.center,
      width: defaultWidth,
      height: defaultHeight,
    );
    return _BackgroundCropMetrics(
      imageRect: imageRect,
      selectionBounds: selectionBounds,
      sourceScale: imageScale,
      defaultCropRect: defaultRect,
    );
  }

  Rect _clampSelection(Rect rect, _BackgroundCropMetrics metrics) {
    final aspectRatio = widget.aspectRatio.isFinite && widget.aspectRatio > 0
        ? widget.aspectRatio
        : 1.0;
    final maxWidth = math.min(
      metrics.selectionBounds.width,
      metrics.selectionBounds.height * aspectRatio,
    );
    final minWidth = math.min(72.0, maxWidth);
    final width = rect.width.clamp(minWidth, maxWidth).toDouble();
    final height = width / aspectRatio;
    final center = Offset(
      rect.center.dx.clamp(
        metrics.selectionBounds.left + width / 2,
        metrics.selectionBounds.right - width / 2,
      ),
      rect.center.dy.clamp(
        metrics.selectionBounds.top + height / 2,
        metrics.selectionBounds.bottom - height / 2,
      ),
    );
    return Rect.fromCenter(center: center, width: width, height: height);
  }

  Future<Uint8List> _crop(_BackgroundCropMetrics metrics) async {
    final source = _source!;
    final cropRect = _selectionRect ?? metrics.defaultCropRect;
    final x = ((cropRect.left - metrics.imageRect.left) / metrics.sourceScale)
        .round()
        .clamp(0, source.width - 1)
        .toInt();
    final y = ((cropRect.top - metrics.imageRect.top) / metrics.sourceScale)
        .round()
        .clamp(0, source.height - 1)
        .toInt();
    final width = (cropRect.width / metrics.sourceScale)
        .round()
        .clamp(1, source.width - x)
        .toInt();
    final height = (cropRect.height / metrics.sourceScale)
        .round()
        .clamp(1, source.height - y)
        .toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(
        x.toDouble(),
        y.toDouble(),
        width.toDouble(),
        height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(width, height);
    picture.dispose();
    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    croppedImage.dispose();
    if (byteData == null) throw const FormatException('无法读取图片像素');
    final rgba = TransferableTypedData.fromList([
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    ]);
    return Isolate.run(() {
      final pixels = rgba.materialize();
      final decoded = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: pixels,
        numChannels: 4,
      );
      return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
    });
  }

  Future<void> _confirmCrop(_BackgroundCropMetrics metrics) async {
    if (_isCropping || _source == null) return;
    setState(() => _isCropping = true);
    try {
      final bytes = await _crop(metrics);
      if (mounted) Navigator.pop(context, bytes);
    } catch (error) {
      if (mounted) {
        setState(() => _isCropping = false);
        showAppSnackBar(context, '图片裁剪失败', severity: ToastSeverity.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AppPage(
      title: '调整背景图',
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppSpacing.sm,
            0,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final source = _source;
                    if (source == null) {
                      return Center(
                        child: _loadError == null
                            ? const CircularProgressIndicator()
                            : Text('图片读取失败', style: theme.typography.bodySmall),
                      );
                    }
                    final canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final metrics = _metrics(canvasSize);
                    final selection = _clampSelection(
                      _selectionRect ?? metrics.defaultCropRect,
                      metrics,
                    );
                    _selectionRect = selection;
                    _lastMetrics = metrics;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) {
                        _gestureStartSelection = selection;
                      },
                      onScaleUpdate: (details) {
                        final start = _gestureStartSelection ?? selection;
                        final current = _selectionRect ?? start;
                        final isPinching = details.pointerCount > 1;
                        final aspectRatio =
                            widget.aspectRatio.isFinite &&
                                widget.aspectRatio > 0
                            ? widget.aspectRatio
                            : 1.0;
                        final width = isPinching
                            ? start.width * details.scale
                            : start.width;
                        final moved = Rect.fromCenter(
                          center: current.center + details.focalPointDelta,
                          width: width,
                          height: width / aspectRatio,
                        );
                        setState(() {
                          _selectionRect = _clampSelection(moved, metrics);
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: theme.colors.muted),
                          Positioned.fromRect(
                            rect: metrics.imageRect,
                            child: RawImage(
                              image: source,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _CropOverlayPainter(selection),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FButton(
                    variant: FButtonVariant.ghost,
                    onPress: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FButton(
                    variant: FButtonVariant.ghost,
                    onPress: _isCropping
                        ? null
                        : () {
                            final metrics = _lastMetrics;
                            if (metrics != null && _source != null) {
                              unawaited(_confirmCrop(metrics));
                            }
                          },
                    child: _isCropping
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('使用此位置'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundCropMetrics {
  final Rect imageRect;
  final Rect selectionBounds;
  final double sourceScale;
  final Rect defaultCropRect;

  const _BackgroundCropMetrics({
    required this.imageRect,
    required this.selectionBounds,
    required this.sourceScale,
    required this.defaultCropRect,
  });
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  const _CropOverlayPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = const Color(0x99000000);
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), shade)
      ..drawRect(
        Rect.fromLTWH(
          0,
          cropRect.bottom,
          size.width,
          size.height - cropRect.bottom,
        ),
        shade,
      )
      ..drawRect(
        Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height),
        shade,
      )
      ..drawRect(
        Rect.fromLTWH(
          cropRect.right,
          cropRect.top,
          size.width - cropRect.right,
          cropRect.height,
        ),
        shade,
      );

    final border = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, border);

    final guide = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 0.7;
    for (var i = 1; i < 3; i++) {
      final dx = cropRect.left + cropRect.width * i / 3;
      final dy = cropRect.top + cropRect.height * i / 3;
      canvas
        ..drawLine(Offset(dx, cropRect.top), Offset(dx, cropRect.bottom), guide)
        ..drawLine(
          Offset(cropRect.left, dy),
          Offset(cropRect.right, dy),
          guide,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}
