import 'dart:async';
import 'dart:io';

import 'package:classroom360_mobile/core/errors.dart';
import 'package:flutter_test/flutter_test.dart';

/// Looks like supabase_flutter's PostgrestException / AuthException: it has a `message`.
class FakeDbError implements Exception {
  FakeDbError(this.message);
  final String message;
  @override
  String toString() => 'PostgrestException(message: $message, code: 22023)';
}

void main() {
  test('a database error shows its message, not the wrapper around it', () {
    expect(friendlyError(FakeDbError('a note is required when rejecting a request')), 'a note is required when rejecting a request');
    expect(friendlyError(FakeDbError('this request is already approved')), 'this request is already approved');
  });

  test('the exclusion-constraint names become sentences', () {
    expect(friendlyError(FakeDbError('conflicting key value violates exclusion constraint "no_room_double_request"')),
        'That room or instructor is already taken by an approved request at that time.');
  });

  test('sign-in problems', () {
    expect(friendlyError(FakeDbError('Invalid login credentials')), 'The email or password is not right.');
    expect(friendlyError(FakeDbError('Email not confirmed')), startsWith('Confirm your email'));
  });

  test('network problems of every kind say the same helpful thing', () {
    const want = 'Could not reach the server. Check your connection and try again.';
    expect(friendlyError(const SocketException('Failed host lookup: x.supabase.co')), want);
    expect(friendlyError(TimeoutException('slow')), want);
    expect(friendlyError(Exception('ClientException: Connection reset by peer')), want);
    expect(friendlyError('Failed to fetch'), want);
  });

  test('permission errors', () {
    expect(friendlyError(FakeDbError('new row violates row-level security policy for table "room_requests"')), 'You are not allowed to do that.');
    expect(friendlyError(FakeDbError('permission denied for function decide_room_request')), 'You are not allowed to do that.');
  });

  test('nothing at all falls back', () {
    expect(friendlyError(null, 'Try again.'), 'Try again.');
    expect(friendlyError(''), 'The change was not saved.');
  });

  test('an expired sign-in tells the person to sign in again', () {
    expect(friendlyError(FakeDbError('JWT expired')), 'Your sign-in has expired. Sign out and sign in again.');
    expect(friendlyError(FakeDbError('Invalid JWT')), 'Your sign-in has expired. Sign out and sign in again.');
  });

  test('a missing function or table means the database update has not been run', () {
    expect(isMissingMigration(FakeDbError("Could not find the table 'public.notifications' in the schema cache")), true);
    expect(isMissingMigration(FakeDbError('Could not find the function public.sweep_my_alerts() in the schema cache')), true);
    expect(isMissingMigration(FakeDbError('relation "public.notifications" does not exist')), true);
    expect(isMissingMigration(FakeDbError('permission denied for table notifications')), false);
    expect(isMissingMigration(FakeDbError('network is down')), false);
    expect(isMissingMigration(null), false);
  });
}
