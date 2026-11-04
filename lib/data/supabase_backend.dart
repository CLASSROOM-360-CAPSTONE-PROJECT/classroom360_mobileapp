import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models.dart';
import '../core/store.dart';

/// The real [Backend]: the same Supabase project, tables, views and functions the web app uses
/// (compare `web/src/pages/Requests.tsx`, `Dashboard.tsx`, `Cameras.tsx`). Row-level security in
/// the database decides what the signed-in person may read; nothing is filtered here.
class SupabaseBackend implements Backend {
  SupabaseBackend(this.client);

  final SupabaseClient client;

  static const _requestColumns =
      'id, instructor_id, room_id, requested_for, start_time, end_time, reason, status, decided_at, decision_note, created_at, instructors(full_name), rooms(code, name)';

  List<Map<String, dynamic>> _rows(Object? data) => (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Future<Profile?> loadProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from('profiles')
        .select('id, tenant_id, role, full_name, email, department_id, tenants(name, timezone)')
        .eq('id', user.id)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<RoomStatus>> roomStatus() async {
    final data = await client.from('room_status_now').select().order('room_code');
    return _rows(data).map(RoomStatus.fromJson).toList();
  }

  @override
  Future<List<LockerStatus>> lockerStatus() async {
    final data = await client.from('locker_status').select().order('compartment_no');
    return _rows(data).map(LockerStatus.fromJson).toList();
  }

  @override
  Future<List<RoomRequest>> pendingRequests() async {
    final data = await client
        .from('room_requests')
        .select(_requestColumns)
        .eq('status', 'pending')
        .order('requested_for')
        .order('start_time');
    return _rows(data).map(RoomRequest.fromJson).toList();
  }

  @override
  Future<List<RoomRequest>> decidedRequests() async {
    final data = await client
        .from('room_requests')
        .select(_requestColumns)
        .neq('status', 'pending')
        .order('decided_at', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false)
        .limit(30);
    return _rows(data).map(RoomRequest.fromJson).toList();
  }

  @override
  Future<List<CameraRow>> cameras() async {
    final data = await client
        .from('cameras')
        .select('id, room_id, label, gateway_url, stream_path, is_active, rooms(code, name)')
        .order('created_at');
    return _rows(data).map(CameraRow.fromJson).toList();
  }

  @override
  Future<void> decideRequest(String requestId, {required bool approve, String? note}) async {
    await client.rpc('decide_room_request', params: {
      'p_request_id': requestId,
      'p_approve': approve,
      'p_note': note,
    });
  }

  /// One realtime channel on `room_requests`, opened while somebody listens. Row-level security
  /// applies to realtime too, so only changes this person may read arrive.
  @override
  Stream<void> requestChanges() {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>.broadcast(
      onListen: () {
        channel = client
            .channel('classroom360-mobile-requests')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'room_requests',
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe();
      },
      onCancel: () async {
        final c = channel;
        channel = null;
        if (c != null) await client.removeChannel(c);
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }

  static const _inboxColumns = 'id, kind, severity, title, body, link, created_at, read_at';

  @override
  Future<List<InboxMessage>> inbox() async {
    final data = await client.from('notifications').select(_inboxColumns).order('created_at', ascending: false).order('id').limit(50);
    return _rows(data).map(InboxMessage.fromJson).toList();
  }

  @override
  Future<int> unreadCount() => client.from('notifications').count(CountOption.exact).isFilter('read_at', null);

  @override
  Future<void> markRead(List<String>? ids) async {
    await client.rpc('mark_notifications_read', params: ids == null ? <String, dynamic>{} : {'p_ids': ids});
  }

  @override
  Future<int> sweepAlerts() async {
    final made = await client.rpc('sweep_my_alerts');
    return made is num ? made.toInt() : 0;
  }

  /// One realtime channel on the person's own `notifications` rows (insert and update), opened while somebody listens.
  @override
  Stream<void> inboxChanges() {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>.broadcast(
      onListen: () {
        final uid = client.auth.currentUser?.id;
        if (uid == null) return;
        channel = client
            .channel('classroom360-mobile-inbox-$uid')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe();
      },
      onCancel: () async {
        final c = channel;
        channel = null;
        if (c != null) await client.removeChannel(c);
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }

  @override
  Future<List<RoomMeeting>> roomMeetings(String roomId) async {
    // the term's dates come with each row so the app can tell whether a meeting happens in a given week
    final data = await client
        .from('schedule_entries')
        .select('id, room_id, day_of_week, start_time, end_time, sections(code, courses(code, title)), instructors(full_name), terms(starts_on, ends_on)')
        .eq('room_id', roomId)
        .eq('status', 'published')
        .order('day_of_week')
        .order('start_time');
    return _rows(data).map(RoomMeeting.fromJson).toList();
  }

  @override
  Future<List<RoomRequest>> roomRequests(String roomId, String fromYmd, String toYmd) async {
    final data = await client
        .from('room_requests')
        .select(_requestColumns)
        .eq('room_id', roomId)
        .inFilter('status', ['pending', 'approved'])
        .gte('requested_for', fromYmd)
        .lte('requested_for', toYmd)
        .order('requested_for')
        .order('start_time');
    return _rows(data).map(RoomRequest.fromJson).toList();
  }

  /// The access token for the camera gateway. If it is about to run out, ask for a fresh one first.
  @override
  Future<String?> accessToken() async {
    final session = client.auth.currentSession;
    if (session == null) return null;
    final expiresAt = session.expiresAt; // seconds since 1970
    if (expiresAt != null) {
      final left = expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (left < 60) {
        try {
          final refreshed = await client.auth.refreshSession();
          return refreshed.session?.accessToken ?? session.accessToken;
        } catch (_) {
          return session.accessToken;
        }
      }
    }
    return session.accessToken;
  }
}
