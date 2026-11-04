import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/errors.dart';
import '../core/format.dart';
import '../core/presence.dart';
import '../core/room_week.dart';
import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

/// One room's week, for the room sheet: the class meetings that repeat every week and the one-off room requests that have
/// been approved (or are still waiting), a day at a time, with whatever is happening now picked out. The seven day tabs
/// show how full each day is. The section follows the school's clock, and it reloads by itself when a request is decided.
class RoomScheduleSection extends StatefulWidget {
  const RoomScheduleSection({super.key, required this.store, required this.roomId});

  final AppStore store;
  final String roomId;

  @override
  State<RoomScheduleSection> createState() => _RoomScheduleSectionState();
}

class _RoomScheduleSectionState extends State<RoomScheduleSection> {
  AppStore get store => widget.store;

  RoomWeekData? _data;
  String? _error;
  bool _inFlight = false;
  late SchoolClock _clock;
  late DateTime _monday;
  late int _selected; // 0 = Monday
  Timer? _tick;
  Timer? _refresh;
  StreamSubscription<int>? _sub;
  Object? _pendingSeen;
  Object? _decidedSeen;

  @override
  void initState() {
    super.initState();
    _clock = store.clock;
    _monday = mondayOf(_clock.today);
    _selected = _clock.isoDow - 1;
    _pendingSeen = store.pending;
    _decidedSeen = store.decided;
    // the highlight moves with the clock; a minute is the finest it needs, twenty seconds keeps it from lagging
    _tick = Timer.periodic(const Duration(seconds: 20), (_) => _onTick());
    _refresh = Timer.periodic(const Duration(seconds: 60), (_) => _load());
    // a request that was sent, approved, rejected or cancelled somewhere else changes this room's week at once
    _sub = store.changes.listen((_) {
      if (!identical(store.pending, _pendingSeen) || !identical(store.decided, _decidedSeen)) {
        _pendingSeen = store.pending;
        _decidedSeen = store.decided;
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _refresh?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    final clock = store.clock;
    final monday = mondayOf(clock.today);
    final newWeek = monday != _monday;
    setState(() {
      _clock = clock;
      if (newWeek) {
        _monday = monday;
        _selected = clock.isoDow - 1;
      }
    });
    if (newWeek) _load();
  }

  Future<void> _load() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final data = await store.loadRoomWeek(widget.roomId, _monday);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = friendlyError(err, 'The schedule could not be loaded.'));
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final week = data == null ? null : buildWeek(monday: _monday, meetings: data.meetings, requests: data.requests);
    final selected = week == null ? null : week[_selected];
    final nextId = week == null ? null : nextSlot(week, _clock)?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Semantics(header: true, child: Text('Schedule', style: displayStyle(20))),
            const SizedBox(width: 10),
            Expanded(child: Text('Week of ${fmtWeekRange(_monday)}', textAlign: TextAlign.right, style: bodyStyle(13, color: Palette.ink500))),
          ],
        ),
        const SizedBox(height: 12),
        if (week == null)
          _error == null ? const _ScheduleSkeleton() : _ScheduleError(message: _error!, onRetry: _load)
        else ...[
          _DayStrip(
            week: week,
            selected: _selected,
            clock: _clock,
            onSelect: (i) {
              if (i != _selected) HapticFeedback.selectionClick();
              setState(() => _selected = i);
            },
          ),
          const SizedBox(height: 16),
          _DayList(day: selected!, clock: _clock, nextId: nextId),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Could not refresh just now. This is the last copy that loaded.', style: bodyStyle(13, color: Palette.amber800)),
            ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ loading and failing

class _ScheduleSkeleton extends StatelessWidget {
  const _ScheduleSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h) => Container(height: h, decoration: BoxDecoration(color: Palette.ink100, borderRadius: BorderRadius.circular(12)));
    return Column(children: [bar(74), const SizedBox(height: 16), bar(64), const SizedBox(height: 10), bar(64)]);
  }
}

class _ScheduleError extends StatelessWidget {
  const _ScheduleError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(color: Palette.rose50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Palette.rose200)),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 20, color: Palette.rose700),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: bodyStyle(14, color: Palette.rose800, weight: FontWeight.w600, height: 1.3))),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ the seven days

/// The school day the fullness bar is measured against, in minutes (7 AM to 9 PM).
const int _dayMinutes = 14 * 60;

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.week, required this.selected, required this.clock, required this.onSelect});

  final List<WeekDay> week;
  final int selected;
  final SchoolClock clock;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < week.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(child: _DayChip(day: week[i], clock: clock, selected: i == selected, onTap: () => onSelect(i))),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.clock, required this.selected, required this.onTap});

  final WeekDay day;
  final SchoolClock clock;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = day.ymd == clock.ymd;
    final live = isToday && day.slots.any((s) => s.isConfirmed && phaseOf(s, clock) == SlotPhase.now);
    final count = day.slots.length;
    final fill = (day.busyMinutes / _dayMinutes).clamp(0.0, 1.0);

    final Color bg = selected ? Palette.ink900 : (isToday ? Palette.brass50 : Colors.white);
    final Color border = selected ? Palette.ink900 : (isToday ? Palette.brass400 : Palette.ink200);
    final Color fg = selected ? Colors.white : Palette.ink900;
    final Color soft = selected ? Palette.ink300 : Palette.ink500;
    final Color track = selected ? Palette.ink700 : Palette.ink100;
    final Color bar = selected ? Palette.brass400 : Palette.ink600;
    final Color dot = selected ? Palette.brass300 : Palette.ink400;
    final radius = BorderRadius.circular(12);

    return Semantics(
      button: true,
      selected: selected,
      label: '${dayName(day.isoDow)} ${day.date.day}, ${count == 0 ? 'nothing scheduled' : (count == 1 ? '1 item' : '$count items')}${isToday ? ', today' : ''}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: border, width: isToday && !selected ? 1.5 : 1)),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 9, 2, 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dayShort(day.isoDow), style: bodyStyle(11.5, color: soft, weight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text('${day.date.day}', style: displayStyle(21, color: fg, height: 1.15)),
                const SizedBox(height: 7),
                // how full the day is: the share of the school day taken by a class or an approved request
                SizedBox(
                  width: 26,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: track)),
                        FractionallySizedBox(widthFactor: fill, child: ColoredBox(color: bar)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 7,
                  child: live
                      ? Lamp(color: Palette.brass400, size: 7, pulse: true, off: Palette.ink500)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var k = 0; k < (count > 3 ? 3 : count); k++) ...[
                              if (k > 0) const SizedBox(width: 3),
                              Container(width: 4, height: 4, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ one day

class _DayList extends StatelessWidget {
  const _DayList({required this.day, required this.clock, required this.nextId});

  final WeekDay day;
  final SchoolClock clock;
  final String? nextId;

  @override
  Widget build(BuildContext context) {
    final isToday = day.ymd == clock.ymd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(child: Text(fmtLongDay(day.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: displayStyle(17))),
            if (isToday) ...[const SizedBox(width: 8), const ToneBadge('Today', Tone.brass)],
          ],
        ),
        const SizedBox(height: 10),
        if (day.slots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(color: Palette.ink50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Palette.ink100)),
            child: Row(
              children: [
                const Icon(Icons.event_available_outlined, size: 20, color: Palette.ink500),
                const SizedBox(width: 10),
                Expanded(child: Text(isToday ? 'Nothing is scheduled in this room today.' : 'Nothing is scheduled in this room on ${dayName(day.isoDow)}.', style: bodyStyle(14.5, color: Palette.ink600, height: 1.3))),
              ],
            ),
          )
        else
          for (var i = 0; i < day.slots.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _SlotTile(slot: day.slots[i], phase: phaseOf(day.slots[i], clock), isNext: day.slots[i].id == nextId, clock: clock),
          ],
      ],
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.phase, required this.isNext, required this.clock});

  final WeekSlot slot;
  final SlotPhase phase;
  final bool isNext;
  final SchoolClock clock;

  String get _kindText {
    switch (slot.kind) {
      case SlotKind.classMeeting:
        return 'class';
      case SlotKind.approvedRequest:
        return 'approved room request';
      case SlotKind.pendingRequest:
        return 'room request waiting for a decision';
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = phase == SlotPhase.now && slot.isConfirmed;
    final past = phase == SlotPhase.past;
    final pending = slot.kind == SlotKind.pendingRequest;

    final Color accent = live ? Palette.brass400 : (pending ? Palette.amber400 : (slot.isRequest ? Palette.emerald400 : Palette.ink600));
    final Color bg = live ? Palette.brass50 : (past ? Palette.ink50 : (pending ? const Color(0xFFFFFBEB) : Colors.white));
    final Color border = live ? Palette.brass400 : (pending ? Palette.amber400.withValues(alpha: 0.6) : Palette.ink200);
    final Color text = past ? Palette.ink500 : Palette.ink900;
    final Color soft = past ? Palette.ink400 : Palette.ink600;
    final radius = BorderRadius.circular(12);

    final minutesLeft = slot.endMin - clock.minutes;
    final until = minutesUntilStart(slot, clock);
    final progress = ((clock.minutes - slot.startMin) / (slot.endMin - slot.startMin)).clamp(0.0, 1.0);

    final semantics = [
      '${fmtRange(slot.startTime, slot.endTime)}, ${slot.title}',
      if (slot.subtitle != null) slot.subtitle!,
      if (slot.instructorName != null) slot.instructorName!,
      _kindText,
      if (live) 'happening now',
      if (isNext) 'next',
      if (past) 'over',
    ].join(', ');

    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmtTime(slot.startTime), style: monoStyle(13, color: text, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(fmtTime(slot.endTime), style: monoStyle(12, color: Palette.ink500)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: bg, borderRadius: radius, border: Border.all(color: border, width: live ? 1.5 : 1)),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 5, color: past ? Palette.ink200 : accent),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (live) ...[
                              Row(
                                children: [
                                  Lamp(color: Palette.brass400, size: 8, pulse: true, off: Palette.ink500),
                                  const SizedBox(width: 7),
                                  Text('Happening now', style: bodyStyle(12.5, color: Palette.brass700, weight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ] else if (isNext) ...[
                              Text(until == null ? 'Next' : 'Next, in ${fmtSpan(until)}', style: bodyStyle(12.5, color: Palette.ink600, weight: FontWeight.w700)),
                              const SizedBox(height: 6),
                            ],
                            Wrap(
                              spacing: 8,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(slot.title, style: displayStyle(18, color: text, height: 1.2)),
                                if (slot.sectionCode != null) Text(slot.sectionCode!, style: monoStyle(12.5, color: soft)),
                              ],
                            ),
                            if (slot.subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(slot.subtitle!, style: bodyStyle(14, color: soft, height: 1.3))),
                            if (slot.instructorName != null) _meta(Icons.person_outline_rounded, slot.instructorName!, soft),
                            if (slot.reason != null) _meta(Icons.notes_rounded, slot.reason!, soft),
                            if (slot.isRequest) ...[
                              const SizedBox(height: 8),
                              Align(alignment: Alignment.centerLeft, child: ToneBadge(pending ? 'Waiting for a decision' : 'Approved request', pending ? Tone.warn : Tone.good)),
                            ],
                            if (live) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: Palette.brass100, color: Palette.brass500),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('ends in ${fmtSpan(minutesLeft)}', style: bodyStyle(12.5, color: Palette.brass700, weight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: bodyStyle(13.5, color: color, height: 1.3))),
        ],
      ),
    );
  }
}
