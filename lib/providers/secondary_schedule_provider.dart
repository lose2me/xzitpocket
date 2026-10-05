import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course.dart';
import 'config_provider.dart';

class SecondaryScheduleState {
  final List<Course> courses;
  final bool active;
  final bool imported;

  const SecondaryScheduleState({
    this.courses = const [],
    this.active = false,
    this.imported = false,
  });

  bool get hasSchedule => imported || courses.isNotEmpty;

  SecondaryScheduleState copyWith({List<Course>? courses, bool? active}) =>
      SecondaryScheduleState(
        courses: courses ?? this.courses,
        active: active ?? this.active,
        imported: imported,
      );
}

final secondaryScheduleProvider =
    NotifierProvider<SecondaryScheduleNotifier, SecondaryScheduleState>(
      SecondaryScheduleNotifier.new,
    );

class SecondaryScheduleNotifier extends Notifier<SecondaryScheduleState> {
  @override
  SecondaryScheduleState build() {
    final raw = ref
        .watch(preferencesStorageProvider)
        .getSecondaryScheduleJson();
    if (raw == null || raw.trim().isEmpty) {
      return const SecondaryScheduleState();
    }
    try {
      final decoded = jsonDecode(raw);
      final list = decoded is Map ? decoded['courses'] : decoded;
      if (list is! List) return const SecondaryScheduleState();
      final courses = [
        for (final item in list)
          if (item is Map)
            Course.fromJson(Map<String, dynamic>.from(item))
          else
            throw const FormatException('备用课表课程格式无效'),
      ];
      return SecondaryScheduleState(
        courses: List.unmodifiable(courses),
        imported: true,
      );
    } catch (_) {
      // A damaged optional backup must never prevent the main timetable from
      // starting. The next import simply replaces it.
      return const SecondaryScheduleState();
    }
  }

  Future<void> setCourses(List<Course> courses) async {
    final normalized = List<Course>.unmodifiable(courses);
    final next = SecondaryScheduleState(courses: normalized, imported: true);
    await _save(next);
    state = next;
  }

  Future<void> _save(SecondaryScheduleState schedule) {
    return ref
        .read(preferencesStorageProvider)
        .setSecondaryScheduleJson(
          jsonEncode({
            'version': 1,
            'courses': schedule.courses
                .map((course) => course.toJson())
                .toList(),
          }),
        );
  }

  Future<void> clear() async {
    await ref.read(preferencesStorageProvider).setSecondaryScheduleJson(null);
    state = const SecondaryScheduleState();
  }

  void toggle() {
    if (!state.hasSchedule) return;
    state = state.copyWith(active: !state.active);
  }

  void setActive(bool active) {
    if (!state.hasSchedule) return;
    state = state.copyWith(active: active);
  }
}
