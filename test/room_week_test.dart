import 'package:classroom360_mobile/core/models.dart';
import 'package:classroom360_mobile/core/room_week.dart';
import 'package:flutter_test/flutter_test.dart';

RoomMeeting meeting(String id, int dow, String start, String end, {String? code, String? starts, String? ends, String? who}) => RoomMeeting(
      id: id, roomId: 'r1', dayOfWeek: dow, startTime: start, endTime: end, courseCode: code ?? 'IT 101', courseTitle: 'Introduction', sectionCode: 'BSIT-1A', instructorName: who, termStarts: starts, termEnds: ends);

RoomRequest request(String id, String date, String start, String end, {String status = 'approved', String reason = 'Make-up class'}) => RoomRequest(
      id: id, roomId: 'r1', requestedFor: date, startTime: start, endTime: end, reason: reason, status: status, instructorName: 'Ana Cruz');

void main() {
  group('the school clock', () {
    test('Manila is eight hours ahead of UTC, whatever zone the phone is in', () {
      final c = schoolClock('Asia/Manila', now: DateTime.utc(2026, 11, 4, 15, 30)); // 23:30 in Manila
      expect(c.ymd, '2026-11-04');
      expect(c.minutes, 23 * 60 + 30);
      expect(c.isoDow, 3);
    });

    test('it can be the next day at the school while it is still today in UTC', () {
      final c = schoolClock('Asia/Manila', now: DateTime.utc(2026, 11, 4, 16, 5)); // 00:05 on the 5th in Manila
      expect(c.ymd, '2026-11-05');
      expect(c.minutes, 5);
      expect(c.isoDow, 4);
    });

    test('an unknown zone falls back to the phone\'s clock', () {
      final now = DateTime(2026, 11, 4, 9, 15);
      final c = schoolClock('Europe/Paris', now: now);
      expect(c.ymd, '2026-11-04');
      expect(c.minutes, 9 * 60 + 15);
      expect(schoolClock(null, now: now).minutes, 9 * 60 + 15);
    });
  });

  group('dates', () {
    test('the week starts on Monday, also when the date is a Sunday', () {
      expect(ymdOf(mondayOf(DateTime.utc(2026, 11, 4))), '2026-11-02');
      expect(ymdOf(mondayOf(DateTime.utc(2026, 11, 2))), '2026-11-02');
      expect(ymdOf(mondayOf(DateTime.utc(2026, 11, 8))), '2026-11-02');
      expect(ymdOf(mondayOf(DateTime.utc(2026, 11, 9))), '2026-11-09');
    });

    test('a week across a month and a year end', () {
      expect(fmtWeekRange(DateTime.utc(2026, 11, 2)), 'Nov 2 to 8');
      expect(fmtWeekRange(DateTime.utc(2026, 10, 26)), 'Oct 26 to Nov 1');
      expect(ymdOf(addDaysTo(DateTime.utc(2026, 12, 28), 6)), '2027-01-03');
    });

    test('words for days, times and spans', () {
      expect(fmtLongDay(DateTime.utc(2026, 11, 4)), 'Wednesday, Nov 4');
      expect(fmtMinuteOfDay(13 * 60 + 5), '1:05 PM');
      expect(fmtMinuteOfDay(0), '12:00 AM');
      expect(fmtSpan(0), 'under a minute');
      expect(fmtSpan(25), '25 min');
      expect(fmtSpan(60), '1 h');
      expect(fmtSpan(70), '1 h 10 min');
      expect(dayShort(7), 'Sun');
    });
  });

  group('the week', () {
    final monday = DateTime.utc(2026, 11, 2);

    test('a class meeting is on its weekday, the requests are on their dates, and each day is in time order', () {
      final week = buildWeek(
        monday: monday,
        meetings: [meeting('a', 1, '10:00:00', '11:30:00'), meeting('b', 1, '08:00:00', '09:30:00', code: 'CPE 301'), meeting('c', 3, '13:00:00', '14:30:00')],
        requests: [request('q', '2026-11-03', '15:00:00', '16:00:00')],
      );
      expect(week.length, 7);
      expect(week.map((d) => d.ymd).first, '2026-11-02');
      expect(week.map((d) => d.ymd).last, '2026-11-08');
      expect(week[0].slots.map((s) => s.title).toList(), ['CPE 301', 'IT 101']);
      expect(week[1].slots.single.title, 'Room request');
      expect(week[1].slots.single.kind, SlotKind.approvedRequest);
      expect(week[2].slots.single.startTime, '13:00:00');
      expect(week[3].slots, isEmpty);
    });

    test('a meeting is left out of days before its term starts and after it ends', () {
      final week = buildWeek(monday: monday, meetings: [meeting('a', 1, '08:00:00', '09:00:00', starts: '2026-11-03', ends: '2026-12-20'), meeting('b', 2, '08:00:00', '09:00:00', starts: '2026-08-10', ends: '2026-11-03'), meeting('c', 3, '08:00:00', '09:00:00', ends: '2026-11-03')], requests: const []);
      expect(week[0].slots, isEmpty); // Monday the 2nd, a day before the term starts
      expect(week[1].slots.single.id, startsWith('class-b')); // Tuesday the 3rd, the last day of its term
      expect(week[2].slots, isEmpty); // Wednesday the 4th, after it
    });

    test('a request that is waiting is kept and marked; a rejected or cancelled one is not shown', () {
      final week = buildWeek(
        monday: monday,
        meetings: const [],
        requests: [
          request('p', '2026-11-04', '09:00:00', '10:00:00', status: 'pending'),
          request('r', '2026-11-04', '10:00:00', '11:00:00', status: 'rejected'),
          request('c', '2026-11-04', '11:00:00', '12:00:00', status: 'cancelled'),
          request('x', '2026-11-11', '09:00:00', '10:00:00'), // next week
        ],
      );
      expect(week[2].slots.map((s) => s.kind).toList(), [SlotKind.pendingRequest]);
      expect(week.expand((d) => d.slots).length, 1);
    });

    test('busy minutes count classes and approved requests, not requests still waiting', () {
      final week = buildWeek(
        monday: monday,
        meetings: [meeting('a', 3, '08:00:00', '09:30:00')],
        requests: [request('q', '2026-11-04', '13:00:00', '14:00:00'), request('p', '2026-11-04', '15:00:00', '17:00:00', status: 'pending')],
      );
      expect(week[2].busyMinutes, 150);
    });

    test('a request with no reason has none to show; a meeting with no course falls back to its section', () {
      final week = buildWeek(
        monday: monday,
        meetings: const [RoomMeeting(id: 'm', roomId: 'r1', dayOfWeek: 5, startTime: '08:00:00', endTime: '09:00:00', sectionCode: 'BSIT-1A')],
        requests: [request('q', '2026-11-06', '10:00:00', '11:00:00', reason: '  ')],
      );
      expect(week[4].slots[0].title, 'BSIT-1A');
      expect(week[4].slots[0].sectionCode, isNull);
      expect(week[4].slots[1].reason, isNull);
    });
  });

  group('what is on now', () {
    final monday = DateTime.utc(2026, 11, 2);
    final week = buildWeek(
      monday: monday,
      meetings: [meeting('a', 3, '08:00:00', '09:30:00'), meeting('b', 3, '10:00:00', '11:30:00'), meeting('c', 4, '08:00:00', '09:00:00'), meeting('d', 2, '08:00:00', '09:00:00')],
      requests: [request('p', '2026-11-04', '09:30:00', '10:00:00', status: 'pending')],
    );
    SchoolClock at(int day, int h, int m) => SchoolClock(DateTime.utc(2026, 11, day, h, m));
    WeekSlot slot(String id) => week.expand((d) => d.slots).firstWhere((s) => s.id.contains(id));

    test('a class is on from its first minute to just before its last', () {
      expect(phaseOf(slot('class-a'), at(4, 7, 59)), SlotPhase.upcoming);
      expect(phaseOf(slot('class-a'), at(4, 8, 0)), SlotPhase.now);
      expect(phaseOf(slot('class-a'), at(4, 9, 29)), SlotPhase.now);
      expect(phaseOf(slot('class-a'), at(4, 9, 30)), SlotPhase.past);
    });

    test('an earlier day is past and a later day is still to come', () {
      expect(phaseOf(slot('class-d'), at(4, 8, 30)), SlotPhase.past);
      expect(phaseOf(slot('class-c'), at(4, 8, 30)), SlotPhase.upcoming);
    });

    test('the next one is the first confirmed slot still to start, skipping a request that is waiting', () {
      expect(nextSlot(week, at(4, 9, 0))!.id, startsWith('class-b')); // the waiting request at 9:30 is not counted
      expect(nextSlot(week, at(4, 10, 15))!.id, startsWith('class-c')); // b is on, so the next is tomorrow's
      expect(nextSlot(week, at(5, 9, 30)), isNull);
    });

    test('minutes until a slot are only given for today', () {
      expect(minutesUntilStart(slot('class-b'), at(4, 9, 0)), 60);
      expect(minutesUntilStart(slot('class-c'), at(4, 9, 0)), isNull);
    });
  });

  group('rows from the database', () {
    test('a meeting is read with its course, instructor and term', () {
      final m = RoomMeeting.fromJson({
        'id': 'e1',
        'room_id': 'r1',
        'day_of_week': 3,
        'start_time': '08:00:00',
        'end_time': '09:30:00',
        'sections': {'code': 'BSIT-1A', 'courses': {'code': 'IT 101', 'title': 'Introduction to Computing'}},
        'instructors': {'full_name': 'Maria Santos'},
        'terms': {'starts_on': '2026-08-10', 'ends_on': '2026-12-19'},
      });
      expect(m.courseCode, 'IT 101');
      expect(m.courseTitle, 'Introduction to Computing');
      expect(m.sectionCode, 'BSIT-1A');
      expect(m.instructorName, 'Maria Santos');
      expect(m.termStarts, '2026-08-10');
      expect(m.dayOfWeek, 3);
    });

    test('a meeting with nothing joined still reads, and a row with no weekday is refused', () {
      final m = RoomMeeting.fromJson({'id': 'e1', 'day_of_week': 1, 'start_time': '08:00:00', 'end_time': '09:00:00', 'sections': null, 'instructors': [], 'terms': [{'starts_on': '2026-08-10', 'ends_on': '2026-12-19'}]});
      expect(m.courseCode, isNull);
      expect(m.instructorName, isNull);
      expect(m.termEnds, '2026-12-19'); // a to-one join sent as a list
      Object? err;
      try {
        RoomMeeting.fromJson({'id': 'e1', 'start_time': '08:00:00', 'end_time': '09:00:00'});
      } catch (e) {
        err = e;
      }
      expect(err is FormatException, true);
    });
  });
}
