import 'dart:async';

import 'package:classroom360_mobile/core/models.dart';
import 'package:classroom360_mobile/core/store.dart';
import 'package:flutter_test/flutter_test.dart';

RoomStatus room(String id, String code, {String? presence, String? keyStatus}) =>
    RoomStatus(roomId: id, roomCode: code, presence: presence, keyStatus: keyStatus);

RoomRequest req(String id, {String status = 'pending', String roomId = 'r1'}) => RoomRequest(
      id: id, roomId: roomId, requestedFor: '2026-11-09', startTime: '13:00:00', endTime: '14:00:00', reason: 'Make-up class', status: status, instructorName: 'Ana Cruz', roomCode: 'LRC-302');

CameraRow cam(String id, String roomId, String roomCode, String label, {bool active = true}) =>
    CameraRow(id: id, roomId: roomId, label: label, gatewayUrl: 'http://10.0.0.5:8889', streamPath: id, isActive: active, roomCode: roomCode);

class FakeBackend implements Backend {
  List<RoomStatus> rooms = [];
  List<LockerStatus> lockers = [];
  List<RoomRequest> pending = [];
  List<RoomRequest> decided = [];
  List<CameraRow> cameraRows = [];
  Object? roomsError, requestsError, decideError;
  int roomCalls = 0, requestCalls = 0, cameraCalls = 0;
  final List<Map<String, Object?>> decisions = [];
  String? busyWhileDeciding;
  AppStore? store;
  Duration roomDelay = Duration.zero;
  final StreamController<void> changes = StreamController<void>.broadcast();

  @override
  Future<Profile?> loadProfile() async => const Profile(id: 'u', role: Role.dean);
  @override
  Future<List<RoomStatus>> roomStatus() async {
    roomCalls++;
    if (roomDelay > Duration.zero) await Future<void>.delayed(roomDelay);
    if (roomsError != null) throw roomsError!;
    return rooms;
  }

  @override
  Future<List<LockerStatus>> lockerStatus() async => lockers;
  @override
  Future<List<RoomRequest>> pendingRequests() async {
    requestCalls++;
    if (requestsError != null) throw requestsError!;
    return pending;
  }

  @override
  Future<List<RoomRequest>> decidedRequests() async => decided;
  @override
  Future<List<CameraRow>> cameras() async {
    cameraCalls++;
    return cameraRows;
  }

  @override
  Future<void> decideRequest(String requestId, {required bool approve, String? note}) async {
    busyWhileDeciding = store?.busyRequestId;
    decisions.add({'id': requestId, 'approve': approve, 'note': note});
    if (decideError != null) throw decideError!;
    // the database now shows the decision
    final r = pending.firstWhere((p) => p.id == requestId);
    pending = pending.where((p) => p.id != requestId).toList();
    decided = [req(r.id, status: approve ? 'approved' : 'rejected'), ...decided];
  }

  @override
  Stream<void> requestChanges() => changes.stream;
  @override
  Future<String?> accessToken() async => 'token';

  // ---- the inbox
  List<InboxMessage> inboxRows = [];
  int? unreadTotal; // when set, the database holds more unread than the list shows
  Object? inboxError;
  int inboxCalls = 0, sweepCalls = 0;
  int sweepMakes = 0; // how many messages the next sweep makes
  Object? sweepError;
  Object? markError;
  final List<List<String>?> marks = [];
  final StreamController<void> inboxFeed = StreamController<void>.broadcast();

  @override
  Future<List<InboxMessage>> inbox() async {
    inboxCalls++;
    if (inboxError != null) throw inboxError!;
    return inboxRows;
  }

  @override
  Future<int> unreadCount() async => unreadTotal ?? inboxRows.where((m) => m.isUnread).length;
  @override
  Future<void> markRead(List<String>? ids) async {
    marks.add(ids);
    if (markError != null) throw markError!;
    final now = DateTime.now();
    inboxRows = [for (final m in inboxRows) (ids == null || ids.contains(m.id)) ? m.markedRead(now) : m];
  }

  @override
  Future<int> sweepAlerts() async {
    sweepCalls++;
    if (sweepError != null) throw sweepError!;
    final made = sweepMakes;
    for (var i = 0; i < made; i++) {
      inboxRows = [msg('swept$sweepCalls$i', title: 'Key not returned', severity: 'high', minutesAgo: 0), ...inboxRows];
    }
    sweepMakes = 0;
    return made;
  }

  @override
  Stream<void> inboxChanges() => inboxFeed.stream;

  // ---- one room's week
  List<RoomMeeting> meetingRows = [];
  List<RoomRequest> roomRequestRows = [];
  Object? weekError;
  final List<String> weekAsked = [];

  @override
  Future<List<RoomMeeting>> roomMeetings(String roomId) async {
    weekAsked.add('meetings $roomId');
    if (weekError != null) throw weekError!;
    return meetingRows.where((m) => m.roomId == roomId).toList();
  }

  @override
  Future<List<RoomRequest>> roomRequests(String roomId, String fromYmd, String toYmd) async {
    weekAsked.add('requests $roomId $fromYmd $toYmd');
    return roomRequestRows.where((r) => r.roomId == roomId && r.requestedFor.compareTo(fromYmd) >= 0 && r.requestedFor.compareTo(toYmd) <= 0).toList();
  }
}

InboxMessage msg(String id, {String title = 'New room request', String severity = 'info', int minutesAgo = 5, bool read = false, String? link = '/requests'}) {
  final at = DateTime.now().subtract(Duration(minutes: minutesAgo));
  return InboxMessage(id: id, kind: 'request_new', severity: severity, title: title, body: '', link: link, createdAt: at, readAt: read ? at : null);
}

class DbError implements Exception {
  DbError(this.message);
  final String message;
}

void main() {
  late FakeBackend be;
  late AppStore store;

  setUp(() {
    be = FakeBackend();
    store = AppStore(be, roomsEvery: const Duration(milliseconds: 60), requestsEvery: const Duration(milliseconds: 60), sweepEvery: const Duration(milliseconds: 60));
    be.store = store;
  });
  tearDown(() => store.dispose());

  test('rooms load, the ones that need a look come first, then by code', () async {
    be.rooms = [room('1', 'LRC-301', presence: 'teacher_present'), room('2', 'LRC-302', presence: 'teacher_absent'), room('3', 'LRC-303', presence: 'no_class'), room('4', 'LRC-304', presence: 'key_with_other')];
    await store.refreshRooms();
    expect(store.roomsLoaded, true);
    expect(store.sortedRooms.map((r) => r.roomCode).toList(), ['LRC-302', 'LRC-304', 'LRC-301', 'LRC-303']);
    expect(store.attentionCount, 2);
  });

  test('a failed load keeps the last good data and says why; the next good load clears the message', () async {
    be.rooms = [room('1', 'LRC-301')];
    await store.refreshRooms();
    be.roomsError = DbError('boom');
    await store.refreshRooms();
    expect(store.rooms.length, 1);
    expect(store.roomsError, 'boom');
    be.roomsError = null;
    await store.refreshRooms();
    expect(store.roomsError, isNull);
  });

  test('two refreshes at once make one call', () async {
    be.roomDelay = const Duration(milliseconds: 50);
    await Future.wait([store.refreshRooms(), store.refreshRooms()]);
    expect(be.roomCalls, 1);
  });

  test('the locker door of a room, and the first active camera of a room', () async {
    be.lockers = [const LockerStatus(lockerId: 'l1', roomId: '1', roomCode: 'LRC-301', compartmentNo: 1, holderName: 'Ana', keyStatus: 'issued')];
    be.rooms = [room('1', 'LRC-301')];
    be.cameraRows = [cam('b', '1', 'LRC-301', 'Back'), cam('a', '1', 'LRC-301', 'Front'), cam('x', '2', 'LRC-302', 'Old', active: false)];
    await store.refreshAll();
    expect(store.lockerForRoom('1')!.holderName, 'Ana');
    expect(store.lockerForRoom('9'), isNull);
    expect(store.activeCameras.map((c) => c.label).toList(), ['Back', 'Front']);
    expect(store.cameraForRoom('1')!.label, 'Back');
    expect(store.cameraForRoom('2'), isNull);
    expect(store.roomById('1')!.roomCode, 'LRC-301');
  });

  test('accepting a request: sent without a note, announced, refreshed', () async {
    be.pending = [req('q1'), req('q2')];
    await store.refreshRequests();
    expect(store.pending.length, 2);
    final ok = await store.decide(store.pending.first, approve: true);
    expect(ok, true);
    expect(be.decisions, [{'id': 'q1', 'approve': true, 'note': null}]);
    expect(be.busyWhileDeciding, 'q1');
    expect(store.busyRequestId, isNull);
    expect(store.notice!.isError, false);
    expect(store.notice!.text, startsWith('Approved.'));
    expect(store.pending.map((r) => r.id).toList(), ['q2']);
    expect(store.decided.first.status, 'approved');
  });

  test('rejecting needs a note, and the note is trimmed', () async {
    be.pending = [req('q1')];
    await store.refreshRequests();
    var ok = await store.decide(store.pending.first, approve: false, note: '   ');
    expect(ok, false);
    expect(be.decisions, isEmpty);
    expect(store.notice!.isError, true);
    ok = await store.decide(store.pending.first, approve: false, note: '  Room is reserved for an exam  ');
    expect(ok, true);
    expect(be.decisions, [{'id': 'q1', 'approve': false, 'note': 'Room is reserved for an exam'}]);
    expect(store.notice!.text, startsWith('Rejected.'));
  });

  test('a refusal from the database is shown in words and the list is reloaded', () async {
    be.pending = [req('q1')];
    await store.refreshRequests();
    be.decideError = DbError('that time has already passed');
    final before = be.requestCalls;
    final ok = await store.decide(store.pending.first, approve: true);
    expect(ok, false);
    expect(store.notice!.isError, true);
    expect(store.notice!.text, 'that time has already passed');
    expect(be.requestCalls, before + 1);
    expect(store.busyRequestId, isNull);
  });

  test('while one decision is being saved, another is ignored', () async {
    be.pending = [req('q1'), req('q2')];
    await store.refreshRequests();
    final first = store.decide(store.pending[0], approve: true);
    final second = await store.decide(store.pending[1], approve: true);
    expect(second, false);
    await first;
    expect(be.decisions.length, 1);
  });

  test('changes are announced to the screens', () async {
    var n = 0;
    final sub = store.changes.listen((_) => n++);
    be.rooms = [room('1', 'LRC-301')];
    await store.refreshRooms();
    await Future<void>.delayed(Duration.zero);
    expect(n >= 1, true);
    await sub.cancel();
  });

  test('start() loads everything, refreshes on its timers, and a request change refreshes the requests at once', () async {
    be.rooms = [room('1', 'LRC-301')];
    be.pending = [req('q1')];
    store.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(store.roomsLoaded && store.requestsLoaded && store.camerasLoaded, true);
    final rooms0 = be.roomCalls;
    final req0 = be.requestCalls;
    await Future<void>.delayed(const Duration(milliseconds: 170));
    expect(be.roomCalls > rooms0, true, reason: 'timer refreshed the rooms');
    expect(be.requestCalls > req0, true, reason: 'timer refreshed the requests');
    store.stop();
    final req1 = be.requestCalls;
    be.changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(be.requestCalls, req1, reason: 'stopped: no more refreshes');
    store.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final req2 = be.requestCalls;
    be.pending = [req('q1'), req('q9')];
    be.changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(be.requestCalls > req2, true);
    expect(store.pending.length, 2);
  });

  test('after dispose nothing is loaded or announced', () async {
    store.dispose();
    await store.refreshRooms();
    expect(be.roomCalls, 0);
  });

  // ------------------------------------------------------------------ the inbox

  test('the inbox loads newest first, and the unread count is the database\'s own count', () async {
    be.inboxRows = [msg('a', minutesAgo: 30), msg('b', minutesAgo: 2), msg('c', minutesAgo: 10, read: true)];
    be.unreadTotal = 7; // more are waiting than the list of 50 holds
    await store.refreshInbox();
    expect(store.inboxLoaded, true);
    expect(store.inbox.map((m) => m.id).toList(), ['b', 'c', 'a']);
    expect(store.unread, 7);
  });

  test('the first load announces nothing; a message that arrives later is announced once, however often the inbox is reloaded', () async {
    be.inboxRows = [msg('old1'), msg('old2')];
    final seen = <String>[];
    final sub = store.arrivals.listen((m) => seen.add(m.id));
    await store.refreshInbox();
    await Future<void>.delayed(Duration.zero);
    expect(seen, isEmpty);
    be.inboxRows = [msg('new1', minutesAgo: 0), ...be.inboxRows];
    await store.refreshInbox();
    await store.refreshInbox();
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['new1']);
    be.inboxRows = [msg('already-read', minutesAgo: 0, read: true), ...be.inboxRows];
    await store.refreshInbox();
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['new1'], reason: 'a message that is already read is not announced');
    await sub.cancel();
  });

  test('several messages that arrive together are announced oldest first, so the newest stays on screen', () async {
    be.inboxRows = [msg('x', minutesAgo: 60, read: true)];
    await store.refreshInbox();
    final seen = <String>[];
    final sub = store.arrivals.listen((m) => seen.add(m.id));
    be.inboxRows = [msg('n3', minutesAgo: 1), msg('n2', minutesAgo: 3), msg('n1', minutesAgo: 9), ...be.inboxRows];
    await store.refreshInbox();
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['n1', 'n2', 'n3']);
    await sub.cancel();
  });

  test('a message marked read changes on screen at once, and the database is told which one', () async {
    be.inboxRows = [msg('a', minutesAgo: 1), msg('b', minutesAgo: 9)];
    await store.refreshInbox();
    expect(store.unread, 2);
    final done = store.markRead(store.inbox.first);
    expect(store.unread, 1, reason: 'before the database has answered');
    expect(store.inbox.where((m) => m.isUnread).length, 1);
    await done;
    expect(be.marks, [['a']]);
    await store.markRead(store.inbox.firstWhere((m) => !m.isUnread));
    expect(be.marks.length, 1, reason: 'a message that is already read is not sent again');
  });

  test('if the database refuses, the screen goes back to what the database says', () async {
    be.inboxRows = [msg('a')];
    await store.refreshInbox();
    be.markError = DbError('offline');
    await store.markRead(store.inbox.first);
    expect(store.unread, 1);
    expect(store.inbox.first.isUnread, true);
  });

  test('mark all read sends no list of ids', () async {
    be.inboxRows = [msg('a'), msg('b'), msg('c', read: true)];
    await store.refreshInbox();
    await store.markAllRead();
    expect(be.marks, [null]);
    expect(store.unread, 0);
    expect(store.inbox.every((m) => !m.isUnread), true);
    await store.markAllRead();
    expect(be.marks.length, 1, reason: 'nothing unread: nothing to send');
  });

  test('a sweep that made messages reloads the inbox and announces them; one that made none does not', () async {
    be.inboxRows = [msg('a', read: true)];
    await store.refreshInbox();
    final seen = <String>[];
    final sub = store.arrivals.listen((m) => seen.add(m.title));
    final calls = be.inboxCalls;
    await store.sweepAlerts();
    expect(be.inboxCalls, calls, reason: 'nothing made, nothing reloaded');
    be.sweepMakes = 1;
    await store.sweepAlerts();
    await Future<void>.delayed(Duration.zero);
    expect(be.inboxCalls, calls + 1);
    expect(seen, ['Key not returned']);
    expect(store.unread, 1);
    await sub.cancel();
  });

  test('start() sweeps at once and then every interval, and a change message reloads the inbox; stop() ends both', () async {
    be.inboxRows = [msg('a', read: true)];
    store.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(be.sweepCalls >= 1, true, reason: 'at once');
    expect(store.inboxLoaded, true);
    final s0 = be.sweepCalls;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(be.sweepCalls > s0, true, reason: 'on the timer');
    final i0 = be.inboxCalls;
    be.inboxRows = [msg('b', minutesAgo: 0), ...be.inboxRows];
    be.inboxFeed.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(be.inboxCalls > i0, true, reason: 'the change feed');
    expect(store.unread, 1);
    store.stop();
    final s1 = be.sweepCalls, i1 = be.inboxCalls;
    be.inboxFeed.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(be.sweepCalls, s1);
    expect(be.inboxCalls, i1);
  });

  test('without database update 12 the inbox says it is unavailable, empties itself and is never asked again', () async {
    be.inboxError = DbError("Could not find the table 'public.notifications' in the schema cache");
    store.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(store.inboxAvailable, false);
    expect(store.inbox, isEmpty);
    expect(store.unread, 0);
    final i0 = be.inboxCalls, s0 = be.sweepCalls;
    await Future<void>.delayed(const Duration(milliseconds: 170));
    expect(be.inboxCalls, i0);
    expect(be.sweepCalls, s0);
    await store.refreshInbox();
    expect(be.inboxCalls, i0);
  });

  test('a missing sweep function alone also switches the inbox off, quietly', () async {
    be.sweepError = DbError('Could not find the function public.sweep_my_alerts() in the schema cache');
    await store.sweepAlerts();
    expect(store.inboxAvailable, false);
  });

  test('any other failure keeps the messages on screen', () async {
    be.inboxRows = [msg('a')];
    await store.refreshInbox();
    be.inboxError = DbError('network is down');
    await store.refreshInbox();
    expect(store.inboxAvailable, true);
    expect(store.inbox.length, 1);
    expect(store.unread, 1);
    be.sweepError = DbError('network is down');
    await store.sweepAlerts();
    expect(store.inboxAvailable, true);
  });

  group('one room\'s week', () {
    test('asks for the meetings of the room and the requests of the week from Monday to Sunday', () async {
      be.meetingRows = [
        const RoomMeeting(id: 'm1', roomId: 'r1', dayOfWeek: 1, startTime: '08:00:00', endTime: '09:30:00', courseCode: 'IT 101'),
        const RoomMeeting(id: 'm2', roomId: 'r2', dayOfWeek: 1, startTime: '08:00:00', endTime: '09:30:00', courseCode: 'IT 102'),
      ];
      be.roomRequestRows = [req('q1', status: 'approved'), req('q2', status: 'approved', roomId: 'r2')];
      final data = await store.loadRoomWeek('r1', DateTime.utc(2026, 11, 9));
      expect(data.meetings.map((m) => m.id).toList(), ['m1']);
      expect(data.requests.map((r) => r.id).toList(), ['q1']);
      expect(be.weekAsked, ['meetings r1', 'requests r1 2026-11-09 2026-11-15']);
    });

    test('a failure is thrown for the screen to word', () async {
      be.weekError = DbError('boom');
      Object? err;
      try {
        await store.loadRoomWeek('r1', DateTime.utc(2026, 11, 9));
      } catch (e) {
        err = e;
      }
      expect(err is DbError, true);
    });
  });
}
