import 'dart:async';

import 'whep.dart';

/// One live viewing of a camera, as far as the keeping-it-connected logic cares.
abstract class FeedSession {
  Future<void> close();
}

/// Starts a viewing: [onLost] is called later if the picture drops after it was up. Throws a
/// [WhepError] that says in words what went wrong. The real one (`lib/data/webrtc_feed.dart`) uses
/// flutter_webrtc; the tests use a fake.
typedef FeedConnect = Future<FeedSession> Function(String token, void Function(String reason) onLost);

enum FeedPhase { connecting, live, problem }

class FeedState {
  const FeedState._(this.phase, this.kind, this.message, this.retrying);

  const FeedState.connecting() : this._(FeedPhase.connecting, null, null, false);
  const FeedState.live() : this._(FeedPhase.live, null, null, false);
  const FeedState.problem(WhepFailure kind, String message, {required bool retrying}) : this._(FeedPhase.problem, kind, message, retrying);

  final FeedPhase phase;
  final WhepFailure? kind;
  final String? message;

  /// true while the app is going to try again by itself
  final bool retrying;
}

/// Keeps one camera's picture connected. After a drop it tries again by itself, waiting a little
/// longer each time ([whepRetryDelay]), and gives up only when the gateway refuses the sign-in
/// (trying again would not help). Same behaviour as the web app's `useCameraFeed`.
class CameraFeed {
  CameraFeed({
    required this.getToken,
    required this.connect,
    required this.onChanged,
    this.retryDelay = whepRetryDelay,
  });

  final Future<String?> Function() getToken;
  final FeedConnect connect;
  final void Function(FeedState state) onChanged;
  final Duration Function(int failures) retryDelay;

  FeedState state = const FeedState.connecting();
  FeedSession? _session;
  Timer? _timer;
  int _failures = 0;
  int _generation = 0;
  bool _stopped = false;

  void _set(FeedState s) {
    state = s;
    if (!_stopped) onChanged(s);
  }

  void start() {
    _stopped = false;
    _try();
  }

  /// "Try again" pressed: forget the waiting and connect now.
  void retryNow() {
    if (_stopped) return;
    _timer?.cancel();
    _failures = 0;
    _try();
  }

  Future<void> stop() async {
    _stopped = true;
    _generation++;
    _timer?.cancel();
    _timer = null;
    final s = _session;
    _session = null;
    if (s != null) {
      try {
        await s.close();
      } catch (_) {
        // closing is best effort
      }
    }
  }

  Future<void> _try() async {
    if (_stopped) return;
    final gen = ++_generation;
    final old = _session;
    _session = null;
    if (old != null) {
      try {
        await old.close();
      } catch (_) {}
    }
    if (_stopped || gen != _generation) return;
    if (state.phase != FeedPhase.live) _set(const FeedState.connecting());
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw WhepError('You are signed out. Sign in again.', WhepFailure.denied);
      }
      final session = await connect(token, (reason) => _lost(gen, reason));
      if (_stopped || gen != _generation) {
        await session.close();
        return;
      }
      _session = session;
      _failures = 0;
      _set(const FeedState.live());
    } catch (err) {
      if (_stopped || gen != _generation) return;
      final e = err is WhepError ? err : WhepError(err.toString(), WhepFailure.media);
      final retrying = e.kind != WhepFailure.denied;
      _set(FeedState.problem(e.kind, e.message, retrying: retrying));
      if (retrying) _later();
    }
  }

  void _lost(int gen, String reason) {
    if (_stopped || gen != _generation) return;
    final s = _session;
    _session = null;
    if (s != null) {
      s.close().catchError((_) {});
    }
    _set(FeedState.problem(WhepFailure.network, 'The picture stopped ($reason).', retrying: true));
    _later();
  }

  void _later() {
    _failures += 1;
    _timer?.cancel();
    _timer = Timer(retryDelay(_failures), _try);
  }
}
