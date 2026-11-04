import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// WHEP is the standard way to play a WebRTC stream from a server. The parent Raspberry Pi
/// (`pi/camera-gateway`) offers each camera that way. The signed-in person's access token goes in the
/// Authorization header and the gateway asks Supabase whether that person may watch before it sends
/// any video. This file only does the HTTP part (post the phone's offer, read the server's answer);
/// the phone's WebRTC engine (`flutter_webrtc`) makes the offer and plays the answer.

enum WhepFailure { denied, offline, network, timeout, media }

class WhepError implements Exception {
  WhepError(this.message, this.kind);

  final String message;
  final WhepFailure kind;

  @override
  String toString() => message;
}

/// The WHEP address of a stream on a gateway: http://192.168.1.50:8889 + lrc-301.
String whepUrl(String gatewayUrl, String streamPath) {
  final base = gatewayUrl.replaceAll(RegExp(r'/+$'), '');
  final path = streamPath.replaceAll(RegExp(r'^/+|/+$'), '');
  return '$base/$path/whep';
}

class WhepAnswer {
  const WhepAnswer(this.sdp, this.resourceUrl);

  /// the server's answer (SDP text) to hand to the WebRTC engine
  final String sdp;

  /// the address to DELETE when the viewing ends, if the server gave one
  final String? resourceUrl;
}

/// Posts the offer and returns the answer, or throws a [WhepError] that says in words what went wrong.
Future<WhepAnswer> postWhepOffer(
  String url,
  String token,
  String offerSdp, {
  Duration timeout = const Duration(seconds: 12),
  HttpClient? client,
}) async {
  final http = client ?? HttpClient();
  http.connectionTimeout = timeout;
  try {
    final uri = Uri.parse(url);
    final req = await http.postUrl(uri).timeout(timeout);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/sdp');
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final body = utf8.encode(offerSdp);
    req.contentLength = body.length;
    req.add(body);
    final res = await req.close().timeout(timeout);
    final text = await res.transform(utf8.decoder).join().timeout(timeout);

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw WhepError('The camera gateway did not accept your sign-in.', WhepFailure.denied);
    }
    if (res.statusCode == 404) {
      throw WhepError('This camera is not sending video right now.', WhepFailure.offline);
    }
    if (res.statusCode == 400 && text.contains('not configured')) {
      // MediaMTX answers this for a stream name that is not in its settings file (before it asks who is watching)
      throw WhepError('The camera gateway has no stream with this name. Ask an administrator to check the stream name for this camera.', WhepFailure.offline);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw WhepError('The camera gateway answered ${res.statusCode}.', WhepFailure.network);
    }
    if (text.trim().isEmpty) {
      throw WhepError('The camera gateway sent an empty answer.', WhepFailure.media);
    }
    final location = res.headers.value(HttpHeaders.locationHeader);
    return WhepAnswer(text, location == null ? null : uri.resolve(location).toString());
  } on WhepError {
    rethrow;
  } on TimeoutException {
    throw WhepError('The camera gateway did not answer in time.', WhepFailure.timeout);
  } on SocketException {
    throw WhepError('The camera gateway could not be reached. Check its address and that the Raspberry Pi is switched on.', WhepFailure.network);
  } on HttpException {
    throw WhepError('The camera gateway could not be reached. Check its address and that the Raspberry Pi is switched on.', WhepFailure.network);
  } on FormatException {
    throw WhepError('The camera address is not valid.', WhepFailure.network);
  } finally {
    if (client == null) http.close(force: true);
  }
}

/// Tells the gateway the viewing has ended so it can free the connection. Never throws.
Future<void> closeWhepSession(String? resourceUrl, String token, {HttpClient? client}) async {
  if (resourceUrl == null) return;
  final http = client ?? HttpClient();
  try {
    final req = await http.deleteUrl(Uri.parse(resourceUrl)).timeout(const Duration(seconds: 4));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final res = await req.close().timeout(const Duration(seconds: 4));
    await res.drain<void>();
  } catch (_) {
    // the gateway also drops a connection that goes quiet
  } finally {
    if (client == null) http.close(force: true);
  }
}

/// How long to wait before trying a camera again: 2 s, 4 s, 8 s, 16 s, then 30 s. [failures] counts
/// the failed tries in a row, starting at 1. (Same pacing as the web app.)
Duration whepRetryDelay(int failures) {
  final n = failures < 1 ? 1 : failures;
  final seconds = 2 * (1 << (n - 1 > 4 ? 4 : n - 1));
  return Duration(seconds: seconds > 30 ? 30 : seconds);
}
