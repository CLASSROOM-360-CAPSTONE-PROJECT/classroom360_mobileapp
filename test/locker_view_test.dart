import 'package:classroom360_mobile/core/locker_view.dart';
import 'package:classroom360_mobile/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

RoomStatus room(String id, String code, {String? presence, String? keyStatus, bool inClass = false}) => RoomStatus(
      roomId: id,
      roomCode: code,
      presence: presence,
      keyStatus: keyStatus,
      scheduleEntryId: inClass ? 'e-$id' : null,
      startTime: inClass ? '08:30:00' : null,
      endTime: inClass ? '10:00:00' : null,
    );

LockerStatus door(int n, String roomId, String roomCode, {String? keyStatus}) =>
    LockerStatus(lockerId: 'l$n', roomId: roomId, roomCode: roomCode, compartmentNo: n, keyStatus: keyStatus);

void main() {
  group('LockerFigures', () {
    test('counts rooms in use, keys out and keys not returned', () {
      final rooms = [
        room('r1', 'LRC-301', inClass: true, keyStatus: 'issued'),
        room('r2', 'LRC-302', inClass: true, keyStatus: 'outstanding'),
        room('r3', 'LRC-303', keyStatus: 'available'),
        room('r4', 'LRC-304'),
      ];
      final doors = [
        door(1, 'r1', 'LRC-301', keyStatus: 'issued'),
        door(2, 'r2', 'LRC-302', keyStatus: 'outstanding'),
        door(3, 'r3', 'LRC-303', keyStatus: 'available'),
        door(4, 'r4', 'LRC-304', keyStatus: 'available'),
      ];
      final f = LockerFigures.from(rooms, doors);
      expect(f.roomsInUse, 2);
      expect(f.totalRooms, 4);
      expect(f.keysOut, 1);
      expect(f.notReturned, 1);
      expect(f.doors, 4);
    });

    test('is all zeros before anything has loaded', () {
      final f = LockerFigures.from(const [], const []);
      expect(f.roomsInUse, 0);
      expect(f.totalRooms, 0);
      expect(f.keysOut, 0);
      expect(f.notReturned, 0);
      expect(f.doors, 0);
    });
  });

  group('RoomFilter', () {
    final rooms = [
      room('r1', 'LRC-301', presence: 'teacher_present', keyStatus: 'issued', inClass: true),
      room('r2', 'LRC-302', presence: 'teacher_absent', keyStatus: 'available', inClass: true),
      room('r3', 'LRC-303', presence: 'no_class', keyStatus: 'outstanding'),
      room('r4', 'LRC-304', presence: 'no_class', keyStatus: 'available'),
    ];

    test('all keeps every room', () {
      expect(applyRoomFilter(rooms, RoomFilter.all).length, 4);
    });

    test('attention keeps the rooms someone should look at', () {
      final codes = applyRoomFilter(rooms, RoomFilter.attention).map((r) => r.roomCode).toList();
      expect(codes, ['LRC-302']);
    });

    test('keyOut keeps rooms whose key is out or not returned', () {
      final codes = applyRoomFilter(rooms, RoomFilter.keyOut).map((r) => r.roomCode).toList();
      expect(codes, ['LRC-301', 'LRC-303']);
    });
  });

  group('doors', () {
    test('doorState reads the key status', () {
      expect(doorState(null), DoorState.empty);
      expect(doorState(door(1, 'r1', 'A', keyStatus: 'available')), DoorState.inside);
      expect(doorState(door(1, 'r1', 'A', keyStatus: 'issued')), DoorState.out);
      expect(doorState(door(1, 'r1', 'A', keyStatus: 'outstanding')), DoorState.notReturned);
      expect(doorState(door(1, 'r1', 'A')), DoorState.inside);
    });

    test('sortedDoors puts the doors in cabinet order without touching the input', () {
      final input = [door(3, 'r3', 'C'), door(1, 'r1', 'A'), door(2, 'r2', 'B')];
      expect(sortedDoors(input).map((d) => d.compartmentNo).toList(), [1, 2, 3]);
      expect(input.first.compartmentNo, 3);
    });

    test('doorNumberFor finds the door of a room, or null', () {
      final doors = [door(1, 'r1', 'A'), door(4, 'r4', 'D')];
      expect(doorNumberFor('r4', doors), 4);
      expect(doorNumberFor('r9', doors), null);
    });
  });

  group('swingAngle', () {
    test('starts turned, ends straight and never leaves its amplitude', () {
      expect(swingAngle(0, amplitude: 0.2), closeTo(0.2, 1e-9));
      expect(swingAngle(1), 0);
      for (var i = 0; i <= 100; i++) {
        final a = swingAngle(i / 100, amplitude: 0.2);
        expect(a.abs() <= 0.2 + 1e-9, true);
      }
    });

    test('clamps time outside 0 to 1', () {
      expect(swingAngle(-3, amplitude: 0.2), closeTo(0.2, 1e-9));
      expect(swingAngle(7), 0);
    });
  });
  group('initialsOf', () {
    test('takes the first letters of the first and last names', () {
      expect(initialsOf('Maria Santos'), 'MS');
      expect(initialsOf('juan de la Cruz'), 'JC');
    });
    test('copes with one name, extra spaces and no name', () {
      expect(initialsOf('Dean'), 'D');
      expect(initialsOf('  ana   lopez  '), 'AL');
      expect(initialsOf(''), '?');
      expect(initialsOf('   '), '?');
    });
  });
}
