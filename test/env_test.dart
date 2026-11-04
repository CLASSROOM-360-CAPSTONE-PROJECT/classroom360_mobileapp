import 'dart:convert';

import 'package:classroom360_mobile/env.dart';
import 'package:flutter_test/flutter_test.dart';

String jwt(Map<String, Object> claims) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(claims)}.signature';
}

void main() {
  const url = 'https://abcd1234.supabase.co';

  test('missing settings are explained', () {
    expect(Env.check('', ''), contains('--dart-define'));
    expect(Env.check(url, ''), contains('--dart-define'));
    expect(Env.check('', 'sb_publishable_x'), contains('--dart-define'));
  });

  test('the project address must be just the address', () {
    expect(Env.check('$url/rest/v1/', 'sb_publishable_x'), contains('no path'));
    expect(Env.check('abcd1234.supabase.co', 'sb_publishable_x'), contains('https://'));
    expect(Env.check(url, 'sb_publishable_x'), isNull);
    expect(Env.check('http://192.168.1.20:54321', 'sb_publishable_x'), isNull);
  });

  test('a secret key is refused, whichever style it is', () {
    expect(Env.check(url, 'sb_secret_abc'), contains('SECRET'));
    expect(Env.check(url, jwt({'role': 'service_role', 'exp': 1999999999})), contains('SECRET'));
  });

  test('the publishable key and an old anon key are accepted', () {
    expect(Env.check(url, 'sb_publishable_abc'), isNull);
    expect(Env.check(url, jwt({'role': 'anon', 'exp': 1999999999})), isNull);
  });

  test('something that is not a token does not crash the check', () {
    expect(Env.check(url, 'a.b.c'), isNull);
    expect(Env.check(url, 'not a key at all'), isNull);
  });
}
