import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/course.dart';

void main() {
  group('Course', () {
    test('startSession returns minimum of sessions', () {
      final course = Course(
        title: 'Math',
        teacher: 'T',
        weekday: 1,
        sessions: [3, 1, 2],
        weeks: [1],
        campus: '',
        place: '',
        colorIndex: 0,
      );
      expect(course.startSession, 1);
    });

    test('endSession returns maximum of sessions', () {
      final course = Course(
        title: 'Math',
        teacher: 'T',
        weekday: 1,
        sessions: [3, 1, 2],
        weeks: [1],
        campus: '',
        place: '',
        colorIndex: 0,
      );
      expect(course.endSession, 3);
    });

    test('sessionSpan is correct', () {
      final course = Course(
        title: 'Math',
        teacher: 'T',
        weekday: 1,
        sessions: [3, 4, 5],
        weeks: [1],
        campus: '',
        place: '',
        colorIndex: 0,
      );
      expect(course.sessionSpan, 3);
    });

    test('empty sessions defaults to 1', () {
      final course = Course(
        title: 'Math',
        teacher: 'T',
        weekday: 1,
        sessions: [],
        weeks: [1],
        campus: '',
        place: '',
        colorIndex: 0,
      );
      expect(course.startSession, 1);
      expect(course.endSession, 1);
      expect(course.sessionSpan, 1);
    });

    test('isInWeek returns true for matching week', () {
      final course = Course(
        title: 'Math',
        teacher: 'T',
        weekday: 1,
        sessions: [1],
        weeks: [1, 3, 5],
        campus: '',
        place: '',
        colorIndex: 0,
      );
      expect(course.isInWeek(3), true);
      expect(course.isInWeek(2), false);
    });

    test('color returns palette color for valid index', () {
      final course = Course(
        title: 'Math',
        teacher: 'T',
        weekday: 1,
        sessions: [1],
        weeks: [1],
        campus: '',
        place: '',
        colorIndex: 0,
      );
      expect(course.color, Course.colors[0]);
    });

    test('color returns raw ARGB for out-of-palette index', () {
      const rawColor = 0xFFFF0000;
      final course = Course(
        title: 'Math',
        teacher: 'T',
        weekday: 1,
        sessions: [1],
        weeks: [1],
        campus: '',
        place: '',
        colorIndex: rawColor,
      );
      expect(course.color, const Color(rawColor));
    });

    test('copyWith creates modified copy', () {
      final original = Course(
        title: 'Math',
        teacher: 'T1',
        weekday: 1,
        sessions: [1, 2],
        weeks: [1],
        campus: 'A',
        place: 'R101',
        colorIndex: 0,
        courseId: 'C001',
      );
      final copy = original.copyWith(title: 'Physics', teacher: 'T2');
      expect(copy.title, 'Physics');
      expect(copy.teacher, 'T2');
      expect(copy.weekday, 1);
      expect(copy.courseId, 'C001');
    });

    test('colors list has expected length', () {
      expect(Course.colors.length, 24);
    });
  });
}
