import 'dart:math' as math;

import 'models.dart';
import 'presence.dart';

/// The numbers the Rooms page shows on its ledger plate, worked out the same way as the web app's campus overview
/// (`web/src/pages/Dashboard.tsx`): a room is in use while a class or an approved request is on, a key is out while
/// its locker door says it was taken, and "not returned" is a key that is still out after its class ended.
class LockerFigures {
  const LockerFigures({required this.roomsInUse, required this.totalRooms, required this.keysOut, required this.notReturned, required this.doors});

  final int roomsInUse;
  final int totalRooms;
  final int keysOut;
  final int notReturned;

  /// how many locker doors there are
  final int doors;

  factory LockerFigures.from(List<RoomStatus> rooms, List<LockerStatus> lockers) {
    return LockerFigures(
      roomsInUse: rooms.where((r) => r.hasClassNow).length,
      totalRooms: rooms.length,
      keysOut: lockers.where((l) => l.keyStatus == 'issued').length,
      notReturned: lockers.where((l) => l.keyStatus == 'outstanding').length,
      doors: lockers.length,
    );
  }
}

/// The three ways the Rooms page can narrow its list.
enum RoomFilter { all, attention, keyOut }

extension RoomFilterX on RoomFilter {
  bool matches(RoomStatus r) {
    switch (this) {
      case RoomFilter.all:
        return true;
      case RoomFilter.attention:
        return needsAttention(r);
      case RoomFilter.keyOut:
        return r.keyStatus == 'issued' || r.keyStatus == 'outstanding';
    }
  }
}

List<RoomStatus> applyRoomFilter(List<RoomStatus> rooms, RoomFilter filter) => rooms.where(filter.matches).toList();

/// What a locker door looks like: nothing behind it, the key inside, the key out, or the key out and overdue.
enum DoorState { empty, inside, out, notReturned }

DoorState doorState(LockerStatus? locker) {
  if (locker == null) return DoorState.empty;
  switch (locker.keyStatus) {
    case 'issued':
      return DoorState.out;
    case 'outstanding':
      return DoorState.notReturned;
  }
  return DoorState.inside;
}

/// The doors in the order they stand in the cabinet.
List<LockerStatus> sortedDoors(List<LockerStatus> lockers) {
  final list = [...lockers];
  list.sort((a, b) => a.compartmentNo.compareTo(b.compartmentNo));
  return list;
}

/// The number of the door that holds a room's key, or null when the room has no locker door.
int? doorNumberFor(String roomId, List<LockerStatus> lockers) {
  for (final l in lockers) {
    if (l.roomId == roomId) return l.compartmentNo;
  }
  return null;
}

/// How far a hanging key tag is turned, in radians, [t] (0 to 1) of the way through its settling swing: it starts
/// turned by [amplitude], swings back and forth a couple of times and comes to rest straight.
double swingAngle(double t, {double amplitude = 0.2, double cycles = 2.25}) {
  final p = t.clamp(0.0, 1.0);
  if (p >= 1) return 0;
  return amplitude * math.exp(-3.4 * p) * math.cos(2 * math.pi * cycles * p);
}

/// The letters in a person's round badge: the first letter of their first and last names ("Maria Santos" is "MS"),
/// or just one letter for a single name, or "?" when there is no name.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  String first(String s) => String.fromCharCode(s.runes.first).toUpperCase();
  if (parts.length == 1) return first(parts.first);
  return first(parts.first) + first(parts.last);
}
