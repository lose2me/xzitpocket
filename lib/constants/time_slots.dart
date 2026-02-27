class TimeSlot {
  final int index;
  final String start;
  final String end;

  const TimeSlot({required this.index, required this.start, required this.end});

  String get label => '$start\n$end';
}

const List<TimeSlot> kTimeSlots = [
  TimeSlot(index: 1, start: '08:00', end: '08:45'),
  TimeSlot(index: 2, start: '08:55', end: '09:40'),
  TimeSlot(index: 3, start: '10:00', end: '10:45'),
  TimeSlot(index: 4, start: '10:55', end: '11:40'),
  TimeSlot(index: 5, start: '14:00', end: '14:45'),
  TimeSlot(index: 6, start: '14:55', end: '15:40'),
  TimeSlot(index: 7, start: '16:00', end: '16:45'),
  TimeSlot(index: 8, start: '16:55', end: '17:40'),
  TimeSlot(index: 9, start: '19:00', end: '19:45'),
  TimeSlot(index: 10, start: '19:55', end: '20:40'),
  TimeSlot(index: 11, start: '20:50', end: '21:35'),
  TimeSlot(index: 12, start: '21:45', end: '22:30'),
  TimeSlot(index: 13, start: '22:40', end: '23:25'),
  TimeSlot(index: 14, start: '23:35', end: '00:20'),
];
