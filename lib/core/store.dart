import 'dart:async';

import 'errors.dart';
import 'inbox.dart';
import 'models.dart';
import 'presence.dart';
import 'room_week.dart';

/// Everything the app reads from, or asks of, the database. The real one is in `lib/data/`
/// (supabase_flutter); the tests use a fake. Row-level security in the database decides what each
/// signed-in person gets; the app does no filtering of its own.
abstract class Backend {
  Future<Profile?> loadProfile();

  /// view `room_status_now`
  Future<List<RoomStatus>> roomStatus();

  /// view `locker_status`
  Future<List<LockerStatus>> lockerStatus();

  /// requests waiting for a decision, soonest first
  Future<List<RoomRequest>> pendingRequests();

  /// the last decisions, newest first
  Future<List<RoomRequest>> decidedRequests();
  Future<List<CameraRow>> cameras();

  /// RPC `decide_room_request` (dean or administrator; a note is required to reject)
  Future<void> decideRequest(String requestId, {required bool approve, String? note});

  /// fires when a room request is added or changed anywhere
  Stream<void> requestChanges();

  /// the access token to show the camera gateway; refreshed when it is about to expire
  Future<String?> accessToken();

  /// the latest messages of the signed-in person, newest first (table `notifications`, database update 12)
  Future<List<InboxMessage>> inbox();

  /// how many of their messages are still unread
  Future<int> unreadCount();

  /// marks the given messages read, or all of them when [ids] is null
  Future<void> markRead(List<String>? ids);

  /// RPC `sweep_my_alerts`: asks the database to turn the alerts that have no event of their own (a key left out, a silent
  /// locker) into messages; returns how many it made. At most one sweep per school runs every 20 seconds.
  Future<int> sweepAlerts();

  /// fires when one of the person's messages is added or changed
  Stream<void> inboxChanges();

  /// the published class meetings of one room, every weekday (table `schedule_entries`, each with its term's dates)
  Future<List<RoomMeeting>> roomMeetings(String roomId);

  /// the requests for one room that are still waiting or already approved, for days from [fromYmd] to [toYmd] inclusive
  /// (table `room_requests`)
  Future<List<RoomRequest>> roomRequests(String roomId, String fromYmd, String toYmd);
}

/// Everything that goes on one room's timetable for a week.
class RoomWeekData {
  const RoomWeekData({required this.meetings, required this.requests});

  final List<RoomMeeting> meetings;
  final List<RoomRequest> requests;
}

class Notice {
  const Notice(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

/// The app's data: it loads, keeps the latest good copy when a load fails, refreshes by itself while
/// running, and tells the screens (through [changes]) when anything changed.
class AppStore {
  AppStore(
    this.backend, {
    this.roomsEvery = const Duration(seconds: 15),
    this.requestsEvery = const Duration(seconds: 30),
    this.sweepEvery = const Duration(seconds: 60),
    this.timezone,
  });

  final Backend backend;

  /// the school's time zone (for example 'Asia/Manila'): "now" on a room's timetable is the school's clock, not the phone's
  final String? timezone;
  final Duration roomsEvery;
  final Duration requestsEvery;
  final Duration sweepEvery;

  List<RoomStatus> rooms = const [];
  List<LockerStatus> lockers = const [];
  List<CameraRow> cameras = const [];
  List<RoomRequest> pending = const [];
  List<RoomRequest> decided = const [];

  /// the person's messages, newest first, and how many are unread (a count of its own: more can be waiting than the list holds)
  List<InboxMessage> inbox = const [];
  int unread = 0;
  bool inboxLoaded = false;

  /// false once the database says it has no inbox (update 12 not run yet): the bell is then hidden and nothing is asked again
  bool inboxAvailable = true;

  bool roomsLoaded = false;
  bool requestsLoaded = false;
  bool camerasLoaded = false;
  String? roomsError;
  String? requestsError;
  String? camerasError;

  /// the request being decided right now
  String? busyRequestId;
  Notice? notice;

  final StreamController<int> _changes = StreamController<int>.broadcast();
  int _version = 0;
  Timer? _roomsTimer;
  Timer? _requestsTimer;
  Timer? _sweepTimer;
  StreamSubscription<void>? _requestSub;
  StreamSubscription<void>? _inboxSub;
  final StreamController<InboxMessage> _arrivals = StreamController<InboxMessage>.broadcast();
  final Set<String> _announced = <String>{};
  bool _inboxInFlight = false;
  bool _sweepInFlight = false;
  bool _roomsInFlight = false;
  bool _requestsInFlight = false;
  bool _camerasInFlight = false;
  bool _disposed = false;

  Stream<int> get changes => _changes.stream;
  int get version => _version;

  /// each unread message once, the first time the app sees it after the first load (the screen shows a banner)
  Stream<InboxMessage> get arrivals => _arrivals.stream;

  void _changed() {
    if (_disposed) return;
    _version++;
    _changes.add(_version);
  }

  // ------------------------------------------------------------------ what the screens show

  /// rooms that need a person to look at them first, then the others, each group by room code
  List<RoomStatus> get sortedRooms {
    final list = [...rooms];
    list.sort((a, b) {
      final na = needsAttention(a) ? 0 : 1;
      final nb = needsAttention(b) ? 0 : 1;
      if (na != nb) return na - nb;
      return a.roomCode.compareTo(b.roomCode);
    });
    return list;
  }

  int get attentionCount => rooms.where(needsAttention).length;

  LockerStatus? lockerForRoom(String roomId) {
    for (final l in lockers) {
      if (l.roomId == roomId) return l;
    }
    return null;
  }

  /// the active cameras, by room code and then label
  List<CameraRow> get activeCameras {
    final list = cameras.where((c) => c.isActive).toList();
    list.sort((a, b) {
      final byRoom = (a.roomCode ?? '').compareTo(b.roomCode ?? '');
      return byRoom != 0 ? byRoom : a.label.compareTo(b.label);
    });
    return list;
  }

  CameraRow? cameraForRoom(String roomId) {
    for (final c in activeCameras) {
      if (c.roomId == roomId) return c;
    }
    return null;
  }

  RoomStatus? roomById(String roomId) {
    for (final r in rooms) {
      if (r.roomId == roomId) return r;
    }
    return null;
  }

  /// the clock at the school right now
  SchoolClock get clock => schoolClock(timezone);

  // ------------------------------------------------------------------ one room's week

  /// What goes on one room's timetable in the week that starts on [monday]: its class meetings and its requests.
  /// A failure is thrown for the screen to word; nothing is kept here, so every call reads the database again.
  Future<RoomWeekData> loadRoomWeek(String roomId, DateTime monday) async {
    final from = ymdOf(monday);
    final to = ymdOf(addDaysTo(monday, 6));
    final results = await Future.wait<Object>([backend.roomMeetings(roomId), backend.roomRequests(roomId, from, to)]);
    return RoomWeekData(meetings: results[0] as List<RoomMeeting>, requests: results[1] as List<RoomRequest>);
  }

  // ------------------------------------------------------------------ loading

  Future<void> refreshRooms() async {
    if (_roomsInFlight || _disposed) return;
    _roomsInFlight = true;
    try {
      final results = await Future.wait<Object>([backend.roomStatus(), backend.lockerStatus()]);
      rooms = results[0] as List<RoomStatus>;
      lockers = results[1] as List<LockerStatus>;
      roomsError = null;
    } catch (err) {
      roomsError = friendlyError(err, 'The rooms could not be loaded.');
    } finally {
      _roomsInFlight = false;
      roomsLoaded = true;
      _changed();
    }
  }

  Future<void> refreshRequests() async {
    if (_requestsInFlight || _disposed) return;
    _requestsInFlight = true;
    try {
      final results = await Future.wait<List<RoomRequest>>([backend.pendingRequests(), backend.decidedRequests()]);
      pending = results[0];
      decided = results[1];
      requestsError = null;
    } catch (err) {
      requestsError = friendlyError(err, 'The requests could not be loaded.');
    } finally {
      _requestsInFlight = false;
      requestsLoaded = true;
      _changed();
    }
  }

  Future<void> refreshCameras() async {
    if (_camerasInFlight || _disposed) return;
    _camerasInFlight = true;
    try {
      cameras = await backend.cameras();
      camerasError = null;
    } catch (err) {
      camerasError = friendlyError(err, 'The cameras could not be loaded.');
    } finally {
      _camerasInFlight = false;
      camerasLoaded = true;
      _changed();
    }
  }

  /// Loads the inbox. The first load only learns what is already there; after that every unread message that was not seen
  /// before is announced once on [arrivals], whether it came by the change feed or by the timer.
  Future<void> refreshInbox() async {
    if (_inboxInFlight || _disposed || !inboxAvailable) return;
    _inboxInFlight = true;
    try {
      final results = await Future.wait<Object>([backend.inbox(), backend.unreadCount()]);
      final list = newestFirst(results[0] as List<InboxMessage>);
      final first = !inboxLoaded;
      final fresh = <InboxMessage>[];
      for (final m in list) {
        if (_announced.add(m.id) && !first && m.isUnread) fresh.add(m);
      }
      inbox = list;
      unread = results[1] as int;
      inboxLoaded = true;
      if (!_disposed) {
        for (final m in fresh.reversed) {
          _arrivals.add(m); // oldest first, so the newest is the one left on the screen
        }
      }
    } catch (err) {
      if (isMissingMigration(err)) {
        inboxAvailable = false;
        inbox = const [];
        unread = 0;
        _stopInbox();
      }
      // any other failure: keep what is shown; the next timer or change tries again
    } finally {
      _inboxInFlight = false;
      _changed();
    }
  }

  /// Marks one message read at once on the screen, then in the database; a failure puts the database's truth back.
  Future<void> markRead(InboxMessage m) async {
    if (!m.isUnread || !inboxAvailable) return;
    final now = DateTime.now();
    inbox = [for (final x in inbox) x.id == m.id ? x.markedRead(now) : x];
    unread = unread > 0 ? unread - 1 : 0;
    _changed();
    try {
      await backend.markRead([m.id]);
    } catch (_) {
      await refreshInbox();
    }
  }

  Future<void> markAllRead() async {
    if (unread == 0 || !inboxAvailable) return;
    final now = DateTime.now();
    inbox = [for (final x in inbox) x.markedRead(now)];
    unread = 0;
    _changed();
    try {
      await backend.markRead(null);
    } catch (_) {
      await refreshInbox();
    }
  }

  /// Asks the database to make messages out of the alerts, then reloads the inbox if it made any.
  Future<void> sweepAlerts() async {
    if (_sweepInFlight || _disposed || !inboxAvailable) return;
    _sweepInFlight = true;
    try {
      final made = await backend.sweepAlerts();
      if (made > 0) await refreshInbox();
    } catch (err) {
      if (isMissingMigration(err)) {
        inboxAvailable = false;
        _stopInbox();
        _changed();
      }
    } finally {
      _sweepInFlight = false;
    }
  }

  void _stopInbox() {
    _sweepTimer?.cancel();
    _inboxSub?.cancel();
    _sweepTimer = null;
    _inboxSub = null;
  }

  Future<void> refreshAll() => Future.wait<void>([refreshRooms(), refreshRequests(), refreshCameras(), refreshInbox()]);

  /// Loads everything and keeps it fresh until [stop]. A new or changed request is picked up at once
  /// (database change feed); the timers cover a missed message.
  void start() {
    stop();
    refreshAll();
    _roomsTimer = Timer.periodic(roomsEvery, (_) {
      refreshRooms();
      refreshCameras();
    });
    _requestsTimer = Timer.periodic(requestsEvery, (_) => refreshRequests());
    _requestSub = backend.requestChanges().listen((_) => refreshRequests(), onError: (_) {});
    if (inboxAvailable) {
      unawaited(sweepAlerts());
      _sweepTimer = Timer.periodic(sweepEvery, (_) {
        sweepAlerts();
        refreshInbox(); // the timer also covers a change message that never arrived
      });
      _inboxSub = backend.inboxChanges().listen((_) => refreshInbox(), onError: (_) {});
    }
  }

  void stop() {
    _roomsTimer?.cancel();
    _requestsTimer?.cancel();
    _requestSub?.cancel();
    _roomsTimer = _requestsTimer = null;
    _requestSub = null;
    _stopInbox();
  }

  void dispose() {
    stop();
    _disposed = true;
    _changes.close();
    _arrivals.close();
  }

  // ------------------------------------------------------------------ deciding a request

  void clearNotice() {
    if (notice == null) return;
    notice = null;
    _changed();
  }

  /// Accepts or rejects a request. A rejection needs a note (the instructor sees it).
  /// Returns true when the database accepted the decision.
  Future<bool> decide(RoomRequest r, {required bool approve, String? note}) async {
    if (busyRequestId != null) return false;
    final text = note?.trim() ?? '';
    if (!approve && text.isEmpty) {
      notice = const Notice('Write a short reason; the instructor will see it.', isError: true);
      _changed();
      return false;
    }
    busyRequestId = r.id;
    notice = null;
    _changed();
    var ok = false;
    try {
      await backend.decideRequest(r.id, approve: approve, note: approve ? null : text);
      notice = Notice(approve
          ? 'Approved. The room key will open for the instructor during that time.'
          : 'Rejected. The instructor can see your note.');
      ok = true;
    } catch (err) {
      notice = Notice(friendlyError(err, 'The decision was not saved.'), isError: true);
    } finally {
      busyRequestId = null;
    }
    _changed();
    await refreshRequests(); // also after a refusal: the request may have changed under us
    if (ok) unawaited(refreshRooms());
    return ok;
  }
}
