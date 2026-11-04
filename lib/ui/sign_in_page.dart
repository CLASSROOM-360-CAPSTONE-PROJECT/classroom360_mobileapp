import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art.dart';
import 'theme.dart';
import 'widgets.dart';

/// The first screen: a dark steel wall with the key rack on it, and the sign-in form on a white panel at the bottom.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.onSignIn});

  /// Returns an error sentence, or null when the sign-in worked.
  final Future<String?> Function(String email, String password) onSignIn;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSignIn(email, _password.text);
    if (!mounted) return;
    // on success the gate replaces this page; only a failure stays here
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarDividerColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Palette.ink950,
        body: Stack(
          children: [
            const Positioned.fill(child: ExcludeSemantics(child: IgnorePointer(child: DraftingGrid(opacity: 0.32, spacing: 24, focus: Alignment(0.7, -0.6))))),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Center(
                    // at least as tall as the screen, so the form panel sits at the bottom; taller than that, it scrolls
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight, maxWidth: 520),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Reveal(child: _hero()),
                          Reveal(index: 2, child: _panel(context)),
                        ],
                      ),
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

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ExcludeSemantics(child: LogoMark(size: 44)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Classroom360', style: displayStyle(26, color: Colors.white, height: 1.1)),
                  Text('For deans and administrators', style: bodyStyle(13, color: Palette.ink300)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 34),
          Semantics(header: true, child: Text('Every key follows the timetable.', style: displayStyle(40, color: Colors.white, height: 1.04))),
          const SizedBox(height: 12),
          Text('See which rooms are in use, who holds each key, and what the cameras show, then approve room requests from your phone.', style: bodyStyle(15, color: Palette.ink300, height: 1.45)),
          const SizedBox(height: 30),
          const KeyRack(),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Palette.brass50, shape: BoxShape.circle, border: Border.all(color: Palette.brass200)),
                  child: const Icon(Icons.vpn_key_rounded, size: 20, color: Palette.brass600),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Sign in', style: displayStyle(28, height: 1.1))),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text('Use your Classroom360 account.', style: bodyStyle(14, color: Palette.ink600)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              style: bodyStyle(16, color: Palette.ink900),
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded, color: Palette.ink500), fillColor: Palette.ink50),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              focusNode: _passwordFocus,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              style: bodyStyle(16, color: Palette.ink900),
              decoration: InputDecoration(
                labelText: 'Password',
                fillColor: Palette.ink50,
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Palette.ink500),
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Palette.ink500),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            AnimatedSize(
              duration: motionReduced(context) ? Duration.zero : const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                          decoration: BoxDecoration(color: Palette.rose50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Palette.rose200)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.error_outline_rounded, size: 20, color: Palette.rose700)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_error!, style: bodyStyle(14, color: Palette.rose800, weight: FontWeight.w600, height: 1.35))),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.ink500)),
                        const SizedBox(width: 12),
                        Text('Signing in'),
                      ],
                    )
                  : const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
