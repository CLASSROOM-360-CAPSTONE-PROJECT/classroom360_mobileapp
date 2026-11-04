import 'package:classroom360_mobile/core/inbox.dart';
import 'package:classroom360_mobile/core/models.dart';
import 'package:classroom360_mobile/core/presence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a link of the web app opens the phone page that has the same job, or none', () {
    expect(tabForLink('/'), 0);
    expect(tabForLink('/lockers'), 0);
    expect(tabForLink('/requests'), 1);
    expect(tabForLink('/cameras'), 2);
    expect(tabForLink('/requests?x=1'), 1);
    expect(tabForLink('/timetables?term=T&program=all'), isNull, reason: 'a timetable is a web page');
    expect(tabForLink('/schedules'), isNull);
    expect(tabForLink('//evil.example/requests'), isNull);
    expect(tabForLink('https://evil.example/requests'), isNull);
    expect(tabForLink(''), isNull);
    expect(tabForLink(null), isNull);
  });

  test('severity gives the colour and the words', () {
    expect(inboxTone('high'), Tone.bad);
    expect(inboxTone('medium'), Tone.warn);
    expect(inboxTone('info'), Tone.neutral);
    expect(inboxTone('anything else'), Tone.neutral);
    expect(inboxSeverityLabel('high'), 'Urgent');
    expect(inboxSeverityLabel('medium'), 'Look soon');
    expect(inboxSeverityLabel('info'), 'For information');
  });

  test('a message as the database sends it', () {
    final m = InboxMessage.fromJson({
      'id': 'n1', 'kind': 'key_not_returned', 'severity': 'high', 'title': 'Key not returned: LRC-302',
      'body': 'Ben Cruz took it at 9:12 AM.', 'link': '/lockers', 'created_at': '2026-11-04T01:12:00+00:00', 'read_at': null,
    });
    expect(m.isUnread, true);
    expect(m.severity, 'high');
    expect(m.link, '/lockers');
    expect(m.createdAt.toUtc(), DateTime.utc(2026, 11, 4, 1, 12));
    final read = m.markedRead(DateTime.utc(2026, 11, 4, 2));
    expect(read.isUnread, false);
    expect(read.title, m.title);
    expect(read.markedRead(DateTime.utc(2026, 11, 4, 3)).readAt, read.readAt, reason: 'the first reading time stays');
  });

  test('an unknown severity is drawn as information, a missing body is empty, a missing time is refused', () {
    final m = InboxMessage.fromJson({'id': 'n2', 'title': 'Hello', 'severity': 'banana', 'created_at': '2026-11-04T01:12:00Z'});
    expect(m.severity, 'info');
    expect(m.body, '');
    expect(m.link, isNull);
    expect(m.kind, '');
    Object? caught;
    try {
      InboxMessage.fromJson({'id': 'n3', 'title': 'No time'});
    } catch (e) {
      caught = e;
    }
    expect(caught, isA<FormatException>());
    caught = null;
    try {
      InboxMessage.fromJson({'title': 'No id', 'created_at': '2026-11-04T01:12:00Z'});
    } catch (e) {
      caught = e;
    }
    expect(caught, isA<FormatException>());
  });

  test('newest first, a tie broken by id', () {
    InboxMessage at(String id, DateTime t) => InboxMessage(id: id, kind: 'k', severity: 'info', title: id, body: '', createdAt: t);
    final a = at('b', DateTime.utc(2026, 11, 4, 1));
    final b = at('a', DateTime.utc(2026, 11, 4, 1));
    final c = at('c', DateTime.utc(2026, 11, 4, 2));
    expect(newestFirst([a, b, c]).map((m) => m.id).toList(), ['c', 'a', 'b']);
  });
}
