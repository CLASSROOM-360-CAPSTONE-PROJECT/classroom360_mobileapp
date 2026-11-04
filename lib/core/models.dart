/// Rows as the database sends them (PostgREST JSON), read tolerantly: a missing or null field
/// becomes null instead of an error, because a role may be allowed to see fewer columns.

String? _s(Object? v) => v is String ? v : null;
int? _i(Object? v) => v is num ? v.toInt() : null;
bool? _b(Object? v) => v is bool ? v : null;
Map<String, dynamic>? _m(Object? v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is List && v.isNotEmpty && v.first is Map) return Map<String, dynamic>.from(v.first as Map); // a to-one join sent as a list
  return null;
}

String _req(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is String) return v;
  throw FormatException('missing "$key" in a row from the database');
}

enum Role { admin, dean, programChair, instructor }

Role? roleFromString(String? v) {
  switch (v) {
    case 'admin':
      return Role.admin;
    case 'dean':
      return Role.dean;
    case 'program_chair':
      return Role.programChair;
    case 'instructor':
      return Role.instructor;
  }
  return null;
}

String roleLabel(Role? r) {
  switch (r) {
    case Role.admin:
      return 'Administrator';
    case Role.dean:
      return 'Dean';
    case Role.programChair:
      return 'Program chair';
    case Role.instructor:
      return 'Instructor';
    case null:
      return 'No role';
  }
}

/// The roles that see the whole campus's keys and cameras and decide room requests.
bool isOps(Role? r) => r == Role.admin || r == Role.dean;

class Profile {
  const Profile({required this.id, required this.role, this.fullName, this.email, this.institution, this.timezone});

  final String id;
  final Role? role;
  final String? fullName;
  final String? email;
  final String? institution;
  final String? timezone;

  factory Profile.fromJson(Map<String, dynamic> j) {
    final t = _m(j['tenants']);
    return Profile(
      id: _req(j, 'id'),
      role: roleFromString(_s(j['role'])),
      fullName: _s(j['full_name']),
      email: _s(j['email']),
      institution: t == null ? null : _s(t['name']),
      timezone: t == null ? null : _s(t['timezone']),
    );
  }

  /// A name to greet the person with.
  String get displayName {
    final n = fullName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return email ?? 'Signed in';
  }
}

class RoomStatus {
  const RoomStatus({
    required this.roomId,
    required this.roomCode,
    this.roomName,
    this.buildingName,
    this.floor,
    this.scheduleEntryId,
    this.roomRequestId,
    this.startTime,
    this.endTime,
    this.instructorName,
    this.courseCode,
    this.sectionCode,
    this.keyStatus,
    this.isOccupied,
    this.occupancyAt,
    this.discrepancy,
    this.personCount,
    this.presence,
  });

  final String roomId;
  final String roomCode;
  final String? roomName;
  final String? buildingName;
  final int? floor;
  final String? scheduleEntryId;
  final String? roomRequestId;
  final String? startTime;
  final String? endTime;
  final String? instructorName;
  final String? courseCode;
  final String? sectionCode;

  /// 'available' | 'issued' | 'outstanding', or null when the room has no locker door
  final String? keyStatus;
  final bool? isOccupied;
  final String? occupancyAt;
  final String? discrepancy;
  final int? personCount;

  /// the verdict from the database (key + camera + timetable), see presence.dart
  final String? presence;

  /// a class or an approved room request is on now
  bool get hasClassNow => (scheduleEntryId != null || roomRequestId != null) && startTime != null && endTime != null;

  factory RoomStatus.fromJson(Map<String, dynamic> j) => RoomStatus(
        roomId: _req(j, 'room_id'),
        roomCode: _req(j, 'room_code'),
        roomName: _s(j['room_name']),
        buildingName: _s(j['building_name']),
        floor: _i(j['floor']),
        scheduleEntryId: _s(j['schedule_entry_id']),
        roomRequestId: _s(j['room_request_id']),
        startTime: _s(j['start_time']),
        endTime: _s(j['end_time']),
        instructorName: _s(j['instructor_name']),
        courseCode: _s(j['course_code']),
        sectionCode: _s(j['section_code']),
        keyStatus: _s(j['key_status']),
        isOccupied: _b(j['is_occupied']),
        occupancyAt: _s(j['occupancy_at']),
        discrepancy: _s(j['discrepancy']),
        personCount: _i(j['person_count']),
        presence: _s(j['presence']),
      );
}

/// One door of the key locker (view `locker_status`).
class LockerStatus {
  const LockerStatus({required this.lockerId, required this.roomId, required this.roomCode, required this.compartmentNo, this.holderName, this.issuedAt, this.keyStatus});

  final String lockerId;
  final String roomId;
  final String roomCode;
  final int compartmentNo;
  final String? holderName;
  final String? issuedAt;
  final String? keyStatus;

  factory LockerStatus.fromJson(Map<String, dynamic> j) => LockerStatus(
        lockerId: _req(j, 'locker_id'),
        roomId: _req(j, 'room_id'),
        roomCode: _req(j, 'room_code'),
        compartmentNo: _i(j['compartment_no']) ?? 0,
        holderName: _s(j['holder_name']),
        issuedAt: _s(j['issued_at']),
        keyStatus: _s(j['key_status']),
      );
}

class RoomRequest {
  const RoomRequest({
    required this.id,
    required this.roomId,
    required this.requestedFor,
    required this.startTime,
    required this.endTime,
    required this.reason,
    required this.status,
    this.instructorName,
    this.roomCode,
    this.roomName,
    this.decidedAt,
    this.decisionNote,
    this.createdAt,
  });

  final String id;
  final String roomId;

  /// 'YYYY-MM-DD'
  final String requestedFor;
  final String startTime;
  final String endTime;
  final String reason;

  /// 'pending' | 'approved' | 'rejected' | 'cancelled'
  final String status;
  final String? instructorName;
  final String? roomCode;
  final String? roomName;
  final String? decidedAt;
  final String? decisionNote;
  final String? createdAt;

  bool get isPending => status == 'pending';

  factory RoomRequest.fromJson(Map<String, dynamic> j) {
    final i = _m(j['instructors']);
    final r = _m(j['rooms']);
    return RoomRequest(
      id: _req(j, 'id'),
      roomId: _req(j, 'room_id'),
      requestedFor: _req(j, 'requested_for'),
      startTime: _req(j, 'start_time'),
      endTime: _req(j, 'end_time'),
      reason: _s(j['reason']) ?? '',
      status: _req(j, 'status'),
      instructorName: i == null ? null : _s(i['full_name']),
      roomCode: r == null ? null : _s(r['code']),
      roomName: r == null ? null : _s(r['name']),
      decidedAt: _s(j['decided_at']),
      decisionNote: _s(j['decision_note']),
      createdAt: _s(j['created_at']),
    );
  }
}

/// One class meeting that repeats every week in a room: a published row of `schedule_entries`, with the course, the section,
/// the instructor and the term it belongs to.
class RoomMeeting {
  const RoomMeeting({
    required this.id,
    required this.roomId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.courseCode,
    this.courseTitle,
    this.sectionCode,
    this.instructorName,
    this.termStarts,
    this.termEnds,
  });

  final String id;
  final String roomId;

  /// ISO weekday: Monday is 1, Sunday is 7
  final int dayOfWeek;

  /// 'HH:MM:SS'
  final String startTime;
  final String endTime;
  final String? courseCode;
  final String? courseTitle;
  final String? sectionCode;
  final String? instructorName;

  /// the first and last day of the term the meeting belongs to ('YYYY-MM-DD'); outside them it does not happen
  final String? termStarts;
  final String? termEnds;

  factory RoomMeeting.fromJson(Map<String, dynamic> j) {
    final section = _m(j['sections']);
    final course = section == null ? null : _m(section['courses']);
    final instructor = _m(j['instructors']);
    final term = _m(j['terms']);
    final day = _i(j['day_of_week']);
    if (day == null) throw const FormatException('missing "day_of_week" in a row from the database');
    return RoomMeeting(
      id: _req(j, 'id'),
      roomId: _s(j['room_id']) ?? '',
      dayOfWeek: day,
      startTime: _req(j, 'start_time'),
      endTime: _req(j, 'end_time'),
      courseCode: course == null ? null : _s(course['code']),
      courseTitle: course == null ? null : _s(course['title']),
      sectionCode: section == null ? null : _s(section['code']),
      instructorName: instructor == null ? null : _s(instructor['full_name']),
      termStarts: term == null ? null : _s(term['starts_on']),
      termEnds: term == null ? null : _s(term['ends_on']),
    );
  }
}

String requestStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Waiting';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'cancelled':
      return 'Cancelled';
  }
  return status;
}

class CameraRow {
  const CameraRow({required this.id, required this.roomId, required this.label, required this.gatewayUrl, required this.streamPath, required this.isActive, this.roomCode, this.roomName});

  final String id;
  final String roomId;
  final String label;

  /// the parent Raspberry Pi, for example http://192.168.1.50:8889
  final String gatewayUrl;

  /// the stream name on the gateway, for example lrc-301
  final String streamPath;
  final bool isActive;
  final String? roomCode;
  final String? roomName;

  factory CameraRow.fromJson(Map<String, dynamic> j) {
    final r = _m(j['rooms']);
    return CameraRow(
      id: _req(j, 'id'),
      roomId: _req(j, 'room_id'),
      label: _s(j['label']) ?? 'Camera',
      gatewayUrl: _req(j, 'gateway_url'),
      streamPath: _req(j, 'stream_path'),
      isActive: _b(j['is_active']) ?? true,
      roomCode: r == null ? null : _s(r['code']),
      roomName: r == null ? null : _s(r['name']),
    );
  }
}

/// One line of the signed-in person's inbox (table `notifications`). The database writes them; the app only reads them
/// and marks them read.
class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.body,
    required this.createdAt,
    this.link,
    this.readAt,
  });

  final String id;
  final String kind;

  /// 'high' | 'medium' | 'info'
  final String severity;
  final String title;
  final String body;

  /// a page of the web app such as "/requests"; the phone maps it to one of its own pages (see inbox.dart)
  final String? link;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  InboxMessage markedRead(DateTime at) =>
      InboxMessage(id: id, kind: kind, severity: severity, title: title, body: body, link: link, createdAt: createdAt, readAt: readAt ?? at);

  factory InboxMessage.fromJson(Map<String, dynamic> j) {
    final created = DateTime.tryParse(_s(j['created_at']) ?? '');
    if (created == null) throw const FormatException('missing "created_at" in a row from the database');
    final sev = _s(j['severity']);
    return InboxMessage(
      id: _req(j, 'id'),
      kind: _s(j['kind']) ?? '',
      severity: sev == 'high' || sev == 'medium' ? sev! : 'info',
      title: _req(j, 'title'),
      body: _s(j['body']) ?? '',
      link: _s(j['link']),
      createdAt: created.toLocal(),
      readAt: DateTime.tryParse(_s(j['read_at']) ?? '')?.toLocal(),
    );
  }
}
