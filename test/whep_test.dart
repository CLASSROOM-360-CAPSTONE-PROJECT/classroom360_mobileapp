import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:classroom360_mobile/core/whep.dart';
import 'package:flutter_test/flutter_test.dart';

class Seen {
  String? method, path, contentType, auth, body;
}

/// A tiny gateway: answers each request with whatever `reply` says.
Future<(HttpServer, Seen)> gateway(Future<void> Function(HttpRequest, Seen) reply) async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  final seen = Seen();
  server.listen((req) async {
    seen.method = req.method;
    seen.path = req.uri.path;
    seen.contentType = req.headers.contentType?.mimeType;
    seen.auth = req.headers.value('authorization');
    seen.body = await utf8.decoder.bind(req).join();
    await reply(req, seen);
  });
  return (server, seen);
}

Future<WhepError> failure(Future<void> Function() run) async {
  try {
    await run();
  } on WhepError catch (e) {
    return e;
  }
  throw TestFailure('expected a WhepError');
}

void main() {
  test('posts the offer as application/sdp with the bearer token and returns the answer and the session address', () async {
    final (server, seen) = await gateway((req, _) async {
      req.response
        ..statusCode = 201
        ..headers.set('Location', '/lrc-301/whep/abc-123')
        ..headers.contentType = ContentType('application', 'sdp');
      req.response.write('v=0\r\nanswer\r\n');
      await req.response.close();
    });
    final base = 'http://127.0.0.1:${server.port}';
    final a = await postWhepOffer(whepUrl(base, 'lrc-301'), 'tok-123', 'v=0\r\noffer\r\n');
    expect(seen.method, 'POST');
    expect(seen.path, '/lrc-301/whep');
    expect(seen.contentType, 'application/sdp');
    expect(seen.auth, 'Bearer tok-123');
    expect(seen.body, 'v=0\r\noffer\r\n');
    expect(a.sdp, 'v=0\r\nanswer\r\n');
    expect(a.resourceUrl, '$base/lrc-301/whep/abc-123');
    await server.close(force: true);
  });

  test('401 and 403 mean the gateway does not accept the sign-in', () async {
    for (final code in [401, 403]) {
      final (server, _) = await gateway((req, _) async {
        req.response.statusCode = code;
        await req.response.close();
      });
      final e = await failure(() => postWhepOffer('http://127.0.0.1:${server.port}/x/whep', 't', 'offer'));
      expect(e.kind, WhepFailure.denied, reason: '$code');
      expect(e.message, 'The camera gateway did not accept your sign-in.');
      await server.close(force: true);
    }
  });

  test('404 means the camera is not sending', () async {
    final (server, _) = await gateway((req, _) async {
      req.response.statusCode = 404;
      await req.response.close();
    });
    final e = await failure(() => postWhepOffer('http://127.0.0.1:${server.port}/x/whep', 't', 'offer'));
    expect(e.kind, WhepFailure.offline);
    await server.close(force: true);
  });

  test('another status, and an empty answer', () async {
    var code = 500;
    final (server, _) = await gateway((req, _) async {
      req.response.statusCode = code;
      await req.response.close();
    });
    var e = await failure(() => postWhepOffer('http://127.0.0.1:${server.port}/x/whep', 't', 'offer'));
    expect(e.kind, WhepFailure.network);
    expect(e.message, 'The camera gateway answered 500.');
    code = 201;
    e = await failure(() => postWhepOffer('http://127.0.0.1:${server.port}/x/whep', 't', 'offer'));
    expect(e.kind, WhepFailure.media);
    await server.close(force: true);
  });

  test('a stream name the gateway has not been set up for is explained, other 400s are not', () async {
    var body = '{"error":"path \'lrc-999\' is not configured"}';
    final (server, _) = await gateway((req, _) async {
      req.response.statusCode = 400;
      req.response.write(body);
      await req.response.close();
    });
    var e = await failure(() => postWhepOffer('http://127.0.0.1:${server.port}/lrc-999/whep', 't', 'offer'));
    expect(e.kind, WhepFailure.offline);
    expect(e.message, contains('no stream with this name'));
    body = '{"error":"bad sdp"}';
    e = await failure(() => postWhepOffer('http://127.0.0.1:${server.port}/lrc-999/whep', 't', 'offer'));
    expect(e.kind, WhepFailure.network);
    expect(e.message, 'The camera gateway answered 400.');
    await server.close(force: true);
  });

  test('a gateway that does not answer in time', () async {
    final (server, _) = await gateway((req, _) async {
      await Future<void>.delayed(const Duration(seconds: 3));
      try {
        await req.response.close();
      } catch (_) {}
    });
    final e = await failure(() => postWhepOffer('http://127.0.0.1:${server.port}/x/whep', 't', 'offer', timeout: const Duration(milliseconds: 300)));
    expect(e.kind, WhepFailure.timeout);
    await server.close(force: true);
  });

  test('a gateway that is switched off, and a nonsense address', () async {
    final probe = await HttpServer.bind('127.0.0.1', 0);
    final port = probe.port;
    await probe.close(force: true);
    var e = await failure(() => postWhepOffer('http://127.0.0.1:$port/x/whep', 't', 'offer'));
    expect(e.kind, WhepFailure.network);
    expect(e.message.contains('could not be reached'), true);
    e = await failure(() => postWhepOffer('http://exa mple/x', 't', 'offer'));
    expect(e.kind, WhepFailure.network);
  });

  test('ending the session sends DELETE with the token, and a failure is swallowed', () async {
    final (server, seen) = await gateway((req, _) async {
      req.response.statusCode = 200;
      await req.response.close();
    });
    await closeWhepSession('http://127.0.0.1:${server.port}/x/whep/abc', 'tok');
    expect(seen.method, 'DELETE');
    expect(seen.path, '/x/whep/abc');
    expect(seen.auth, 'Bearer tok');
    await server.close(force: true);
    await closeWhepSession('http://127.0.0.1:1/x/whep/abc', 'tok'); // nothing there: must not throw
    await closeWhepSession(null, 'tok');
  });
}
