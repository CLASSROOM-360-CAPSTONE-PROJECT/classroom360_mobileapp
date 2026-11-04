import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// The ledger plate: the day's figures on a dark steel plate screwed to the page, set in flap digits like a
/// departures board. The digits turn over when a number changes (not when the phone asks for reduced motion).
/// It is the one loud thing on the Rooms page, so the rest of the page can stay quiet.

class LedgerFigure {
  const LedgerFigure({required this.label, required this.value, this.hint, this.bad = false, this.lampsLit, this.lampsOf});

  final String label;
  final int value;

  /// a short line under the lamps
  final String? hint;

  /// red digits and lamps
  final bool bad;

  /// lamps under the digits: [lampsLit] of [lampsOf] are on
  final int? lampsLit;
  final int? lampsOf;

  String get semanticLabel => '$label $value${hint == null ? '' : ', $hint'}';
}

/// The digits of a number, each on its own flap. A flap whose digit changes turns over to the new one.
class FlapNumber extends StatelessWidget {
  const FlapNumber({super.key, required this.value, this.pad = 2, this.bad = false});

  final int value;
  final int pad;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final text = math.max(0, value).toString().padLeft(pad, '0');
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < text.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            _Flap(key: ValueKey<int>(text.length - i), char: text[i], bad: bad),
          ],
        ],
      ),
    );
  }
}

class _Flap extends StatelessWidget {
  const _Flap({super.key, required this.char, required this.bad});

  final String char;
  final bool bad;

  static Widget _turn(Widget child, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final v = animation.value;
        return Opacity(
          opacity: v,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.004)
              ..rotateX((1 - v) * math.pi / 2),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const w = 27.0;
    const h = 42.0;
    final tile = Container(
      key: ValueKey<String>(char),
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Palette.ink900,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Palette.ink800),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          MediaQuery.withNoTextScaling(child: Text(char, style: monoStyle(31, color: bad ? Palette.rose300 : Palette.brass300, height: 1))),
          // the hinge line across the middle of a flap
          Positioned(left: 0, right: 0, top: h / 2 - 1, child: Container(height: 1, color: Palette.ink950.withValues(alpha: 0.9))),
        ],
      ),
    );
    return AnimatedSwitcher(
      duration: motionReduced(context) ? Duration.zero : const Duration(milliseconds: 420),
      switchInCurve: const Interval(0.45, 1.0, curve: Curves.easeOut),
      switchOutCurve: const Interval(0.45, 1.0, curve: Curves.easeIn),
      transitionBuilder: _turn,
      child: tile,
    );
  }
}

/// A row of small lamps: [lit] of [of] are on. More than eight are scaled down to eight.
class LampRow extends StatelessWidget {
  const LampRow({super.key, required this.lit, required this.of, this.bad = false});

  final int lit;
  final int of;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final n = of.clamp(0, 8);
    final on = of > 8 ? (lit / of * 8).round() : math.min(lit, n);
    final color = bad ? Palette.rose400 : Palette.brass400;
    return ExcludeSemantics(
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [for (var i = 0; i < n; i++) Lamp(color: color, size: 7, lit: i < on)],
      ),
    );
  }
}

class LedgerPlate extends StatelessWidget {
  const LedgerPlate({super.key, required this.figures, this.footer});

  final List<LedgerFigure> figures;

  /// a line along the bottom of the plate
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Key ledger. ${figures.map((f) => f.semanticLabel).join('. ')}',
      child: Container(
        decoration: BoxDecoration(
          color: Palette.ink950,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.ink800),
          boxShadow: const [BoxShadow(color: Color(0x730B1524), blurRadius: 22, spreadRadius: -8, offset: Offset(0, 12))],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < figures.length; i++) ...[
                        if (i > 0) Container(width: 1, color: Palette.ink800),
                        Expanded(child: _Cell(figure: figures[i])),
                      ],
                    ],
                  ),
                ),
                if (footer != null) ...[
                  Container(height: 1, color: Palette.ink800),
                  Padding(padding: const EdgeInsets.fromLTRB(16, 11, 16, 12), child: footer),
                ],
              ],
            ),
            const Positioned(left: 7, top: 7, child: Screw()),
            const Positioned(right: 7, top: 7, child: Screw()),
            const Positioned(left: 7, bottom: 7, child: Screw()),
            const Positioned(right: 7, bottom: 7, child: Screw()),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.figure});

  final LedgerFigure figure;

  @override
  Widget build(BuildContext context) {
    final f = figure;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(f.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(12.5, color: Palette.ink300, height: 1.25)),
          const SizedBox(height: 10),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: FlapNumber(value: f.value, bad: f.bad)),
          if (f.lampsOf != null) ...[
            const SizedBox(height: 12),
            LampRow(lit: f.lampsLit ?? 0, of: f.lampsOf!, bad: f.bad),
          ],
          if (f.hint != null) ...[
            const SizedBox(height: 10),
            Text(f.hint!, style: bodyStyle(12, color: Palette.ink400, height: 1.25)),
          ],
        ],
      ),
    );
  }
}
