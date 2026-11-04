import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/feed.dart';
import '../core/whep.dart';

/// One WebRTC viewing of a camera through the gateway's WHEP address. The HTTP part is
/// `core/whep.dart`; this file only drives the phone's WebRTC engine (flutter_webrtc).
class WebRtcFeedSession implements FeedSession {
  WebRtcFeedSession._(this._pc, this.stream, this._resourceUrl, this._token);

  final RTCPeerConnection _pc;

  /// the picture, to hand to an RTCVideoRenderer
  final MediaStream stream;
  final String? _resourceUrl;
  final String _token;
  bool _closed = false;

  bool get isClosed => _closed;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pc.onConnectionState = null;
    await closeWhepSession(_resourceUrl, _token);
    try {
      await _pc.close();
    } catch (_) {
      // already closed
    }
  }

  /// Makes the offer, posts it to the gateway, plays the answer, and waits for the first picture.
  /// Throws a [WhepError] that says in words what went wrong. [onLost] is called if the connection
  /// drops after the picture was up.
  static Future<WebRtcFeedSession> connect(
    String url,
    String token,
    void Function(String reason) onLost, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    // No STUN or TURN servers: the cameras are on the school network, and nothing here should
    // contact an outside server.
    final pc = await createPeerConnection(<String, dynamic>{
      'iceServers': <Map<String, dynamic>>[],
      'sdpSemantics': 'unified-plan',
    });
    String? resource;
    Future<Never> fail(WhepError e) async {
      if (resource != null) await closeWhepSession(resource, token);
      try {
        await pc.close();
      } catch (_) {}
      throw e;
    }

    try {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      final firstStream = Completer<MediaStream>();
      pc.onTrack = (RTCTrackEvent e) async {
        if (firstStream.isCompleted) return;
        if (e.streams.isNotEmpty) {
          firstStream.complete(e.streams.first);
        } else {
          final s = await createLocalMediaStream('camera');
          await s.addTrack(e.track);
          if (!firstStream.isCompleted) firstStream.complete(s);
        }
      };

      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await _waitForIce(pc, const Duration(milliseconds: 2500));
      final local = await pc.getLocalDescription();
      final offerSdp = local?.sdp;
      if (offerSdp == null || offerSdp.isEmpty) {
        await fail(WhepError('The video could not be started.', WhepFailure.media));
      }

      final WhepAnswer answer;
      try {
        answer = await postWhepOffer(url, token, offerSdp, timeout: timeout);
      } on WhepError catch (e) {
        await fail(e);
      }
      resource = answer.resourceUrl;
      await pc.setRemoteDescription(RTCSessionDescription(answer.sdp, 'answer'));

      final MediaStream stream;
      try {
        stream = await firstStream.future.timeout(timeout);
      } on TimeoutException {
        await fail(WhepError('No picture arrived.', WhepFailure.timeout));
      }

      final session = WebRtcFeedSession._(pc, stream, resource, token);
      pc.onConnectionState = (RTCPeerConnectionState state) {
        if (session._closed) return;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          onLost(state.name.replaceFirst('RTCPeerConnectionState', '').toLowerCase());
        }
      };
      return session;
    } on WhepError {
      rethrow;
    } catch (err) {
      return fail(WhepError(err.toString(), WhepFailure.media));
    }
  }

  static Future<void> _waitForIce(RTCPeerConnection pc, Duration limit) {
    if (pc.iceGatheringState == RTCIceGatheringState.RTCIceGatheringStateComplete) return Future<void>.value();
    final done = Completer<void>();
    pc.onIceGatheringState = (RTCIceGatheringState s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete && !done.isCompleted) done.complete();
    };
    return done.future.timeout(limit, onTimeout: () {});
  }
}
