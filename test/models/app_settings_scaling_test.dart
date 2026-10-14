import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/app_settings.dart';

void main() {
  group('AppSettings.scaledForViewport (B1)', () {
    test('reference viewport keeps the stored values', () {
      const settings = AppSettings();
      final scaled = settings.scaledForViewport(kReferenceViewport);
      expect(scaled.timetableSectionHeight, 60.0);
      expect(scaled.timetableDayHeaderHeight, 40.0);
      expect(scaled.timetableTimeColumnWidth, 40.0);
      expect(scaled.timetableCourseTextSize, 12.0);
    });

    test('small and large viewports scale the proportional metrics', () {
      const settings = AppSettings();

      final small = settings.scaledForViewport(const Size(320, 568));
      expect(small.timetableSectionHeight, closeTo(60 * 0.85, 1e-9));
      expect(small.timetableTimeColumnWidth, closeTo(40 * 0.85, 1e-9));
      expect(small.timetableCourseTextSize, closeTo(12 * 0.85, 1e-9));

      final tablet = settings.scaledForViewport(const Size(800, 1280));
      expect(tablet.timetableSectionHeight, closeTo(60 * 1.3, 1e-9));
      expect(tablet.timetableTimeColumnWidth, closeTo(40 * 1.3, 1e-9));
      expect(tablet.timetableCourseTextSize, closeTo(12 * 1.3, 1e-9));
    });

    test('landscape uses separate horizontal, vertical and text scales', () {
      const settings = AppSettings();
      final landscape = settings.scaledForViewport(const Size(844, 390));
      // 横向 844/390→1.3；纵向 390/844→0.85；字号跟随较小维→0.85。
      expect(landscape.timetableTimeColumnWidth, closeTo(40 * 1.3, 1e-9));
      expect(landscape.timetableSectionHeight, closeTo(60 * 0.85, 1e-9));
      expect(landscape.timetableCourseTextSize, closeTo(12 * 0.85, 1e-9));
    });

    test('device-independent look stays absolute', () {
      const settings = AppSettings();
      final tablet = settings.scaledForViewport(const Size(800, 1280));
      expect(
        tablet.timetableCourseCornerRadius,
        settings.timetableCourseCornerRadius,
      );
      expect(tablet.timetableGridLineWidth, settings.timetableGridLineWidth);
      expect(tablet.timetableTodayLineWidth, settings.timetableTodayLineWidth);
      expect(
        tablet.timetableCourseBorderWidth,
        settings.timetableCourseBorderWidth,
      );
      expect(
        tablet.timetableDashedBorderDensity,
        settings.timetableDashedBorderDensity,
      );
      expect(tablet.timetableGridOpacity, settings.timetableGridOpacity);
      expect(
        tablet.timetableCourseBorderOpacity,
        settings.timetableCourseBorderOpacity,
      );
    });
  });
}
