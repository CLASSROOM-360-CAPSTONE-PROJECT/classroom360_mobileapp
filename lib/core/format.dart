/// Small formatting helpers. They give the same text as the web app (`web/src/lib/time.ts`,
/// `web/src/lib/presence/labels.ts`); `test/web_parity_test.dart` checks that against the web code.

/// 'HH:MM:SS' (a Postgres time) to minutes after midnight.
int toMinutes(String t) {
  final parts = t.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// 'HH:MM:SS' to '1:30 PM'.
String fmtTime(String t) {
  final mins = toMinutes(t);
  final h = mins ~/ 60;
  final m = mins % 60;
  final h12 = ((h + 11) % 12) + 1;
  return '$h12:${m.toString().padLeft(2, '0')} ${h >= 12 ? 'PM' : 'AM'}';
}

String fmtRange(String start, String end) => '${fmtTime(start)} to ${fmtTime(end)}';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 'YYYY-MM-DD' to 'Mon, Nov 9'. It is a calendar date, so no time zone is applied.
String fmtDate(String ymd) {
  final p = ymd.split('-').map(int.parse).toList();
  final d = DateTime.utc(p[0], p[1], p[2], 12);
  return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
}

/// A moment (already converted to the phone's time) as '1:30 PM'.
String fmtClock(DateTime t) {
  final h12 = ((t.hour + 11) % 12) + 1;
  return '$h12:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

/// A moment (already converted to the phone's time) as 'Nov 9, 1:30 PM'.
String fmtDateTime(DateTime t) => '${_months[t.month - 1]} ${t.day}, ${fmtClock(t)}';

/// 'just now', '5 min ago', '2 h ago', 'yesterday', '3 days ago'.
String fmtRelative(DateTime then, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(then);
  final min = diff.isNegative ? 0 : diff.inMinutes;
  if (min < 1) return 'just now';
  if (min < 60) return '$min min ago';
  final h = min ~/ 60;
  if (h < 24) return '$h h ago';
  final d = h ~/ 24;
  return d == 1 ? 'yesterday' : '$d days ago';
}

/// "2 people", "1 person", "nobody", or "not checked" for the camera line.
String peopleText(int? count, bool? occupied) {
  if (occupied == null) return 'not checked';
  if (!occupied) return 'nobody';
  if (count == null || count < 1) return 'someone';
  return count == 1 ? '1 person' : '$count people';
}
