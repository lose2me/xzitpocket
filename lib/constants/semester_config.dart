import '../models/school_calendar.dart';

/// Compatibility alias for callers that need the actual semester start day.
/// The value is derived from the first entry in [semesterCalendar], so the
/// school calendar remains the single source of truth.
DateTime get semesterStartDate => semesterCalendar.semesterStartDate;
