import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/locker_view.dart';
import 'theme.dart';

/*
  The phone app's drawings, in the web app's vocabulary: the key tag with its punched hole, the hook on a rail,
  the steel locker door, the ruled slip. They are painted here, not taken from an icon set, so an empty list
  or a sign-in page looks like part of the same cabinet as the rest of the app.
*/

// ------------------------------------------------------------------------------------------------ logo

/// The Classroom360 mark: a navy tile with an open brass ring and a dot, as on the web app.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 32;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(8 * s)), Paint()..color = Palette.ink800);
    const r = 8.5;
    final ring = Paint()
      ..color = Palette.brass400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round;
    // the web mark dashes the ring 42 on, 11 off; the same share of the circle is drawn here
    final sweep = 2 * math.pi * (42 / (2 * math.pi * r));
    canvas.drawArc(Rect.fromCircle(center: Offset(16 * s, 16 * s), radius: r * s), 0, sweep, false, ring);
    canvas.drawCircle(Offset(16 * s, 16 * s), 2.6 * s, Paint()..color = Palette.brass400);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ------------------------------------------------------------------------------------------------ drafting grid

/// A faint plan-paper grid that fades out from one corner, used behind headers and the sign-in page.
class DraftingGrid extends StatelessWidget {
  const DraftingGrid({super.key, this.color = Palette.ink600, this.opacity = 0.28, this.spacing = 22, this.focus = Alignment.topRight});

  final Color color;
  final double opacity;
  final double spacing;

  /// the corner where the grid is strongest
  final Alignment focus;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => RadialGradient(center: focus, radius: 1.15, colors: const [Colors.white, Color(0x00FFFFFF)]).createShader(rect),
          child: SizedBox.expand(child: CustomPaint(painter: _GridPainter(color.withValues(alpha: opacity), spacing))),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.color, this.spacing);

  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color || old.spacing != spacing;
}

// ------------------------------------------------------------------------------------------------ dashed outline

/// A rounded rectangle drawn with a dashed line: the outline of something that is not there (a key that is out,
/// a door with no room).
class DashedBox extends StatelessWidget {
  const DashedBox({super.key, required this.child, this.color = Palette.ink600, this.radius = 10, this.dash = 5, this.gap = 4, this.strokeWidth = 1.5});

  final Widget child;
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPainter(color: color, radius: radius, dash: dash, gap: gap, strokeWidth: strokeWidth),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.color, required this.radius, required this.dash, required this.gap, required this.strokeWidth});

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(strokeWidth / 2), Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => old.color != color || old.radius != radius || old.dash != dash || old.gap != gap || old.strokeWidth != strokeWidth;
}

// ------------------------------------------------------------------------------------------------ hook, ring and tag

/// A hook: straight down from the rail, then a half circle curling up, like the ones the keys hang on.
class Hook extends StatelessWidget {
  const Hook({super.key, this.color = Palette.ink400, this.height = 26, this.width = 20});

  final Color color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(width, height), painter: _HookPainter(color));
}

class _HookPainter extends CustomPainter {
  const _HookPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final r = (size.width - stroke) / 4;
    // the stem comes down the middle; the curl swings to the right and ends level with the stem's foot
    final x0 = size.width / 2 - r;
    final foot = size.height - r - stroke / 2;
    final path = Path()
      ..moveTo(x0, 0)
      ..lineTo(x0, foot)
      ..arcTo(Rect.fromCircle(center: Offset(x0 + r, foot), radius: r), math.pi, -math.pi, false);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HookPainter old) => old.color != color;
}

/// A steel rail with a screw at each end, that hooks hang from.
class Rail extends StatelessWidget {
  const Rail({super.key, this.height = 12});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A5578), Palette.ink700]),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(width: height, child: const Center(child: _Dot(Palette.ink950, 4))),
          SizedBox(width: height, child: const Center(child: _Dot(Palette.ink950, 4))),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.size);

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// One key tag hanging from a hook. [t] is how far its settling swing has got (see [swingAngle]).
/// A tag marked [gone] is drawn as a dashed outline: that key is out.
class HangingTag extends StatelessWidget {
  const HangingTag({super.key, required this.code, required this.caption, required this.width, this.t = 1, this.gone = false});

  final String code;
  final String caption;
  final double width;
  final double t;
  final bool gone;

  @override
  Widget build(BuildContext context) {
    final body = gone
        ? DashedBox(
            color: Palette.brass400.withValues(alpha: 0.6),
            radius: 10,
            child: SizedBox(width: width, height: 92, child: _tagFace(ghost: true)),
          )
        : Container(
            width: width,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Palette.ink600, width: 1.5),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.ink800, Palette.steelDeep]),
            ),
            child: _tagFace(ghost: false),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hook(color: gone ? Palette.brass400 : Palette.ink400),
        // the tag and its ring swing together about the top of the ring
        Transform.rotate(
          angle: gone ? 0 : swingAngle(t),
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!gone) Transform.translate(offset: const Offset(0, -8), child: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Palette.ink300, width: 2)))),
              if (gone) const SizedBox(height: 6),
              Transform.translate(offset: Offset(0, gone ? 0 : -8), child: body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tagFace({required bool ghost}) {
    return Column(
      children: [
        const SizedBox(height: 11),
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ghost ? Colors.transparent : Palette.ink950,
            border: Border.all(color: ghost ? Palette.brass400.withValues(alpha: 0.6) : Palette.ink500, width: 1.5),
          ),
        ),
        const Spacer(),
        Text(code, style: monoStyle(18, color: ghost ? Palette.brass400.withValues(alpha: 0.85) : const Color(0xFFE6EBF2))),
        const SizedBox(height: 2),
        Text(caption, style: bodyStyle(11, color: ghost ? Palette.brass300 : Palette.ink400)),
        const SizedBox(height: 11),
      ],
    );
  }
}

/// The sign-in page's drawing: a rail of four hooks, a tag on each, and one hook empty because that key is out.
/// The tags settle on their hooks once when the page opens. A dimension line under them marks the four rooms, as on a plan.
class KeyRack extends StatefulWidget {
  const KeyRack({super.key});

  @override
  State<KeyRack> createState() => _KeyRackState();
}

class _KeyRackState extends State<KeyRack> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _started = false;

  static const _codes = ['301', '302', '303', '304'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionReduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'A rack of four hooks with a key on three of them. The key to room 303 is out.',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final tagW = ((box.maxWidth - 3 * 14) / 4).clamp(48.0, 68.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Rail(),
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _codes.length; i++)
                        HangingTag(
                          code: _codes[i],
                          caption: _codes[i] == '303' ? 'Key out' : 'Door ${i + 1}',
                          width: tagW,
                          gone: _codes[i] == '303',
                          // each tag starts a little after the one before it
                          t: ((_c.value - i * 0.07) / (1 - 0.21)).clamp(0.0, 1.0),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const _Tick(),
                    const Expanded(child: _HLine()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('3rd floor, four rooms', style: displayStyle(13, color: Palette.ink300, weight: FontWeight.w500))),
                    const Expanded(child: _HLine()),
                    const _Tick(),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HLine extends StatelessWidget {
  const _HLine();

  @override
  Widget build(BuildContext context) => Container(height: 1, color: Palette.ink600);
}

class _Tick extends StatelessWidget {
  const _Tick();

  @override
  Widget build(BuildContext context) => Container(width: 1, height: 12, color: Palette.ink600);
}

// ------------------------------------------------------------------------------------------------ empty and error art

/// A key tag hanging a little crooked from a hook with an icon on it: the picture for an empty list or an error.
class TagArt extends StatelessWidget {
  const TagArt({super.key, required this.icon, this.alert = false});

  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final edge = alert ? Palette.rose300 : Palette.ink200;
    final iconColor = alert ? Palette.rose700 : Palette.ink500;
    final hole = alert ? Palette.rose400 : Palette.ink400;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Hook(color: alert ? Palette.rose400 : Palette.brass400, height: 30),
          Transform.rotate(
            angle: -0.07,
            alignment: Alignment.topCenter,
            child: Container(
              width: 92,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: edge, width: 1.5),
                boxShadow: const [BoxShadow(color: Color(0x140B1524), blurRadius: 12, offset: Offset(0, 6))],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 11),
                  Container(width: 11, height: 11, decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.canvas, border: Border.all(color: hole, width: 1.5))),
                  Expanded(child: Center(child: Icon(icon, size: 34, color: iconColor))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ camera viewfinder

/// Four corner brackets, like a camera's viewfinder, laid over a picture or a placeholder for one.
class ViewfinderCorners extends StatelessWidget {
  const ViewfinderCorners({super.key, this.color = const Color(0x99FFFFFF), this.inset = 12, this.length = 18});

  final Color color;
  final double inset;
  final double length;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(child: SizedBox.expand(child: CustomPaint(painter: _CornersPainter(color, inset, length)))),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter(this.color, this.inset, this.length);

  final Color color;
  final double inset;
  final double length;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final l = inset;
    final t = inset;
    final r = size.width - inset;
    final b = size.height - inset;
    canvas.drawPath(Path()..moveTo(l, t + length)..lineTo(l, t)..lineTo(l + length, t), p);
    canvas.drawPath(Path()..moveTo(r - length, t)..lineTo(r, t)..lineTo(r, t + length), p);
    canvas.drawPath(Path()..moveTo(l, b - length)..lineTo(l, b)..lineTo(l + length, b), p);
    canvas.drawPath(Path()..moveTo(r - length, b)..lineTo(r, b)..lineTo(r, b - length), p);
  }

  @override
  bool shouldRepaint(covariant _CornersPainter old) => old.color != color || old.inset != inset || old.length != length;
}

/// A quiet plan-paper grid with a thin cross at the centre: what a camera tile shows before its picture opens.
class ScopeGrid extends StatelessWidget {
  const ScopeGrid({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(child: ExcludeSemantics(child: SizedBox.expand(child: CustomPaint(painter: const _ScopePainter()))));
}

class _ScopePainter extends CustomPainter {
  const _ScopePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Palette.ink700.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = size.width / 2 % step; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = size.height / 2 % step; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final cross = Paint()
      ..color = Palette.ink500.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    canvas.drawLine(Offset(c.dx - 9, c.dy), Offset(c.dx + 9, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - 9), Offset(c.dx, c.dy + 9), cross);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ------------------------------------------------------------------------------------------------ the slip

/// The room request slip: a white card with a half-circle notch bitten out of each side and a dashed perforation
/// between them. Above the perforation is the request; below it, [actions] (the tear-off part).
/// A slip without [actions] is a plain card with the accent stripe.
class Slip extends StatelessWidget {
  const Slip({super.key, required this.body, this.actions, this.accent});

  final Widget body;
  final Widget? actions;

  /// colour of the stripe down the left edge
  final Color? accent;

  /// height of the tear-off part
  static const double actionsHeight = 76;

  @override
  Widget build(BuildContext context) {
    final a = actions;
    return CustomPaint(
      painter: _SlipPainter(notchFromBottom: a == null ? null : actionsHeight, accent: accent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          if (a != null) SizedBox(height: actionsHeight, child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: a)),
        ],
      ),
    );
  }
}

class _SlipPainter extends CustomPainter {
  const _SlipPainter({required this.notchFromBottom, required this.accent});

  final double? notchFromBottom;
  final Color? accent;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)));
    final ny = notchFromBottom == null ? null : size.height - notchFromBottom!;
    if (ny != null) {
      const nr = 9.0;
      final bites = Path()
        ..addOval(Rect.fromCircle(center: Offset(0, ny), radius: nr))
        ..addOval(Rect.fromCircle(center: Offset(size.width, ny), radius: nr));
      path = Path.combine(PathOperation.difference, path, bites);
    }
    canvas.drawShadow(path, const Color(0xFF0B1524), 1.5, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    if (accent != null) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(Rect.fromLTWH(0, 0, 4, size.height), Paint()..color = accent!);
      canvas.restore();
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Palette.ink200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (ny != null) {
      final dash = Paint()
        ..color = Palette.ink200
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (double x = 18; x < size.width - 18; x += 8) {
        canvas.drawLine(Offset(x, ny), Offset(math.min(x + 4, size.width - 18), ny), dash);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SlipPainter old) => old.notchFromBottom != notchFromBottom || old.accent != accent;
}
