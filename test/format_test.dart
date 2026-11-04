import 'package:classroom360_mobile/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fmtTime handles midnight, noon and the afternoon', () {
    expect(fmtTime('00:00:00'), '12:00 AM');
    expect(fmtTime('00:30:00'), '12:30 AM');
    expect(fmtTime('12:00:00'), '12:00 PM');
    expect(fmtTime('13:05:00'), '1:05 PM');
    expect(fmtTime('23:59:00'), '11:59 PM');
    expect(fmtTime('07:30'), '7:30 AM');
  });

  test('fmtRange', () {
    expect(fmtRange('08:00:00', '09:30:00'), '8:00 AM to 9:30 AM');
  });

  test('fmtDate is a calendar date with its weekday', () {
    expect(fmtDate('2026-11-09'), 'Mon, Nov 9');
    expect(fmtDate('2028-02-29'), 'Tue, Feb 29');
  });

  test('fmtRelative', () {
    final now = DateTime.utc(2026, 11, 3, 12, 0, 0);
    expect(fmtRelative(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(fmtRelative(now.add(const Duration(minutes: 5)), now: now), 'just now'); // a clock a little ahead
    expect(fmtRelative(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(fmtRelative(now.subtract(const Duration(hours: 3, minutes: 10)), now: now), '3 h ago');
    expect(fmtRelative(now.subtract(const Duration(hours: 30)), now: now), 'yesterday');
    expect(fmtRelative(now.subtract(const Duration(days: 4)), now: now), '4 days ago');
  });

  test('peopleText', () {
    expect(peopleText(null, null), 'not checked');
    expect(peopleText(3, false), 'nobody');
    expect(peopleText(null, true), 'someone');
    expect(peopleText(1, true), '1 person');
    expect(peopleText(12, true), '12 people');
  });

  test('fmtClock and fmtDateTime', () {
    expect(fmtClock(DateTime(2026, 11, 9, 0, 5)), '12:05 AM');
    expect(fmtClock(DateTime(2026, 11, 9, 12, 0)), '12:00 PM');
    expect(fmtClock(DateTime(2026, 11, 9, 13, 30)), '1:30 PM');
    expect(fmtClock(DateTime(2026, 11, 9, 23, 59)), '11:59 PM');
    expect(fmtDateTime(DateTime(2026, 11, 9, 13, 30)), 'Nov 9, 1:30 PM');
  });
}
