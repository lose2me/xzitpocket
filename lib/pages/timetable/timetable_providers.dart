import 'package:flutter_riverpod/flutter_riverpod.dart';

class _SimpleNotifier<T> extends Notifier<T> {
  final T _initial;
  _SimpleNotifier(this._initial);

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

final selectedWeekProvider = NotifierProvider<_SimpleNotifier<int>, int>(
  () => _SimpleNotifier(1),
);

final showNonCurrentWeekCoursesProvider =
    NotifierProvider<_SimpleNotifier<bool>, bool>(() => _SimpleNotifier(false));

final showWeekendColumnsProvider =
    NotifierProvider<_SimpleNotifier<bool>, bool>(() => _SimpleNotifier(true));
