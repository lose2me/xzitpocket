import 'package:flutter/services.dart';

/// Shortest-side breakpoint (logical px) used to tell phones from tablets.
const double kTabletShortestSide = 600;

bool shouldLockPortrait(Size logicalSize) =>
    logicalSize.shortestSide < kTabletShortestSide;

/// Phones are locked to portrait; tablets keep all four orientations.
Future<void> applyOrientationPolicy(Size logicalSize) {
  return SystemChrome.setPreferredOrientations(
    shouldLockPortrait(logicalSize)
        ? const [DeviceOrientation.portraitUp]
        : const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
  );
}
