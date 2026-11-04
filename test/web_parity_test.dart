// The mobile app must word things exactly as the web app does. The fixture holds what the web app's
// own helpers answered (made by tool/make_parity_fixture.mjs from web/src).
import 'dart:convert';
import 'dart:io';

import 'package:classroom360_mobile/core/errors.dart';
import 'package:classroom360_mobile/core/format.dart';
import 'package:classroom360_mobile/core/models.dart';
import 'package:classroom360_mobile/core/presence.dart';
import 'package:classroom360_mobile/core/whep.dart';
import 'package:flutter_test/flutter_test.dart';

Tone toneOf(String s) => Tone.values.firstWhere((t) => t.name == s);

void main() {
  final fx = jsonDecode(File('test/fixtures/web_parity.json').readAsStringSync()) as Map<String, dynamic>;

  test('every verdict has the same label, sentence, tone and attention flag as the web app', () {
    final web = fx['presence'] as Map<String, dynamic>;
    expect(kPresence.keys.toSet(), web.keys.toSet());
    for (final e in web.entries) {
      final w = e.value as Map<String, dynamic>;
      final m = kPresence[e.key]!;
      expect(m.label, w['label'], reason: e.key);
      expect(m.why, w['why'], reason: e.key);
      expect(m.tone, toneOf(w['tone'] as String), reason: e.key);
      expect(m.attention, w['attention'], reason: e.key);
    }
  });

  test('needsAttention agrees with the web app, with and without a verdict', () {
    for (final c in fx['needsAttention'] as List) {
      final r = RoomStatus(roomId: 'r', roomCode: 'X', presence: c['presence'] as String?, discrepancy: c['discrepancy'] as String?);
      expect(needsAttention(r), c['expect'], reason: '${c['presence']} / ${c['discrepancy']}');
    }
  });

  test('peopleText agrees', () {
    for (final c in fx['peopleText'] as List) {
      expect(peopleText(c['count'] as int?, c['occupied'] as bool?), c['expect'], reason: '${c['count']} ${c['occupied']}');
    }
  });

  test('times, ranges and dates agree', () {
    for (final c in fx['times'] as List) {
      expect(fmtTime(c['t'] as String), c['expect'], reason: c['t'] as String);
    }
    for (final c in fx['ranges'] as List) {
      expect(fmtRange(c['a'] as String, c['b'] as String), c['expect']);
    }
    for (final c in fx['dates'] as List) {
      expect(fmtDate(c['d'] as String), c['expect'], reason: c['d'] as String);
    }
  });

  test('date and time of a moment agree when the phone is on Manila time', () {
    for (final c in fx['dateTimes'] as List) {
      final manila = DateTime.parse(c['iso'] as String).toUtc().add(const Duration(hours: 8));
      // only the fields are read, so a UTC value standing for the wall clock is enough
      expect(fmtDateTime(manila), c['expect'], reason: c['iso'] as String);
    }
  });

  test('database messages are worded as on the web (except the pointer to the web-only School hours page)', () {
    for (final c in fx['errors'] as List) {
      final web = (c['expect'] as String).replaceAll(' See School hours.', '');
      expect(friendlyError(c['message'] as String), web, reason: c['message'] as String);
    }
  });

  test('whepUrl agrees', () {
    for (final c in fx['whepUrls'] as List) {
      expect(whepUrl(c['gateway'] as String, c['stream'] as String), c['expect']);
    }
  });
}
