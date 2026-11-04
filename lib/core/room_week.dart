import 'format.dart';
import 'models.dart';

/// A room's week: its class meetings and the one-off room requests, laid out day by day, and what is happening now.
/// Nothing here talks to the database or the screen, so it is all tested on its own (`test/room_week_test.dart`).

// ------------------------------------------------------------------------------------------------ the school's clock

/// Minutes east of UTC for school time zones that never change for daylight saving. The phone has no time zone
/// database, so any other zone falls back to the phone's own clock.
const Map<String, int> _fixedOffsets = {
  'Asia/Manila': 8 * 60,
  'Asia/Singapore': 8 * 60,
  'Asia/Kuala_Lumpur': 8 * 60,
  'Asia/Hong_Kong': 8 * 60,
  'Asia/Taipei': 8 * 60,
  'Asia/Shanghai': 8 * 60,
  'Australia/Perth': 8 * 60,
  'Asia/Tokyo': 9 * 60,
  'Asia/Seoul': 9 * 60,
  'Asia/Bangkok': 7 * 60,
  'Asia/Jakarta': 7 * 60,
  'Asia/Ho_Chi_Minh': 7 * 60,
  'Asia/Kolkata': 5 * 60 + 30,
  'Asia/Dubai': 4 * 60,
  'UTC': 0,
  'Etc/UTC': 0,
};

/// The date and time on the clock at the school. It is kept in a UTC-flagged [DateTime] whose fields hold the school's
/// wall-clock reading, so reading `.hour` or `.weekday` gives the school's hour and weekday, whatever zone the phone is in.
class SchoolClock {
  const SchoolClock(this.wall);

  final DateTime wall;

  /// 'YYYY-MM-DD'
  String get ymd => ymdOf(wall);

  /// ISO weekday: Monday is 1, Sunday is 7
  int get isoDow => wall.weekday;

  /// minutes after midnight
  int get minutes => wall.hour * 60 + wall.minute;

  /// today's date, with no time of day
  DateTime get today => DateTime.utc(wall.year, wall.month, wall.day);
}

/// What the clock at the school says at [now] (the phone's current time when left out). [timezone] is the school's IANA
/// name, for example 'Asia/Manila'.
SchoolClock schoolClock(String? timezone, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final offset = _fixedOffsets[timezone];
  if (offset == null) {
    final l = n.toLocal();
    return SchoolClock(DateTime.utc(l.year, l.month, l.day, l.hour, l.minute, l.second));
  }
  return SchoolClock(n.toUtc().add(Duration(minutes: offset)));
}

// ------------------------------------------------------------------------------------------------ dates

String _two(int n) => n.toString().padLeft(2, '0');

/// 'YYYY-MM-DD' of a calendar date.
String ymdOf(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// A 'YYYY-MM-DD' date as a UTC [DateTime] at midnight.
DateTime parseYmd(String ymd) {
  final p = ymd.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

/// The Monday of the week that holds [date].
DateTime mondayOf(DateTime date) => DateTime.utc(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));

DateTime addDaysTo(DateTime date, int days) => DateTime.utc(date.year, date.month, date.day + days);

const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String dayName(int isoDow) => _dayNames[isoDow - 1];
String dayShort(int isoDow) => _dayShort[isoDow - 1];

/// 'Wednesday, Nov 4'
String fmtLongDay(DateTime d) => '${dayName(d.weekday)}, ${_monthShort[d.month - 1]} ${d.day}';

/// 'Nov 2 to 8', or 'Oct 26 to Nov 1' when the week spans two months.
String fmtWeekRange(DateTime monday) {
  final sunday = addDaysTo(monday, 6);
  final a = '${_monthShort[monday.month - 1]} ${monday.day}';
  final b = monday.month == sunday.month ? '${sunday.day}' : '${_monthShort[sunday.month - 1]} ${sunday.day}';
  return '$a to $b';
}

/// '1:30 PM' for minutes after midnight.
String fmtMinuteOfDay(int minutes) => fmtTime('${_two(minutes ~/ 60)}:${_two(minutes % 60)}:00');

/// '25 min', '1 h', '1 h 10 min'.
String fmtSpan(int minutes) {
  if (minutes < 1) return 'under a minute';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

// ------------------------------------------------------------------------------------------------ the week

enum SlotKind { classMeeting, approvedRequest, pendingRequest }

enum SlotPhase { past, now, upcoming }

/// One block on a room's timetable: a class, or a one-off request for a time on a date.
class WeekSlot {
  const WeekSlot({
    required this.id,
    required this.kind,
    required this.ymd,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.subtitle,
    this.sectionCode,
    this.instructorName,
    this.reason,
  });

  final String id;
  final SlotKind kind;

  /// the date it happens on, 'YYYY-MM-DD'
  final String ymd;
  final String startTime;
  final String endTime;

  /// the course code, or 'Room request'
  final String title;

  /// the course title
  final String? subtitle;
  final String? sectionCode;
  final String? instructorName;

  /// what the instructor gave as the reason, for a request
  final String? reason;

  int get startMin => toMinutes(startTime);
  int get endMin => toMinutes(endTime);

  bool get isRequest => kind != SlotKind.classMeeting;

  /// a slot someone is going to use; a request nobody has decided on yet is not one
  bool get isConfirmed => kind != SlotKind.pendingRequest;
}

class WeekDay {
  const WeekDay({required this.date, required this.slots});

  final DateTime date;
  final List<WeekSlot> slots;

  String get ymd => ymdOf(date);
  int get isoDow => date.weekday;

  /// minutes of the day that are taken by a class or an approved request (a request still waiting does not count)
  int get busyMinutes {
    var total = 0;
    for (final s in slots) {
      if (s.isConfirmed) total += s.endMin - s.startMin;
    }
    return total;
  }
}

/// Monday to Sunday of the week that starts on [monday]. A class meeting appears on its weekday of every week of its
/// term (and not outside the term, as in the database's view of the room now); a request appears on its date. Rejected
/// and cancelled requests are left out; one still waiting for a decision is kept and marked as such.
List<WeekDay> buildWeek({required DateTime monday, required List<RoomMeeting> meetings, required List<RoomRequest> requests}) {
  final days = <WeekDay>[];
  for (var i = 0; i < 7; i++) {
    final date = addDaysTo(monday, i);
    final ymd = ymdOf(date);
    final slots = <WeekSlot>[];
    for (final m in meetings) {
      if (m.dayOfWeek != date.weekday) continue;
      if (m.termStarts != null && ymd.compareTo(m.termStarts!) < 0) continue;
      if (m.termEnds != null && ymd.compareTo(m.termEnds!) > 0) continue;
      slots.add(WeekSlot(
        id: 'class-${m.id}-$ymd',
        kind: SlotKind.classMeeting,
        ymd: ymd,
        startTime: m.startTime,
        endTime: m.endTime,
        title: m.courseCode ?? m.sectionCode ?? 'Class',
        subtitle: m.courseTitle,
        sectionCode: m.courseCode == null ? null : m.sectionCode,
        instructorName: m.instructorName,
      ));
    }
    for (final r in requests) {
      if (r.requestedFor != ymd) continue;
      final approved = r.status == 'approved';
      if (!approved && r.status != 'pending') continue;
      slots.add(WeekSlot(
        id: 'request-${r.id}',
        kind: approved ? SlotKind.approvedRequest : SlotKind.pendingRequest,
        ymd: ymd,
        startTime: r.startTime,
        endTime: r.endTime,
        title: 'Room request',
        instructorName: r.instructorName,
        reason: r.reason.trim().isEmpty ? null : r.reason.trim(),
      ));
    }
    slots.sort((a, b) {
      final byStart = a.startMin.compareTo(b.startMin);
      if (byStart != 0) return byStart;
      final byEnd = a.endMin.compareTo(b.endMin);
      return byEnd != 0 ? byEnd : a.id.compareTo(b.id);
    });
    days.add(WeekDay(date: date, slots: slots));
  }
  return days;
}

/// Where a slot is on the clock: already over, happening now (the start counts, the end does not), or still to come.
SlotPhase phaseOf(WeekSlot slot, SchoolClock clock) {
  final today = clock.ymd;
  final cmp = slot.ymd.compareTo(today);
  if (cmp < 0) return SlotPhase.past;
  if (cmp > 0) return SlotPhase.upcoming;
  final m = clock.minutes;
  if (m >= slot.endMin) return SlotPhase.past;
  if (m >= slot.startMin) return SlotPhase.now;
  return SlotPhase.upcoming;
}

/// The slot that comes next: the first confirmed one still to start, today or later this week. Null when the rest of the
/// week is empty.
WeekSlot? nextSlot(List<WeekDay> week, SchoolClock clock) {
  for (final d in week) {
    for (final s in d.slots) {
      if (s.isConfirmed && phaseOf(s, clock) == SlotPhase.upcoming) return s;
    }
  }
  return null;
}

/// Minutes from the clock to the start of a slot that is on the clock's day or a later one (the minutes left today when
/// it is today; a whole number of days after that is not worth showing, so null).
int? minutesUntilStart(WeekSlot slot, SchoolClock clock) => slot.ymd == clock.ymd ? slot.startMin - clock.minutes : null;
