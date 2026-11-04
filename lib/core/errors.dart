import 'dart:async';
import 'dart:io';

/// The text of an error: the `message` of a Supabase exception when it has one, otherwise the error itself.
String _messageOf(Object err) {
  if (err is String) return err;
  try {
    final m = (err as dynamic).message;
    if (m is String && m.isNotEmpty) return m;
  } catch (_) {
    // not an error with a message field
  }
  return err.toString();
}

/// Turns a database, sign-in or network error into a sentence a person can act on.
/// The database messages are the same ones the web app words (`web/src/lib/errors.ts`).
String friendlyError(Object? err, [String fallback = 'The change was not saved.']) {
  if (err == null) return fallback;
  if (err is SocketException || err is TimeoutException || err is HandshakeException) {
    return 'Could not reach the server. Check your connection and try again.';
  }
  final msg = _messageOf(err);
  if (msg.isEmpty) return fallback;
  if (msg.contains('no_room_double_booking')) return 'That room is already booked at that time, possibly by another department.';
  if (msg.contains('no_instructor_double_booking')) return 'That instructor already teaches at that time.';
  if (msg.contains('no_room_double_request') || msg.contains('no_instructor_double_request')) {
    return 'That room or instructor is already taken by an approved request at that time.';
  }
  if (msg.contains('outside school hours')) return 'The school is not open at that time.';
  if (msg.contains('row-level security') || msg.contains('permission denied')) return 'You are not allowed to do that.';
  if (msg.contains('JWT expired') || msg.contains('Invalid JWT') || msg.contains('invalid claim')) {
    return 'Your sign-in has expired. Sign out and sign in again.';
  }
  if (msg.contains('Invalid login credentials')) return 'The email or password is not right.';
  if (msg.contains('Email not confirmed')) return 'Confirm your email address first (check your inbox), then sign in.';
  if (msg.contains('Failed host lookup') ||
      msg.contains('SocketException') ||
      msg.contains('Connection refused') ||
      msg.contains('Connection reset') ||
      msg.contains('ClientException') ||
      msg.contains('Failed to fetch') ||
      msg.contains('NetworkError')) {
    return 'Could not reach the server. Check your connection and try again.';
  }
  return msg;
}

/// True when a call failed because the database does not have an update yet (the function or table is missing),
/// so a feature can stay quiet instead of showing a raw error. Same test as `isMissingMigration` in `web/src/lib/api.ts`.
bool isMissingMigration(Object? err) {
  if (err == null) return false;
  final msg = _messageOf(err);
  return RegExp(r'could not find the (function|table)|schema cache|does not exist|PGRST20[25]|42P01|42883', caseSensitive: false).hasMatch(msg);
}
