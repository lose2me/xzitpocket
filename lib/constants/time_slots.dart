class TimeSlot {
  final int index;
  final String start;
  final String end;

  /// 实验时段（仅服务端标记）：该节次无课时默认隐藏，App 不显示任何标记。
  final bool lab;

  const TimeSlot({
    required this.index,
    required this.start,
    required this.end,
    this.lab = false,
  });

  @override
  bool operator ==(Object other) =>
      other is TimeSlot &&
      other.index == index &&
      other.start == start &&
      other.end == end &&
      other.lab == lab;

  @override
  int get hashCode => Object.hash(index, start, end, lab);
}

/// Built-in fallback periods (作息时间), used until xzitpocket-control provides
/// its own list and whenever the downloaded list is missing or malformed.
const List<TimeSlot> kDefaultTimeSlots = [
  TimeSlot(index: 1, start: '08:00', end: '08:45'),
  TimeSlot(index: 2, start: '08:55', end: '09:40'),
  TimeSlot(index: 3, start: '10:05', end: '10:50'),
  TimeSlot(index: 4, start: '11:00', end: '11:45'),
  TimeSlot(index: 5, start: '12:00', end: '12:45', lab: true),
  TimeSlot(index: 6, start: '12:55', end: '13:40', lab: true),
  TimeSlot(index: 7, start: '14:00', end: '14:45'),
  TimeSlot(index: 8, start: '14:55', end: '15:40'),
  TimeSlot(index: 9, start: '16:05', end: '16:50'),
  TimeSlot(index: 10, start: '17:00', end: '17:45'),
  TimeSlot(index: 11, start: '17:55', end: '18:40'),
  TimeSlot(index: 12, start: '18:45', end: '19:30'),
  TimeSlot(index: 13, start: '19:40', end: '20:25'),
  TimeSlot(index: 14, start: '20:35', end: '21:20'),
];

/// Active timetable periods. Replaced at runtime from the schedule served by
/// xzitpocket-control together with the school calendar.
List<TimeSlot> kTimeSlots = kDefaultTimeSlots;

final RegExp _timeSlotClock = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// Decodes one control period entry; returns null when it is malformed.
TimeSlot? timeSlotFromJson(Object? raw) {
  if (raw is! Map) return null;
  final index = raw['index'];
  final start = raw['start'];
  final end = raw['end'];
  if (index is! int || start is! String || end is! String) return null;
  if (!_timeSlotClock.hasMatch(start) || !_timeSlotClock.hasMatch(end)) {
    return null;
  }
  if (start.compareTo(end) >= 0) return null;
  final rawLab = raw['lab'];
  // Older cached payloads predate the lab flag; keep periods 5/6 marked so the
  // hide-when-empty behaviour survives a cache that has not been refetched.
  final lab = rawLab is bool ? rawLab : (index == 5 || index == 6);
  return TimeSlot(index: index, start: start, end: end, lab: lab);
}

Map<String, dynamic> timeSlotToJson(TimeSlot slot) => {
  'index': slot.index,
  'start': slot.start,
  'end': slot.end,
  'lab': slot.lab,
};

/// Decodes control's period list. Anything malformed, out of order, or empty
/// falls back to [kDefaultTimeSlots] so the timetable always renders.
List<TimeSlot> timeSlotsFromJson(Object? raw) {
  if (raw is! List || raw.isEmpty) return kDefaultTimeSlots;
  final slots = <TimeSlot>[];
  for (var i = 0; i < raw.length; i++) {
    final slot = timeSlotFromJson(raw[i]);
    if (slot == null || slot.index != i + 1) return kDefaultTimeSlots;
    slots.add(slot);
  }
  return slots;
}
