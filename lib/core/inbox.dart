import 'models.dart';
import 'presence.dart';

/// Where a message sends the person on the phone. The database words a link as a page of the web app; the phone has
/// three pages, so it maps the ones that have a counterpart and ignores the rest (a timetable is a web page).
/// Returns the tab index (0 Rooms, 1 Requests, 2 Cameras), or null when the phone has no such page.
int? tabForLink(String? link) {
  if (link == null) return null;
  final path = link.split('?').first;
  switch (path) {
    case '/':
    case '/lockers':
      return 0;
    case '/requests':
      return 1;
    case '/cameras':
      return 2;
  }
  return null;
}

/// How strongly a message is drawn: urgent red, "look soon" amber, information grey.
Tone inboxTone(String severity) {
  switch (severity) {
    case 'high':
      return Tone.bad;
    case 'medium':
      return Tone.warn;
  }
  return Tone.neutral;
}

String inboxSeverityLabel(String severity) {
  switch (severity) {
    case 'high':
      return 'Urgent';
    case 'medium':
      return 'Look soon';
  }
  return 'For information';
}

/// The unread ones first would hide the order they came in; the list stays newest first and unread ones are only drawn bolder.
List<InboxMessage> newestFirst(List<InboxMessage> list) {
  final out = [...list];
  out.sort((a, b) {
    final c = b.createdAt.compareTo(a.createdAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return out;
}
