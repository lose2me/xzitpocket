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
      expect(scaled.timetableCourseTextSize, 11.4);
    });

    test('small and large viewports scale the proportional metrics', () {
      const settings = AppSettings();

      final small = settings.scaledForViewport(const Size(320, 568));
      expect(small.timetableSectionHeight, closeTo(60 * 0.85, 1e-9));
      expect(small.timetableTimeColumnWidth, closeTo(40 * 0.85, 1e-9));
      // Course-card metrics are scaled later from the real cell size.
      expect(small.timetableCourseTextSize, 11.4);

      final tablet = settings.scaledForViewport(const Size(800, 1280));
      expect(tablet.timetableSectionHeight, closeTo(60 * 1.3, 1e-9));
      expect(tablet.timetableTimeColumnWidth, closeTo(40 * 1.3, 1e-9));
      expect(tablet.timetableCourseTextSize, 11.4);
    });

    test('landscape uses separate horizontal, vertical and text scales', () {
      const settings = AppSettings();
      final landscape = settings.scaledForViewport(const Size(844, 390));
      // 横向 844/390→1.3；纵向 390/844→0.85；字号跟随较小维→0.85。
      expect(landscape.timetableTimeColumnWidth, closeTo(40 * 1.3, 1e-9));
      expect(landscape.timetableSectionHeight, closeTo(60 * 0.85, 1e-9));
      expect(landscape.timetableCourseTextSize, 11.4);
    });

    test('non-card metrics keep their expected scaling', () {
      const settings = AppSettings();
      final tablet = settings.scaledForViewport(const Size(800, 1280));
      expect(
        tablet.timetableCourseCornerRadius,
        settings.timetableCourseCornerRadius,
      );
      expect(tablet.timetableGridLineWidth, closeTo(0.5 * 1.3, 1e-9));
      expect(tablet.timetableTodayLineWidth, closeTo(1.5 * 1.3, 1e-9));
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

  group('timetableCellScale', () {
    test('reference cell keeps the stored metrics', () {
      expect(
        timetableCellScale(
          cellWidth: kReferenceCourseCellWidth,
          cellHeight: kReferenceCourseCellHeight,
        ),
        1.0,
      );
    });

    test('shrinks with narrow or short cells and clamps', () {
      expect(timetableCellScale(cellWidth: 51, cellHeight: 60), 0.8);
      expect(timetableCellScale(cellWidth: 500, cellHeight: 500), 1.4);
      expect(
        timetableCellScale(cellWidth: double.infinity, cellHeight: 60),
        1.0,
      );
    });
  });
}
