import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/errors.dart';
import 'core/models.dart';
import 'data/supabase_backend.dart';
import 'ui/art.dart';
import 'ui/home_shell.dart';
import 'ui/sign_in_page.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

class Classroom360App extends StatelessWidget {
  const Classroom360App({super.key, this.settingsProblem});

  /// set when the app was started without usable Supabase settings (see env.dart)
  final String? settingsProblem;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classroom360',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: settingsProblem != null ? _SettingsProblemPage(settingsProblem!) : const AuthGate(),
    );
  }
}

class _SettingsProblemPage extends StatelessWidget {
  const _SettingsProblemPage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => _Wall(icon: Icons.settings_outlined, text: text, isError: true);
}

/// A full-screen notice on the dark steel wall: the logo, then a white panel with a key tag, a sentence and buttons.
/// Used when the app has no settings, when the account could not be loaded, and for people this app is not for.
class _Wall extends StatelessWidget {
  const _Wall({required this.icon, required this.text, this.isError = false, this.actions = const []});

  final IconData icon;
  final String text;
  final bool isError;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Palette.ink950,
        body: Stack(
          children: [
            const Positioned.fill(child: ExcludeSemantics(child: IgnorePointer(child: DraftingGrid(opacity: 0.32, spacing: 24, focus: Alignment(0.7, -0.6))))),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Reveal(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const ExcludeSemantics(child: LogoMark(size: 40)),
                              const SizedBox(width: 12),
                              Text('Classroom360', style: displayStyle(26, color: Colors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Reveal(
                          index: 1,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 12))],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(child: TagArt(icon: icon, alert: isError)),
                                const SizedBox(height: 20),
                                Semantics(
                                  liveRegion: isError,
                                  child: Text(text, textAlign: TextAlign.center, style: bodyStyle(15.5, color: isError ? Palette.rose800 : Palette.ink700, height: 1.45)),
                                ),
                                for (final a in actions) ...[const SizedBox(height: 12), a],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the sign-in page, or, once signed in, loads the person's profile and shows the app.
/// The phone app is for deans and administrators; anyone else is told so and can sign out.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final SupabaseClient _client = Supabase.instance.client;
  late final SupabaseBackend _backend = SupabaseBackend(_client);
  StreamSubscription<AuthState>? _sub;
  String? _userId;
  Profile? _profile;
  bool _loading = false;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _userId = _client.auth.currentSession?.user.id;
    _sub = _client.auth.onAuthStateChange.listen((state) {
      final id = state.session?.user.id;
      if (id == _userId) return; // a refreshed token for the same person
      setState(() {
        _userId = id;
        _profile = null;
        _profileError = null;
      });
      if (id != null) _loadProfile();
    });
    if (_userId != null) _loadProfile();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final id = _userId;
    setState(() {
      _loading = true;
      _profileError = null;
    });
    try {
      final p = await _backend.loadProfile();
      if (!mounted || id != _userId) return;
      setState(() => _profile = p);
    } catch (err) {
      if (!mounted || id != _userId) return;
      setState(() => _profileError = friendlyError(err, 'Your account could not be loaded.'));
    } finally {
      if (mounted && id == _userId) setState(() => _loading = false);
    }
  }

  /// Returns an error sentence, or null when the sign-in worked.
  Future<String?> _signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email.trim(), password: password);
      return null;
    } catch (err) {
      return friendlyError(err, 'Could not sign in.');
    }
  }

  Future<void> _signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // the state listener below still moves to the sign-in page when the session is gone
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return SignInPage(onSignIn: _signIn);

    if (_loading && _profile == null) {
      return const SplashLoading(label: 'Loading your account');
    }
    if (_profileError != null || _profile == null) {
      return _Wall(
        icon: Icons.cloud_off_outlined,
        text: _profileError ?? 'There is no profile for this account yet. Ask an administrator to finish setting it up.',
        isError: true,
        actions: [
          FilledButton(onPressed: _loadProfile, child: const Text('Try again')),
          TextButton(onPressed: _signOut, child: const Text('Sign out')),
        ],
      );
    }
    final profile = _profile!;
    if (!isOps(profile.role)) {
      return _Wall(
        icon: Icons.lock_outline_rounded,
        text: 'This app is for deans and administrators. You are signed in as ${roleLabel(profile.role).toLowerCase()}. '
            'Use the web app for your own schedule and room requests.',
        actions: [OutlinedButton(onPressed: _signOut, child: const Text('Sign out'))],
      );
    }
    return HomeShell(key: ValueKey(profile.id), backend: _backend, profile: profile, onSignOut: _signOut);
  }
}
