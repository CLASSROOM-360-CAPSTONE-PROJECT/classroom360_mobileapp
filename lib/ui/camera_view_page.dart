import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/feed.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/presence.dart';
import '../core/store.dart';
import '../core/whep.dart';
import '../data/webrtc_feed.dart';
import 'art.dart';
import 'page_header.dart';
import 'theme.dart';
import 'widgets.dart';

/// One camera, live. The picture comes straight from the school's camera gateway over the school
/// network; the signed-in person's token is shown to the gateway, which asks Supabase whether they
/// may watch. Below the picture is what the key locker and the camera say about the room.
class CameraViewPage extends StatefulWidget {
  const CameraViewPage({super.key, required this.store, required this.camera});

  final AppStore store;
  final CameraRow camera;

  @override
  State<CameraViewPage> createState() => _CameraViewPageState();
}

class _CameraViewPageState extends State<CameraViewPage> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  CameraFeed? _feed;
  FeedState _state = const FeedState.connecting();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await _renderer.initialize();
    if (!mounted) return;
    final url = whepUrl(widget.camera.gatewayUrl, widget.camera.streamPath);
    final feed = CameraFeed(
      getToken: widget.store.backend.accessToken,
      connect: (token, onLost) async {
        final session = await WebRtcFeedSession.connect(url, token, onLost);
        _renderer.srcObject = session.stream;
        return session;
      },
      onChanged: (s) {
        if (!mounted) return;
        setState(() => _state = s);
      },
    );
    setState(() {
      _feed = feed;
      _ready = true;
    });
    feed.start();
  }

  @override
  void dispose() {
    final feed = _feed;
    _feed = null;
    () async {
      await feed?.stop();
      _renderer.srcObject = null;
      await _renderer.dispose();
    }();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.camera;
    final room = widget.store.roomById(c.roomId);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            SubPageHeader(title: c.label, subtitle: c.roomName, chip: KeyTagChip(c.roomCode ?? 'Room', tone: keyToneFor(room?.keyStatus), large: true)),
            Expanded(
              child: PageWidth(
                child: StreamBuilder<int>(
                  stream: widget.store.changes,
                  initialData: widget.store.version,
                  builder: (context, _) => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _monitor(),
                      const SizedBox(height: 16),
                      _roomSummary(),
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

  /// The picture in a steel bezel, with the viewfinder corners and a lamp that says whether it is live.
  Widget _monitor() {
    final phase = _state.phase;
    final String status;
    final Color lamp;
    switch (phase) {
      case FeedPhase.live:
        status = 'Live';
        lamp = Palette.emerald400;
      case FeedPhase.connecting:
        status = 'Connecting';
        lamp = Palette.amber400;
      case FeedPhase.problem:
        status = _state.retrying ? 'Reconnecting' : 'Offline';
        lamp = Palette.rose400;
    }
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Camera ${status.toLowerCase()}',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Palette.ink900,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Palette.ink700, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x4D0B1524), blurRadius: 18, spreadRadius: -6, offset: Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_ready) RTCVideoView(_renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
                  if (phase != FeedPhase.live) _overlay(),
                  ViewfinderCorners(color: phase == FeedPhase.live ? const Color(0x99FFFFFF) : const Color(0x80E3B96A)),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
                        decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Lamp(color: lamp, size: 8, pulse: phase != FeedPhase.live),
                            const SizedBox(width: 7),
                            Text(status, style: bodyStyle(12.5, color: Colors.white, weight: FontWeight.w600)),
                          ],
                        ),
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

  Widget _overlay() {
    if (_state.phase == FeedPhase.connecting) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.ink950, Palette.steelDeep]))),
          const ScopeGrid(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: Palette.brass400)),
                const SizedBox(height: 14),
                Text('Connecting to the camera…', style: bodyStyle(14, color: Colors.white)),
              ],
            ),
          ),
        ],
      );
    }
    final denied = _state.kind == WhepFailure.denied;
    return Container(
      color: const Color(0xF20B1524),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.rose400.withValues(alpha: 0.14), border: Border.all(color: Palette.rose300, width: 1.5)),
                child: Icon(denied ? Icons.lock_outline_rounded : Icons.videocam_off_outlined, color: Palette.rose300, size: 24),
              ),
              const SizedBox(height: 10),
              Text(_state.message ?? 'The picture is not available.', textAlign: TextAlign.center, style: bodyStyle(14, color: Colors.white, height: 1.35)),
              if (_state.retrying) ...[
                const SizedBox(height: 6),
                Text('Trying again by itself…', style: bodyStyle(12, color: Palette.ink300)),
              ],
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  side: const BorderSide(color: Palette.brass400),
                ),
                onPressed: _feed?.retryNow,
                child: const Text('Try again now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roomSummary() {
    final room = widget.store.roomById(widget.camera.roomId);
    if (room == null) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(18), child: Text('Room information is not available.', style: bodyStyle(15, color: Palette.ink600))),
      );
    }
    final info = presenceInfo(room.presence);
    final at = room.occupancyAt == null ? null : DateTime.tryParse(room.occupancyAt!);
    final classText = room.hasClassNow
        ? [
            if (room.courseCode != null) room.courseCode!,
            fmtRange(room.startTime!, room.endTime!),
            if (room.instructorName != null) room.instructorName!,
          ].join(' · ')
        : 'Nothing scheduled now';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('The room right now', style: displayStyle(21))),
                if (info != null) Flexible(child: ToneBadge(info.label, info.tone)),
              ],
            ),
            if (info != null) ...[
              const SizedBox(height: 8),
              Text(info.why, style: bodyStyle(15, color: Palette.ink800, height: 1.45)),
            ],
            const SizedBox(height: 10),
            const Divider(),
            LedgerRow('Class', classText),
            const Divider(),
            LedgerRow('Key', keyLabel(room.keyStatus), valueColor: room.keyStatus == 'outstanding' ? Palette.rose700 : Palette.ink900),
            const Divider(),
            LedgerRow('Camera', '${peopleText(room.personCount, room.isOccupied)}${at == null ? '' : ' · ${fmtRelative(at.toLocal())}'}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Palette.ink50, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Palette.ink500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The count comes from a phone, tablet or computer that is watching this camera. This page only shows the picture; it does not count people itself.',
                      style: bodyStyle(12.5, color: Palette.ink600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
