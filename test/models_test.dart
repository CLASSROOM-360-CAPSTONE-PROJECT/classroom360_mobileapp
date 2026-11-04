import 'package:classroom360_mobile/core/models.dart';
import 'package:classroom360_mobile/core/presence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a profile with its institution (object or one-item list) and a role', () {
    final a = Profile.fromJson({
      'id': 'u1', 'role': 'dean', 'full_name': 'Dr. Reyes', 'email': 'd@x.edu',
      'tenants': {'name': 'Holy Cross', 'timezone': 'Asia/Manila'},
    });
    expect(a.role, Role.dean);
    expect(a.institution, 'Holy Cross');
    expect(a.displayName, 'Dr. Reyes');
    final b = Profile.fromJson({'id': 'u2', 'role': 'admin', 'tenants': [{'name': 'X', 'timezone': 'UTC'}], 'email': 'a@x.edu', 'full_name': '  '});
    expect(b.institution, 'X');
    expect(b.displayName, 'a@x.edu');
    expect(Profile.fromJson({'id': 'u3', 'role': 'wizard'}).role, isNull);
  });

  test('only a dean and an administrator are operations roles', () {
    expect(isOps(Role.admin), true);
    expect(isOps(Role.dean), true);
    expect(isOps(Role.programChair), false);
    expect(isOps(Role.instructor), false);
    expect(isOps(null), false);
    expect(roleLabel(Role.programChair), 'Program chair');
  });

  test('a room status with nulls everywhere optional', () {
    final r = RoomStatus.fromJson({'room_id': 'r1', 'room_code': 'LRC-301'});
    expect(r.hasClassNow, false);
    expect(r.presence, isNull);
    expect(needsAttention(r), false);
  });

  test('a room status with a class, a key and a camera count', () {
    final r = RoomStatus.fromJson({
      'room_id': 'r1', 'room_code': 'LRC-301', 'room_name': 'Lecture 301', 'building_name': 'LRC', 'floor': 3,
      'schedule_entry_id': 's1', 'start_time': '08:00:00', 'end_time': '09:30:00', 'instructor_name': 'Ana Cruz',
      'course_code': 'CPE101', 'key_status': 'issued', 'is_occupied': true, 'person_count': 24.0, 'presence': 'teacher_present',
    });
    expect(r.hasClassNow, true);
    expect(r.personCount, 24);
    expect(r.floor, 3);
    expect(needsAttention(r), false);
    expect(keyLabel(r.keyStatus), 'Key out');
  });

  test('a room request with the instructor and room joined in', () {
    final q = RoomRequest.fromJson({
      'id': 'q1', 'instructor_id': 'i1', 'room_id': 'r1', 'requested_for': '2026-11-09', 'start_time': '13:00:00', 'end_time': '14:00:00',
      'reason': 'Make-up class', 'status': 'pending', 'created_at': '2026-11-03T08:12:45.123+00:00',
      'instructors': {'full_name': 'Ana Cruz'}, 'rooms': {'code': 'LRC-302', 'name': 'Lecture 302'},
    });
    expect(q.isPending, true);
    expect(q.instructorName, 'Ana Cruz');
    expect(q.roomCode, 'LRC-302');
    expect(requestStatusLabel(q.status), 'Waiting');
  });

  test('a row without its id is refused with a clear message, not a crash further on', () {
    Object? err;
    try {
      RoomRequest.fromJson({'room_id': 'r1'});
    } catch (e) {
      err = e;
    }
    expect(err is FormatException, true);
    expect(err.toString().contains('"id"'), true);
  });

  test('cameras and locker doors', () {
    final c = CameraRow.fromJson({'id': 'c1', 'room_id': 'r1', 'label': 'Front', 'gateway_url': 'http://10.0.0.5:8889', 'stream_path': 'lrc-301', 'is_active': true, 'rooms': {'code': 'LRC-301', 'name': 'x'}});
    expect(c.roomCode, 'LRC-301');
    final l = LockerStatus.fromJson({'locker_id': 'l1', 'room_id': 'r1', 'room_code': 'LRC-301', 'compartment_no': 1, 'holder_name': 'Ana', 'key_status': 'issued'});
    expect(l.holderName, 'Ana');
    expect(l.compartmentNo, 1);
  });
}
