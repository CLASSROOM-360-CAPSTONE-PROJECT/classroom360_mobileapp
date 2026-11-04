import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/locker_view.dart';
import '../core/models.dart';
import '../core/presence.dart';
import '../core/store.dart';
import 'cabinet.dart';
import 'camera_view_page.dart';
import 'ledger.dart';
import 'room_schedule.dart';
import 'theme.dart';
import 'widgets.dart';

/// Every room with what is going on in it now: the class, the key and the camera. A ledger plate gives the day's
/// figures, the key locker is drawn as a cabinet of doors, and the rooms follow, those that need a person to look
/// at them first.
class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key, required this.store});

  final AppStore store;

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  RoomFilter _filter = RoomFilter.all;

  AppStore get store => widget.store;

  void _openRoom(String roomId) {
    final room = store.roomById(roomId);
    if (room != null) showRoomSheet(context, store, room);
  }

  @override
  Widget build(BuildContext context) {
    if (!store.roomsLoaded) return const SkeletonList(count: 4, height: 140);
    if (store.rooms.isEmpty) {
      return StatusMessage(
        icon: store.roomsError != null ? Icons.cloud_off_outlined : Icons.meeting_room_outlined,
        text: store.roomsError ?? 'No rooms have been added yet.',
        isError: store.roomsError != null,
        actionLabel: 'Try again',
        onAction: store.refreshRooms,
      );
    }
    final all = store.sortedRooms;
    final shown = applyRoomFilter(all, _filter);
    final attention = store.attentionCount;
    final figures = LockerFigures.from(store.rooms, store.lockers);
    final keyOut = applyRoomFilter(all, RoomFilter.keyOut).length;

    return RefreshIndicator(
      color: Palette.brass500,
      onRefresh: () => Future.wait<void>([store.refreshRooms(), store.refreshCameras()]),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (store.roomsError != null) StaleBanner(store.roomsError!),
          const SizedBox(height: 14),
          Reveal(
            child: LedgerPlate(
              figures: [
                LedgerFigure(label: 'Rooms in use', value: figures.roomsInUse, lampsLit: figures.roomsInUse, lampsOf: figures.totalRooms, hint: 'of ${figures.totalRooms}'),
                LedgerFigure(label: 'Keys out', value: figures.keysOut, lampsLit: figures.keysOut, lampsOf: figures.doors, hint: 'for a class'),
                LedgerFigure(label: 'Not returned', value: figures.notReturned, bad: figures.notReturned > 0, lampsLit: figures.notReturned, lampsOf: figures.doors, hint: 'class ended'),
              ],
              footer: Row(
                children: [
                  Lamp(color: attention == 0 ? Palette.emerald400 : Palette.amber400, size: 8, pulse: attention > 0, off: Palette.ink700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      attention == 0 ? 'Nothing needs your attention right now.' : (attention == 1 ? '1 room needs your attention.' : '$attention rooms need your attention.'),
                      style: bodyStyle(13.5, color: attention == 0 ? Palette.ink300 : Palette.amber400, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (store.lockers.isNotEmpty) ...[
            const SectionHeader('The key locker'),
            Reveal(index: 1, child: KeyCabinet(lockers: store.lockers, onOpenRoom: _openRoom)),
          ],
          SectionHeader('Rooms', count: all.length),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                _FilterChip(label: 'All', count: all.length, selected: _filter == RoomFilter.all, onTap: () => setState(() => _filter = RoomFilter.all)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Needs a look', count: attention, selected: _filter == RoomFilter.attention, onTap: () => setState(() => _filter = RoomFilter.attention)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Key out', count: keyOut, selected: _filter == RoomFilter.keyOut, onTap: () => setState(() => _filter = RoomFilter.keyOut)),
              ],
            ),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: [
                  Text('No rooms match this filter.', style: bodyStyle(15, color: Palette.ink600)),
                  const SizedBox(height: 10),
                  TextButton(onPressed: () => setState(() => _filter = RoomFilter.all), child: const Text('Show all rooms')),
                ],
              ),
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Reveal(key: ValueKey<String>('room-${shown[i].roomId}'), index: i, child: _RoomCard(store: store, room: shown[i])),
            ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? Palette.ink900 : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? Palette.ink900 : Palette.ink300)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            if (!selected) HapticFeedback.selectionClick();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 6, 11, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: bodyStyle(14, color: selected ? Colors.white : Palette.ink800, weight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: selected ? Palette.brass400 : Palette.ink100, borderRadius: BorderRadius.circular(999)),
                      child: Text('$count', style: monoStyle(12.5, color: selected ? Palette.ink950 : Palette.ink700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ the words about a room

String _keyText(AppStore store, RoomStatus room) {
  final locker = store.lockerForRoom(room.roomId);
  final label = keyLabel(room.keyStatus);
  if (locker == null || locker.holderName == null || room.keyStatus == 'available') return label;
  final since = locker.issuedAt == null ? null : DateTime.tryParse(locker.issuedAt!);
  return '$label · ${locker.holderName}${since == null ? '' : ' since ${fmtClock(since.toLocal())}'}';
}

String _cameraText(AppStore store, RoomStatus room) {
  if (store.cameraForRoom(room.roomId) == null && room.isOccupied == null) return 'No camera report';
  final people = peopleText(room.personCount, room.isOccupied);
  final at = room.occupancyAt == null ? null : DateTime.tryParse(room.occupancyAt!);
  return at == null ? 'Camera: $people' : 'Camera: $people · ${fmtRelative(at.toLocal())}';
}

String _classText(RoomStatus room) {
  final what = [if (room.courseCode != null) room.courseCode!, if (room.sectionCode != null) room.sectionCode!].join(' · ');
  return [if (what.isNotEmpty) what, fmtRange(room.startTime!, room.endTime!), if (room.instructorName != null) room.instructorName!].join(' · ');
}

// ------------------------------------------------------------------------------------------------ the room card

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.store, required this.room});

  final AppStore store;
  final RoomStatus room;

  @override
  Widget build(BuildContext context) {
    final info = presenceInfo(room.presence);
    final fallback = discrepancyLabel(room.discrepancy);
    final attention = needsAttention(room);
    final doorNo = doorNumberFor(room.roomId, store.lockers);
    final out = room.keyStatus == 'issued';
    final late = room.keyStatus == 'outstanding' || info?.tone == Tone.bad;

    final Color edge;
    if (late) {
      edge = Palette.rose300;
    } else if (attention) {
      edge = Palette.amber400;
    } else if (out) {
      edge = Palette.brass300;
    } else {
      edge = Palette.ink200;
    }
    final lampColor = room.keyStatus == 'outstanding' ? Palette.rose400 : Palette.brass400;
    final radius = BorderRadius.circular(16);

    return Semantics(
      button: true,
      label: '${room.roomCode}${room.roomName == null ? '' : ', ${room.roomName}'}. ${info?.label ?? fallback ?? ''}. ${_keyText(store, room)}. ${_cameraText(store, room)}',
      excludeSemantics: true,
      onTap: () => showRoomSheet(context, store, room),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: const [BoxShadow(color: Color(0x0F0B1524), blurRadius: 12, offset: Offset(0, 4))]),
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: edge, width: attention || out ? 1.5 : 1)),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              showRoomSheet(context, store, room);
            },
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // the hinge side of the door: its number and its lamp
                  Container(
                    width: 52,
                    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.ink800, Palette.steelDeep])),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (doorNo != null) ...[
                          Text('Door', style: bodyStyle(10.5, color: Palette.ink300)),
                          Text('$doorNo', style: displayStyle(28, color: Palette.brass300, height: 1.1)),
                        ] else
                          Text('No\ndoor', textAlign: TextAlign.center, style: bodyStyle(10.5, color: Palette.ink400, height: 1.2)),
                        const SizedBox(height: 10),
                        Lamp(color: lampColor, size: 9, lit: out || room.keyStatus == 'outstanding', pulse: room.keyStatus == 'outstanding', off: Palette.ink500),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: KeyTagChip(room.roomCode, tone: keyToneFor(room.keyStatus), large: true)),
                              const SizedBox(width: 10),
                              if (room.roomName != null) Expanded(child: Text(room.roomName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(14, color: Palette.ink600))) else const Spacer(),
                              const Icon(Icons.chevron_right_rounded, color: Palette.ink300),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (info != null) ToneBadge(info.label, info.tone) else if (fallback != null) ToneBadge(fallback, Tone.warn),
                          if (room.hasClassNow) IconLine(Icons.schedule_rounded, _classText(room)),
                          IconLine(Icons.vpn_key_outlined, _keyText(store, room)),
                          IconLine(Icons.videocam_outlined, _cameraText(store, room)),
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
    );
  }
}

// ------------------------------------------------------------------------------------------------ the room sheet

/// Everything about one room, from the bottom of the screen: why it is flagged, the class, the key and the camera.
void showRoomSheet(BuildContext context, AppStore store, RoomStatus room) {
  final info = presenceInfo(room.presence);
  final camera = store.cameraForRoom(room.roomId);
  final doorNo = doorNumberFor(room.roomId, store.lockers);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.white,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    builder: (sheetContext) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Palette.ink900,
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Palette.ink600, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Flexible(child: KeyTagChip(room.roomCode, tone: keyToneFor(room.keyStatus), large: true)),
                    const Spacer(),
                    if (doorNo != null) Text('Door', style: bodyStyle(12.5, color: Palette.ink300)),
                    if (doorNo != null) const SizedBox(width: 5),
                    if (doorNo != null) Text('$doorNo', style: displayStyle(26, color: Palette.brass300, height: 1.1)),
                    IconButton(onPressed: () => Navigator.of(sheetContext).pop(), tooltip: 'Close', icon: const Icon(Icons.close_rounded, color: Palette.ink300)),
                  ],
                ),
                const SizedBox(height: 8),
                if (room.roomName != null) Text(room.roomName!, style: displayStyle(24, color: Colors.white)),
                if (room.buildingName != null || room.floor != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text([if (room.buildingName != null) room.buildingName!, if (room.floor != null) 'Floor ${room.floor}'].join(' · '), style: bodyStyle(13.5, color: Palette.ink300)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info != null) ...[
                  Align(alignment: Alignment.centerLeft, child: ToneBadge(info.label, info.tone)),
                  const SizedBox(height: 10),
                  Text(info.why, style: bodyStyle(15.5, color: Palette.ink800, height: 1.45)),
                ] else
                  Text('No combined key and camera reading is available for this room yet.', style: bodyStyle(15.5, color: Palette.ink800, height: 1.45)),
                const SizedBox(height: 14),
                const Divider(),
                LedgerRow('Class', room.hasClassNow ? _classText(room) : 'Nothing scheduled now'),
                const Divider(),
                LedgerRow('Key', _keyText(store, room), valueColor: room.keyStatus == 'outstanding' ? Palette.rose700 : Palette.ink900),
                const Divider(),
                LedgerRow('Camera', _cameraText(store, room).replaceFirst('Camera: ', '')),
                const Divider(),
                const SizedBox(height: 16),
                // the room's week: its classes and approved requests, with what is on now picked out
                RoomScheduleSection(store: store, roomId: room.roomId),
                const SizedBox(height: 22),
                if (camera != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Watch the camera'),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(softRoute<void>((_) => CameraViewPage(store: store, camera: camera)));
                    },
                  )
                else
                  Text('No camera has been set up for this room.', style: bodyStyle(14, color: Palette.ink600)),
                SafeArea(top: false, child: const SizedBox(height: 4)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
