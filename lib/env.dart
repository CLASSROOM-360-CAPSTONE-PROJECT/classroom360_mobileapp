/// The project address and the PUBLISHABLE (anon) key, given when the app is built or run:
///
///   flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
///
/// They are the same two values as VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in web/.env.local.
/// Never put the secret or service_role key in a phone app.
class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// What is wrong with the settings, in words, or null when they are fine.
  static String? get problem => check(supabaseUrl, supabaseAnonKey);

  static String? check(String url, String key) {
    if (url.isEmpty || key.isEmpty) {
      return 'The app was started without its Supabase settings.\n\n'
          'Run it with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=... (see mobile/README.md).';
    }
    if (!RegExp(r'^https?://[^/\s]+$').hasMatch(url)) {
      return 'SUPABASE_URL should look like https://abcd1234.supabase.co (no path at the end).';
    }
    if (key.startsWith('sb_secret_') || _isServiceRoleJwt(key)) {
      return 'That is a SECRET key. A phone app must only ever hold the publishable (anon) key. Use the publishable key instead.';
    }
    return null;
  }

  static bool _isServiceRoleJwt(String key) {
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (p.length % 4 != 0) {
        p += '=';
      }
      return String.fromCharCodes(_b64(p)).contains('"service_role"');
    } catch (_) {
      return false;
    }
  }

  static List<int> _b64(String s) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final out = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final ch in s.split('')) {
      if (ch == '=') break;
      buffer = (buffer << 6) | alphabet.indexOf(ch);
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xFF);
      }
    }
    return out;
  }
}
