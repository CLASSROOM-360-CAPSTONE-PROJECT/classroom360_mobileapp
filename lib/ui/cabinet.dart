import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/locker_view.dart';
import '../core/models.dart';
import 'art.dart';
import 'theme.dart';
import 'widgets.dart';

/// The key locker drawn as the steel cabinet it is: a door for each room's key, with its hinges, handle and lamp.
/// The lamp is dim while the key is inside, brass while it is out, and red and blinking when it has not come back.
/// Pressing a door opens the room it holds the key to.
class KeyCabinet extends StatelessWidget {
  const KeyCabinet({super.key, required this.lockers, required this.onOpenRoom});

  final List<LockerStatus> lockers;
  final void Function(String roomId) onOpenRoom;

  @override
  Widget build(BuildContext context) {
    final doors = sortedDoors(lockers);
    if (doors.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < doors.length; i += 2) {
      final second = i + 1 < doors.length ? doors[i + 1] : null;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Door(locker: doors[i], onTap: () => onOpenRoom(doors[i].roomId))),
              const SizedBox(width: 14),
              Expanded(child: second == null ? const SizedBox.shrink() : _Door(locker: second, onTap: () => onOpenRoom(second.roomId))),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Palette.ink900,
        border: Border.all(color: Palette.ink700, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x4D0B1524), blurRadius: 18, spreadRadius: -6, offset: Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Padding(padding: const EdgeInsets.all(2), child: Column(mainAxisSize: MainAxisSize.min, children: rows)),
          const Positioned(left: 0, top: 0, child: Screw()),
          const Positioned(right: 0, top: 0, child: Screw()),
          const Positioned(left: 0, bottom: 0, child: Screw()),
          const Positioned(right: 0, bottom: 0, child: Screw()),
        ],
      ),
    );
  }
}

/// One door. Pressing it swings it open on its hinge for a moment, showing the hook inside, and then opens the room
/// it holds the key to. (With reduced motion it opens the room straight away.)
class _Door extends StatefulWidget {
  const _Door({required this.locker, required this.onTap});

  final LockerStatus locker;
  final VoidCallback onTap;

  @override
  State<_Door> createState() => _DoorState();
}

class _DoorState extends State<_Door> with SingleTickerProviderStateMixin {
  late final AnimationController _swing = AnimationController(vsync: this, duration: const Duration(milliseconds: 240), reverseDuration: const Duration(milliseconds: 300));
  bool _busy = false;

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  Future<void> _press() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    if (motionReduced(context)) {
      widget.onTap();
      return;
    }
    _busy = true;
    try {
      await _swing.forward().orCancel;
      if (!mounted) return;
      widget.onTap();
      // the room sheet slides up over the cabinet while the door swings shut again behind it
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      await _swing.reverse().orCancel;
    } on TickerCanceled {
      // the page went away mid-swing
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locker = widget.locker;
    final state = doorState(locker);
    final Color edge;
    switch (state) {
      case DoorState.out:
        edge = Palette.brass400;
      case DoorState.notReturned:
        edge = Palette.rose400;
      case DoorState.inside:
      case DoorState.empty:
        edge = Palette.ink600;
    }
    final keyInside = state == DoorState.inside || state == DoorState.empty;
    final since = locker.issuedAt == null ? null : DateTime.tryParse(locker.issuedAt!);
    final holder = locker.holderName ?? 'Unknown holder';
    final String status;
    final String? detail;
    switch (state) {
      case DoorState.inside:
      case DoorState.empty:
        status = 'Key in the locker';
        detail = null;
      case DoorState.out:
        status = holder;
        detail = since == null ? 'Key is out' : 'Taken ${fmtClock(since.toLocal())}';
      case DoorState.notReturned:
        status = holder;
        detail = 'Not returned';
    }
    final radius = BorderRadius.circular(10);
    final door = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: edge, width: 1.5),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.ink800, Palette.steelDeep]),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: _press,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Door', style: bodyStyle(12.5, color: Palette.ink300)),
                        const SizedBox(width: 5),
                        Text('${locker.compartmentNo}', style: displayStyle(28, color: Palette.brass300, height: 1.1)),
                        const Spacer(),
                        Lamp(
                          color: state == DoorState.notReturned ? Palette.rose400 : Palette.brass400,
                          size: 9,
                          lit: state == DoorState.out || state == DoorState.notReturned,
                          pulse: state == DoorState.notReturned,
                          off: Palette.ink500,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerLeft, child: KeyTagChip(locker.roomCode, tone: keyToneFor(locker.keyStatus))),
                    const SizedBox(height: 10),
                    Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(13, color: keyInside ? Palette.ink400 : Colors.white, weight: keyInside ? FontWeight.w400 : FontWeight.w600)),
                    if (detail != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(12, color: state == DoorState.notReturned ? Palette.rose300 : Palette.ink300))),
                  ],
                ),
              ),
            ),
          ),
        ),
        // hinges down the left edge and the handle on the right, so each door reads as a door
        Positioned(left: -3, top: 14, child: _Fitting(height: 20, color: Palette.ink600)),
        Positioned(left: -3, bottom: 14, child: _Fitting(height: 20, color: Palette.ink600)),
        Positioned(right: -3, top: 0, bottom: 0, width: 5, child: Center(child: _Fitting(height: 34, color: Palette.ink500))),
      ],
    );
    return Semantics(
      button: true,
      label: 'Door ${locker.compartmentNo}, ${locker.roomCode}, ${keyLabelFor(state)}${state == DoorState.inside ? '' : ', held by $holder'}',
      excludeSemantics: true,
      onTap: _press,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // the inside of the cabinet, seen as the door swings: a hook, with the key on it when it is in
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Palette.ink950, borderRadius: radius, border: Border.all(color: Palette.ink700)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hook(color: keyInside ? Palette.brass400 : Palette.ink600, height: 22),
                  if (keyInside) const Icon(Icons.vpn_key_rounded, size: 22, color: Palette.brass300),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _swing,
            child: door,
            builder: (context, child) => Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(Curves.easeOutCubic.transform(_swing.value) * 1.0),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fitting extends StatelessWidget {
  const _Fitting({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: Container(width: 5, height: height, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))));
}

String keyLabelFor(DoorState s) {
  switch (s) {
    case DoorState.empty:
      return 'no key';
    case DoorState.inside:
      return 'key in the locker';
    case DoorState.out:
      return 'key out';
    case DoorState.notReturned:
      return 'key not returned';
  }
}
