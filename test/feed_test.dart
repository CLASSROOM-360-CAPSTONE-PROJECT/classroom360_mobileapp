import 'dart:async';

import 'package:classroom360_mobile/core/feed.dart';
import 'package:classroom360_mobile/core/whep.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSession implements FeedSession {
  FakeSession(this.onLost);
  final void Function(String) onLost;
  bool closed = false;
  @override
  Future<void> close() async => closed = true;
}

void main() {
  test('the retry pacing is 2, 4, 8, 16 then 30 seconds', () {
    expect([for (var i = 1; i <= 7; i++) whepRetryDelay(i).inSeconds], [2, 4, 8, 16, 30, 30, 30]);
    expect(whepRetryDelay(0).inSeconds, 2);
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

  test('connects, reports live, and closes the session on stop', () async {
    final states = <FeedPhase>[];
    FakeSession? session;
    final feed = CameraFeed(
      getToken: () async => 'tok',
      connect: (token, onLost) async {
        expect(token, 'tok');
        return session = FakeSession(onLost);
      },
      onChanged: (s) => states.add(s.phase),
      retryDelay: (_) => const Duration(milliseconds: 5),
    );
    feed.start();
    await settle();
    expect(states, [FeedPhase.connecting, FeedPhase.live]);
    await feed.stop();
    expect(session!.closed, isTrue);
  });

  test('a signed-out person is told so and it does not keep retrying', () async {
    var tries = 0;
    final feed = CameraFeed(
      getToken: () async => null,
      connect: (token, onLost) async {
        tries++;
        return FakeSession(onLost);
      },
      onChanged: (_) {},
      retryDelay: (_) => const Duration(milliseconds: 5),
    );
    feed.start();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(tries, 0);
    expect(feed.state.phase, FeedPhase.problem);
    expect(feed.state.kind, WhepFailure.denied);
    expect(feed.state.retrying, isFalse);
    await feed.stop();
  });

  test('a refused sign-in at the gateway does not retry; an offline camera does', () async {
    var tries = 0;
    WhepFailure next = WhepFailure.denied;
    final feed = CameraFeed(
      getToken: () async => 'tok',
      connect: (token, onLost) async {
        tries++;
        throw WhepError('x', next);
      },
      onChanged: (_) {},
      retryDelay: (_) => const Duration(milliseconds: 5),
    );
    feed.start();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(tries, 1);
    expect(feed.state.retrying, isFalse);
    await feed.stop();

    tries = 0;
    next = WhepFailure.offline;
    final feed2 = CameraFeed(
      getToken: () async => 'tok',
      connect: (token, onLost) async {
        tries++;
        throw WhepError('This camera is not sending video right now.', next);
      },
      onChanged: (_) {},
      retryDelay: (_) => const Duration(milliseconds: 5),
    );
    feed2.start();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(tries, greaterThan(2));
    expect(feed2.state.retrying, isTrue);
    expect(feed2.state.kind, WhepFailure.offline);
    await feed2.stop();
  });

  test('a dropped picture closes the old session and connects again', () async {
    final sessions = <FakeSession>[];
    final feed = CameraFeed(
      getToken: () async => 'tok',
      connect: (token, onLost) async {
        final s = FakeSession(onLost);
        sessions.add(s);
        return s;
      },
      onChanged: (_) {},
      retryDelay: (_) => const Duration(milliseconds: 5),
    );
    feed.start();
    await settle();
    expect(feed.state.phase, FeedPhase.live);
    sessions.first.onLost('failed');
    expect(feed.state.phase, FeedPhase.problem);
    expect(feed.state.message, 'The picture stopped (failed).');
    expect(feed.state.retrying, isTrue);
    await settle();
    expect(sessions.first.closed, isTrue);
    expect(sessions.length, 2);
    expect(feed.state.phase, FeedPhase.live);
    await feed.stop();
    expect(sessions.last.closed, isTrue);
  });

  test('a late "lost" from an old session is ignored', () async {
    final sessions = <FakeSession>[];
    final feed = CameraFeed(
      getToken: () async => 'tok',
      connect: (token, onLost) async {
        final s = FakeSession(onLost);
        sessions.add(s);
        return s;
      },
      onChanged: (_) {},
      retryDelay: (_) => const Duration(milliseconds: 5),
    );
    feed.start();
    await settle();
    sessions.first.onLost('failed');
    await settle();
    expect(sessions.length, 2);
    sessions.first.onLost('disconnected'); // the first one reports again after it was replaced
    await settle();
    expect(sessions.length, 2);
    expect(feed.state.phase, FeedPhase.live);
    await feed.stop();
  });

  test('stopping while a connection is still being made closes it when it arrives', () async {
    final gate = Completer<void>();
    FakeSession? made;
    final feed = CameraFeed(
      getToken: () async => 'tok',
      connect: (token, onLost) async {
        await gate.future;
        return made = FakeSession(onLost);
      },
      onChanged: (_) {},
    );
    feed.start();
    await settle();
    await feed.stop();
    gate.complete();
    await settle();
    expect(made!.closed, isTrue);
  });

  test('retryNow connects at once and starts the pacing over', () async {
    var tries = 0;
    final delays = <int>[];
    final feed = CameraFeed(
      getToken: () async => 'tok',
      connect: (token, onLost) async {
        tries++;
        if (tries < 3) throw WhepError('down', WhepFailure.network);
        return FakeSession(onLost);
      },
      onChanged: (_) {},
      retryDelay: (n) {
        delays.add(n);
        return const Duration(milliseconds: 400);
      },
    );
    feed.start();
    await settle();
    expect(tries, 1);
    expect(delays, [1]);
    feed.retryNow(); // fails again: the pacing restarted from 1
    await settle();
    expect(tries, 2);
    expect(delays, [1, 1]);
    feed.retryNow();
    await settle();
    expect(tries, 3);
    expect(feed.state.phase, FeedPhase.live);
    await feed.stop();
  });
}
