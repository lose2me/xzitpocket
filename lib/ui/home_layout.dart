import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Keep compact-window safe areas equal in the home shell and its layout probe.
MediaQueryData normalizeHomeMediaQuery(MediaQueryData query) {
  if (query.size.height >= 520) return query;
  return query.copyWith(
    padding: query.padding.copyWith(
      top: query.padding.top.clamp(0.0, 24.0).toDouble(),
      bottom: query.padding.bottom.clamp(0.0, 24.0).toDouble(),
    ),
    viewPadding: query.viewPadding.copyWith(
      top: query.viewPadding.top.clamp(0.0, 24.0).toDouble(),
      bottom: query.viewPadding.bottom.clamp(0.0, 24.0).toDouble(),
    ),
  );
}

/// Used by HomePage and the settings layout probe so navigation geometry is
/// measured from the same widgets and theme rather than guessed constants.
FBottomNavigationBar buildHomeNavigationBar({
  Key? key,
  required bool showServices,
  required bool transparent,
  required int index,
  required ValueChanged<int> onChange,
}) => FBottomNavigationBar(
  key: key,
  style: transparent
      ? FBottomNavigationBarStyleDelta.delta(
          decoration: DecorationDelta.boxDelta(
            color: const Color(0x00000000),
            border: const Border.fromBorderSide(BorderSide.none),
          ),
          backgroundFilter: null,
          slideableItems: FVariantsValueDelta.delta([
            FVariantValueDeltaOperation.all(false),
          ]),
        )
      : FBottomNavigationBarStyleDelta.delta(
          decoration: DecorationDelta.boxDelta(
            border: const Border.fromBorderSide(BorderSide.none),
          ),
          slideableItems: FVariantsValueDelta.delta([
            FVariantValueDeltaOperation.all(false),
          ]),
        ),
  index: index,
  onChange: onChange,
  children: [
    const FBottomNavigationBarItem(
      icon: Icon(FLucideIcons.calendarDays),
      label: Text('课表'),
    ),
    if (showServices)
      const FBottomNavigationBarItem(
        icon: Icon(FLucideIcons.layoutGrid),
        label: Text('服务'),
      ),
    const FBottomNavigationBarItem(
      icon: Icon(FLucideIcons.userRound),
      label: Text('我的'),
    ),
  ],
);
