import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course.dart';
import 'config_provider.dart';

const defaultSecondaryScheduleTitle = '正在预览备用课程';

class SecondaryScheduleState {
  final List<Course> courses;
  final bool active;
  final bool imported;
  final String title;

  const SecondaryScheduleState({
    this.courses = const [],
    this.active = false,
    this.imported = false,
    this.title = defaultSecondaryScheduleTitle,
  });

  bool get hasSchedule => imported || courses.isNotEmpty;

  SecondaryScheduleState copyWith({
    List<Course>? courses,
    bool? active,
    bool? imported,
    String? title,
  }) => SecondaryScheduleState(
    courses: courses ?? this.courses,
    active: active ?? this.active,
    imported: imported ?? this.imported,
    title: title ?? this.title,
  );
}

final secondaryScheduleProvider =
    NotifierProvider<SecondaryScheduleNotifier, SecondaryScheduleState>(
      SecondaryScheduleNotifier.new,
    );

class SecondaryScheduleNotifier extends Notifier<SecondaryScheduleState> {
  @override
  SecondaryScheduleState build() {
    final title = ref
        .watch(preferencesStorageProvider)
        .getSecondaryScheduleTitle();
    final raw = ref
        .watch(preferencesStorageProvider)
        .getSecondaryScheduleJson();
    if (raw == null || raw.trim().isEmpty) {
      return SecondaryScheduleState(title: title);
    }
    try {
      final decoded = jsonDecode(raw);
      final list = decoded is Map ? decoded['courses'] : decoded;
      if (list is! List) return SecondaryScheduleState(title: title);
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
        title: title,
      );
    } catch (_) {
      // A damaged optional backup must never prevent the main timetable from
      // starting. The next import simply replaces it.
      return SecondaryScheduleState(title: title);
    }
  }

  Future<void> setCourses(List<Course> courses) async {
    final normalized = List<Course>.unmodifiable(courses);
    final next = state.copyWith(courses: normalized);
    final imported = SecondaryScheduleState(
      courses: next.courses,
      imported: true,
      title: next.title,
    );
    await _save(imported);
    state = imported;
  }

  Future<void> setTitle(String value) async {
    final title = value.trim().isEmpty
        ? defaultSecondaryScheduleTitle
        : value.trim();
    state = state.copyWith(title: title);
    await ref.read(preferencesStorageProvider).setSecondaryScheduleTitle(title);
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
    state = state.copyWith(courses: const [], active: false, imported: false);
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
