import 'models.dart';

/// How a verdict should look: neutral grey, good green, warn amber, bad red, brass gold.
enum Tone { neutral, good, warn, bad, brass }

class PresenceInfo {
  const PresenceInfo(this.label, this.why, this.tone, this.attention);

  /// short label for a badge
  final String label;

  /// a sentence for people who want to know why
  final String why;
  final Tone tone;

  /// worth someone's attention now
  final bool attention;
}

/// What the combined timetable, key and camera picture means, in plain words.
/// The verdict itself is worked out by the database (view `room_status_now`, column `presence`);
/// the app only words it. Same text as `web/src/lib/presence/labels.ts`.
const Map<String, PresenceInfo> kPresence = {
  'no_class': PresenceInfo('No class', 'Nothing is scheduled in this room now and the camera sees nobody.', Tone.neutral, false),
  'occupied_unscheduled': PresenceInfo('Occupied, no class', 'The camera sees people but nothing is scheduled in this room now.', Tone.warn, true),
  'teacher_present': PresenceInfo('Teacher present', 'The scheduled instructor took the key and the camera sees people in the room.', Tone.good, false),
  'key_out_room_empty': PresenceInfo('Key out, room empty', 'The key was taken but the camera sees nobody. The instructor may have stepped out.', Tone.warn, true),
  'key_out_unchecked': PresenceInfo('Key out', 'The key was taken. The camera has not reported lately, so the room is unchecked.', Tone.brass, false),
  'key_with_other': PresenceInfo('Key with someone else', 'The key is held by a person who is not scheduled in this room now.', Tone.bad, true),
  'people_key_in_locker': PresenceInfo('People, key not taken', 'People are in the room but the key is still in the locker.', Tone.warn, true),
  'not_started': PresenceInfo('Waiting for teacher', 'The class has just started and the key is still in the locker. The grace period is not over.', Tone.neutral, false),
  'teacher_absent': PresenceInfo('Teacher not here', 'The class started, the grace period is over, the key is still in the locker and nobody is seen.', Tone.bad, true),
  'camera_only_present': PresenceInfo('People seen', 'This room has no locker door, so only the camera is used. It sees people.', Tone.good, false),
  'camera_only_empty': PresenceInfo('Room empty', 'This room has no locker door, so only the camera is used. It sees nobody.', Tone.warn, true),
  'unchecked': PresenceInfo('Not checked', 'There is a class but no key and no recent camera report to judge by.', Tone.neutral, false),
};

PresenceInfo? presenceInfo(String? presence) => presence == null ? null : kPresence[presence];

/// A room that needs a person to look at it. Once the combined verdict exists it decides (it knows
/// about the grace period); the older mismatch flag is only used when the verdict is missing.
bool needsAttention(RoomStatus r) {
  final p = r.presence;
  if (p != null) return kPresence[p]?.attention ?? false;
  return r.discrepancy != null;
}

/// The old two-value mismatch, only shown when the database sent no verdict.
String? discrepancyLabel(String? d) {
  switch (d) {
    case 'scheduled_but_empty':
      return 'Scheduled but empty';
    case 'occupied_not_scheduled':
      return 'Occupied, not scheduled';
  }
  return null;
}

/// "Key out", "Not returned", "In locker" or "No locker".
String keyLabel(String? keyStatus) {
  switch (keyStatus) {
    case 'issued':
      return 'Key out';
    case 'outstanding':
      return 'Not returned';
    case 'available':
      return 'In locker';
  }
  return 'No locker';
}
