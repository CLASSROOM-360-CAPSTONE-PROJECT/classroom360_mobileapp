import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/presence.dart';
import '../core/store.dart';
import 'art.dart';
import 'camera_view_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// The classroom cameras, each a monitor in a steel frame. Press one to watch it live.
class CamerasPage extends StatelessWidget {
  const CamerasPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    if (!store.camerasLoaded) return const SkeletonList(count: 3, height: 230);
    final cameras = store.activeCameras;
    if (cameras.isEmpty) {
      return StatusMessage(
        icon: store.camerasError != null ? Icons.cloud_off_outlined : Icons.videocam_off_outlined,
        text: store.camerasError ?? 'No cameras are set up yet. An administrator adds them on the Cameras page of the web app.',
        isError: store.camerasError != null,
        actionLabel: 'Try again',
        onAction: store.refreshCameras,
      );
    }
    return RefreshIndicator(
      color: Palette.brass500,
      onRefresh: store.refreshCameras,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          if (store.camerasError != null) StaleBanner(store.camerasError!),
          SectionHeader(cameras.length == 1 ? 'Camera' : 'Cameras', count: cameras.length),
          for (var i = 0; i < cameras.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            Reveal(key: ValueKey<String>('camera-${cameras[i].id}'), index: i, child: _CameraTile(store: store, camera: cameras[i])),
          ],
        ],
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.store, required this.camera});

  final AppStore store;
  final CameraRow camera;

  @override
  Widget build(BuildContext context) {
    final c = camera;
    final room = store.roomById(c.roomId);
    final info = presenceInfo(room?.presence);
    final radius = BorderRadius.circular(18);
    void open() {
      HapticFeedback.selectionClick();
      Navigator.of(context).push(softRoute<void>((_) => CameraViewPage(store: store, camera: c)));
    }
    return Semantics(
      button: true,
      label: 'Watch ${c.roomCode ?? 'room'} camera, ${c.label}${c.roomName == null ? '' : ', ${c.roomName}'}${info == null ? '' : '. ${info.label}'}',
      excludeSemantics: true,
      onTap: open,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: const [BoxShadow(color: Color(0x1F0B1524), blurRadius: 16, offset: Offset(0, 6))]),
        child: Material(
          color: Palette.ink900,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: Palette.ink700, width: 1.5)),
          child: InkWell(
            onTap: open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.ink950, Palette.steelDeep]))),
                      const ScopeGrid(),
                      const ViewfinderCorners(color: Color(0x80E3B96A)),
                      Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Palette.brass400.withValues(alpha: 0.16),
                            border: Border.all(color: Palette.brass300, width: 2),
                            boxShadow: [BoxShadow(color: Palette.brass400.withValues(alpha: 0.35), blurRadius: 20)],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, size: 34, color: Palette.brass300),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        top: 18,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: KeyTagChip(c.roomCode ?? 'Room', tone: keyToneFor(room?.keyStatus), large: true)),
                            const SizedBox(width: 8),
                            if (info != null) Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Align(alignment: Alignment.centerRight, child: ToneBadge(info.label, info.tone)))) else const Spacer(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Palette.ink800,
                  padding: const EdgeInsets.fromLTRB(18, 13, 12, 13),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_rounded, size: 20, color: Palette.ink300),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(15, color: Colors.white, weight: FontWeight.w600)),
                            if (c.roomName != null) Text(c.roomName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(13, color: Palette.ink300)),
                          ],
                        ),
                      ),
                      Text('Watch', style: bodyStyle(14, color: Palette.brass300, weight: FontWeight.w700)),
                      const Icon(Icons.chevron_right_rounded, color: Palette.brass300),
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
