import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/presence.dart';
import '../core/store.dart';
import 'art.dart';
import 'theme.dart';

// ------------------------------------------------------------------------------------------------ lamps and screws

/// A small round lamp, like the ones on a locker door: lit it glows in [color]; unlit it is a dim dot in [off].
/// A [pulse]ing lamp blinks slowly (not when the phone asks for reduced motion).
class Lamp extends StatefulWidget {
  const Lamp({super.key, required this.color, this.size = 8, this.lit = true, this.pulse = false, this.off = Palette.ink700});

  final Color color;
  final double size;
  final bool lit;
  final bool pulse;
  final Color off;

  @override
  State<Lamp> createState() => _LampState();
}

class _LampState extends State<Lamp> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant Lamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final want = widget.pulse && widget.lit && !motionReduced(context);
    if (want && _c == null) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..repeat(reverse: true);
    } else if (!want && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final dot = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.lit ? widget.color : widget.off,
        boxShadow: widget.lit ? [BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: s * 0.9, spreadRadius: s * 0.08)] : null,
      ),
    );
    final c = _c;
    if (c == null) return dot;
    return FadeTransition(opacity: Tween<double>(begin: 1, end: 0.35).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)), child: dot);
  }
}

/// A screw head, for the corners of the dark plates.
class Screw extends StatelessWidget {
  const Screw({super.key, this.size = 7});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Palette.ink800, shape: BoxShape.circle, border: Border.all(color: Palette.ink700)),
        child: Center(child: Transform.rotate(angle: 0.6, child: Container(width: size - 3, height: 1, color: Palette.ink950))),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ key tag

/// How a key tag is coloured: brass while the key is out, ink while it sits in the locker, red when it was not returned.
enum KeyTone { brass, ink, alert }

KeyTone keyToneFor(String? keyStatus) {
  switch (keyStatus) {
    case 'issued':
      return KeyTone.brass;
    case 'outstanding':
      return KeyTone.alert;
  }
  return KeyTone.ink;
}

/// The room code drawn as a key tag with its punched hole: the one recurring motif of the web app and the phone app.
class KeyTagChip extends StatelessWidget {
  const KeyTagChip(this.code, {super.key, this.tone = KeyTone.ink, this.large = false});

  final String code;
  final KeyTone tone;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final Color border;
    final Color fill;
    final Color text;
    final Color hole;
    switch (tone) {
      case KeyTone.brass:
        border = Palette.brass300;
        fill = Palette.brass100;
        text = Palette.brass700;
        hole = Palette.brass400;
      case KeyTone.alert:
        border = Palette.rose200;
        fill = Palette.rose50;
        text = Palette.rose700;
        hole = Palette.rose400;
      case KeyTone.ink:
        border = Palette.ink200;
        fill = Palette.ink100;
        text = Palette.ink700;
        hole = Palette.ink400;
    }
    final d = large ? 9.0 : 7.0;
    return Container(
      padding: large ? const EdgeInsets.fromLTRB(11, 5, 14, 5) : const EdgeInsets.fromLTRB(7, 2, 9, 2),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(large ? 8 : 6), border: Border.all(color: border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: hole))),
          SizedBox(width: large ? 9 : 6),
          Flexible(child: Text(code, maxLines: 1, overflow: TextOverflow.ellipsis, style: monoStyle(large ? 16 : 13, color: text))),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ badges, lines, headers

/// A small rounded label coloured by [tone], with a dot in front.
class ToneBadge extends StatelessWidget {
  const ToneBadge(this.label, this.tone, {super.key});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: c.foreground, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(12, color: c.foreground, weight: FontWeight.w700))),
        ],
      ),
    );
  }
}

/// A line with a small icon in front.
class IconLine extends StatelessWidget {
  const IconLine(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: Palette.ink50, borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 15, color: Palette.ink600),
          ),
          const SizedBox(width: 10),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(text, style: bodyStyle(14, height: 1.3)))),
        ],
      ),
    );
  }
}

/// A heading above a group of cards: the title, an optional count in a brass pill, and a rule that runs to the edge.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.count});

  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: displayStyle(19))),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(color: Palette.brass100, borderRadius: BorderRadius.circular(999), border: Border.all(color: Palette.brass300)),
              child: Text('$count', style: monoStyle(12.5, color: Palette.brass700)),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: Palette.ink200)),
        ],
      ),
    );
  }
}

/// A row of the "label on the left, value on the right" kind, used in the room sheet and the camera page.
class LedgerRow extends StatelessWidget {
  const LedgerRow(this.label, this.value, {super.key, this.valueColor = Palette.ink900, this.mono = false});

  final String label;
  final String value;
  final Color valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 84, child: Text(label, style: bodyStyle(13.5, color: Palette.ink500))),
          Expanded(child: Text(value, style: mono ? monoStyle(14, color: valueColor) : bodyStyle(14.5, color: valueColor, weight: FontWeight.w500, height: 1.3))),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ messages

/// A key tag with an icon on it, a sentence, and an optional button: used for "loading failed", "nothing here yet" and so on.
class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key, required this.icon, required this.text, this.actionLabel, this.onAction, this.isError = false});

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TagArt(icon: icon, alert: isError),
            const SizedBox(height: 22),
            Text(text, textAlign: TextAlign.center, style: bodyStyle(15.5, color: isError ? Palette.rose800 : Palette.ink700, height: 1.45)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A strip at the top of a page: the result of the last action (green) or an error (red).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.notice, {super.key, required this.onClose});

  final Notice notice;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(notice.isError ? Tone.bad : Tone.good);
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.foreground.withValues(alpha: 0.2))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(notice.isError ? Icons.error_outline : Icons.check_circle_outline, size: 20, color: c.foreground),
            const SizedBox(width: 10),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(notice.text, style: bodyStyle(14, color: c.foreground, weight: FontWeight.w600, height: 1.3)))),
            IconButton(onPressed: onClose, icon: Icon(Icons.close, color: c.foreground), tooltip: 'Dismiss'),
          ],
        ),
      ),
    );
  }
}

/// "Showing the last good copy" strip when a refresh failed but older data is still on screen.
class StaleBanner extends StatelessWidget {
  const StaleBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(Tone.warn);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.foreground.withValues(alpha: 0.2))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_off_rounded, size: 18, color: c.foreground),
          const SizedBox(width: 10),
          Expanded(child: Text('$text Showing the last information that loaded.', style: bodyStyle(13, color: c.foreground, height: 1.35))),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ motion

/// Fades a child in while it rises a few pixels, once, when it first appears. [index] staggers a list a little.
/// A child that has a string key (the card of one room, one request) is only revealed the first time that key is
/// seen, so cards scrolled out of a long list and back in do not play it again.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  /// the keys of the cards that have been revealed already, for as long as the app is open
  static final Set<Object?> _seen = <Object?>{};

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  bool? _animate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animate != null) return;
    final key = widget.key;
    var again = false;
    if (key is ValueKey<String>) {
      again = !Reveal._seen.add(key.value);
    }
    _animate = !again && !motionReduced(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_animate != true) return widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 340 + math.min(widget.index, 8) * 55),
      curve: Curves.easeOutCubic,
      child: widget.child,
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child)),
    );
  }
}

/// Grey outlines of cards, pulsing gently, shown while a page's first load is on its way.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 4, this.height = 108});

  final int count;
  final double height;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!motionReduced(context)) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            for (var i = 0; i < widget.count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 1, end: 0.5).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
                  child: Container(
                    height: widget.height,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Palette.ink100)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 96, height: 16, decoration: BoxDecoration(color: Palette.ink100, borderRadius: BorderRadius.circular(5))),
                        const SizedBox(height: 12),
                        Container(width: double.infinity, height: 11, decoration: BoxDecoration(color: Palette.ink50, borderRadius: BorderRadius.circular(5))),
                        const SizedBox(height: 8),
                        Container(width: 180, height: 11, decoration: BoxDecoration(color: Palette.ink50, borderRadius: BorderRadius.circular(5))),
                      ],
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

/// The page shown while the app starts or loads the signed-in person: the mark on the dark navy, with a brass ring.
class SplashLoading extends StatelessWidget {
  const SplashLoading({super.key, this.label = 'Opening Classroom360'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.ink950,
      body: Stack(
        children: [
          const Positioned.fill(child: DraftingGrid()),
          Center(
            child: Semantics(
              label: label,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoMark(size: 64),
                  const SizedBox(height: 22),
                  const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.brass400)),
                  const SizedBox(height: 18),
                  Text(label, style: displayStyle(16, color: Palette.ink300, weight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ layout

/// Keeps a page's content to a comfortable width and centres it, so on a tablet or a phone held sideways the
/// cards do not stretch across the whole screen. On an ordinary phone it changes nothing.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.maxWidth = 680});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}
