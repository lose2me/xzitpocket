class TimeSlot {
  final int index;
  final String start;
  final String end;

  const TimeSlot({required this.index, required this.start, required this.end});
}

const List<TimeSlot> kTimeSlots = [
  TimeSlot(index: 1, start: '08:00', end: '08:45'),
  TimeSlot(index: 2, start: '08:55', end: '09:40'),
  TimeSlot(index: 3, start: '10:05', end: '10:50'),
  TimeSlot(index: 4, start: '11:00', end: '11:45'),
  TimeSlot(index: 5, start: '12:00', end: '12:45'),
  TimeSlot(index: 6, start: '12:55', end: '13:40'),
  TimeSlot(index: 7, start: '14:00', end: '14:45'),
  TimeSlot(index: 8, start: '14:55', end: '15:40'),
  TimeSlot(index: 9, start: '16:05', end: '16:50'),
  TimeSlot(index: 10, start: '17:00', end: '17:45'),
  TimeSlot(index: 11, start: '17:55', end: '18:40'),
  TimeSlot(index: 12, start: '18:45', end: '19:30'),
  TimeSlot(index: 13, start: '19:40', end: '20:25'),
  TimeSlot(index: 14, start: '20:35', end: '21:20'),
];
