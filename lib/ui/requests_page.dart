import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'art.dart';
import 'theme.dart';
import 'widgets.dart';

/// Room requests from instructors, drawn as slips: the waiting ones have a perforated tear-off with Reject and
/// Approve on it, and the decided ones carry a stamp. Decisions work exactly as before; only the look changed.
class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key, required this.store});

  final AppStore store;

  Future<void> _approve(BuildContext context, RoomRequest r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve this request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            LedgerRow('Room', [r.roomCode ?? 'The room', if (r.roomName != null) r.roomName!].join(' · ')),
            const Divider(),
            LedgerRow('When', '${fmtDate(r.requestedFor)}, ${fmtRange(r.startTime, r.endTime)}'),
            if (r.instructorName != null) ...[
              const Divider(),
              LedgerRow('For', r.instructorName!),
            ],
            const Divider(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Palette.brass50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Palette.brass200)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.vpn_key_rounded, size: 18, color: Palette.brass600),
                  const SizedBox(width: 10),
                  Expanded(child: Text('The room key will open for the instructor during that time.', style: bodyStyle(14, color: Palette.brass700, height: 1.35))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Approve')),
        ],
      ),
    );
    if (yes == true) {
      HapticFeedback.mediumImpact();
      await store.decide(r, approve: true);
    }
  }

  Future<void> _reject(BuildContext context, RoomRequest r) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Write a short reason. The instructor will see it.', style: bodyStyle(14.5, color: Palette.ink700, height: 1.4)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: bodyStyle(16, color: Palette.ink900),
              decoration: const InputDecoration(labelText: 'Reason', fillColor: Palette.ink50),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.rose700),
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null) {
      HapticFeedback.mediumImpact();
      await store.decide(r, approve: false, note: note);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!store.requestsLoaded) return const SkeletonList(count: 3, height: 210);
    if (store.pending.isEmpty && store.decided.isEmpty && store.requestsError != null) {
      return StatusMessage(icon: Icons.cloud_off_outlined, text: store.requestsError!, isError: true, actionLabel: 'Try again', onAction: store.refreshRequests);
    }
    final notice = store.notice;
    return RefreshIndicator(
      color: Palette.brass500,
      onRefresh: store.refreshRequests,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: 28),
        children: [
          if (notice != null) NoticeBanner(notice, onClose: store.clearNotice),
          if (store.requestsError != null) StaleBanner(store.requestsError!),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader('Waiting for a decision', count: store.pending.isEmpty ? null : store.pending.length),
                if (store.pending.isEmpty)
                  const Reveal(child: _AllCaughtUp())
                else
                  for (var i = 0; i < store.pending.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    Reveal(
                      key: ValueKey<String>('pending-${store.pending[i].id}'),
                      index: i,
                      child: _PendingSlip(
                        request: store.pending[i],
                        busy: store.busyRequestId == store.pending[i].id,
                        locked: store.busyRequestId != null,
                        onApprove: () => _approve(context, store.pending[i]),
                        onReject: () => _reject(context, store.pending[i]),
                      ),
                    ),
                  ],
                SectionHeader('Latest decisions', count: store.decided.isEmpty ? null : store.decided.length),
                if (store.decided.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('Nothing has been decided yet.', style: bodyStyle(15, color: Palette.ink600)))
                else
                  for (var i = 0; i < store.decided.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Reveal(key: ValueKey<String>('decided-${store.decided[i].id}'), index: i, child: _DecidedSlip(request: store.decided[i])),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The empty state for the waiting list: an outline of a slip with nothing on it.
class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp();

  @override
  Widget build(BuildContext context) {
    return DashedBox(
      color: Palette.ink300,
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Palette.emerald100, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Palette.emerald800, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All caught up', style: displayStyle(21)),
                  const SizedBox(height: 2),
                  Text('No requests are waiting.', style: bodyStyle(14.5, color: Palette.ink600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sentText(RoomRequest r) {
  final at = r.createdAt == null ? null : DateTime.tryParse(r.createdAt!);
  return at == null ? '' : 'Sent ${fmtRelative(at.toLocal())}';
}

String _summaryOf(RoomRequest r) =>
    '${r.roomCode ?? 'Room'}${r.roomName == null ? '' : ', ${r.roomName}'}. ${fmtDate(r.requestedFor)}, ${fmtRange(r.startTime, r.endTime)}.${r.instructorName == null ? '' : ' ${r.instructorName}.'}'
    '${r.reason.trim().isEmpty ? '' : ' Reason: ${r.reason.trim()}.'}';

/// The part of a slip that says what was asked for: the tag, the day, the hours in large type, who and why.
class _SlipBody extends StatelessWidget {
  const _SlipBody({required this.request, required this.trailing, required this.tone});

  final RoomRequest request;
  final Widget trailing;
  final KeyTone tone;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final reason = r.reason.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: KeyTagChip(r.roomCode ?? 'Room', tone: tone, large: true)),
              const SizedBox(width: 10),
              if (r.roomName != null) Expanded(child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.roomName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(14, color: Palette.ink600)))) else const Spacer(),
              trailing,
            ],
          ),
          const SizedBox(height: 14),
          Text(fmtDate(r.requestedFor), style: bodyStyle(14, color: Palette.ink600, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(fmtRange(r.startTime, r.endTime), style: displayStyle(27, height: 1.15))),
          if (r.instructorName != null) ...[
            const SizedBox(height: 8),
            IconLine(Icons.person_outline_rounded, r.instructorName!),
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: Palette.ink50,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 3, child: ColoredBox(color: Palette.brass400)),
                      Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(11, 9, 12, 10), child: Text(reason, style: bodyStyle(14, color: Palette.ink700, height: 1.4)))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingSlip extends StatelessWidget {
  const _PendingSlip({required this.request, required this.busy, required this.locked, required this.onApprove, required this.onReject});

  final RoomRequest request;
  final bool busy;
  final bool locked;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final sent = _sentText(request);
    return Slip(
      accent: Palette.brass400,
      body: Semantics(
        container: true,
        label: 'Waiting for a decision. ${_summaryOf(request)}',
        excludeSemantics: true,
        child: _SlipBody(
          request: request,
          tone: KeyTone.brass,
          trailing: sent.isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 6, left: 8), child: Text(sent, style: bodyStyle(12, color: Palette.ink500))),
        ),
      ),
      actions: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: locked ? null : onReject,
                icon: const Icon(Icons.close_rounded, size: 20),
                label: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: locked ? null : onApprove,
                // while the decision is being saved the tick turns into a spinner
                icon: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.ink500))
                    : const Icon(Icons.check_rounded, size: 20),
                label: const Text('Approve'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecidedSlip extends StatelessWidget {
  const _DecidedSlip({required this.request});

  final RoomRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final Color ink;
    final Color tint;
    switch (r.status) {
      case 'approved':
        ink = Palette.emerald800;
        tint = Palette.emerald400;
      case 'rejected':
        ink = Palette.rose700;
        tint = Palette.rose400;
      default:
        ink = Palette.ink500;
        tint = Palette.ink300;
    }
    final decided = r.decidedAt == null ? null : DateTime.tryParse(r.decidedAt!);
    final note = r.decisionNote?.trim() ?? '';
    final label = requestStatusLabel(r.status);
    return Slip(
      accent: tint,
      body: Semantics(
        container: true,
        label: '$label. ${_summaryOf(r)}${note.isEmpty ? '' : ' Note: $note.'}${decided == null ? '' : ' Decided ${fmtRelative(decided.toLocal())}.'}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SlipBody(request: r, tone: KeyTone.ink, trailing: _Stamp(label: label, color: ink)),
            if (note.isNotEmpty || decided != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.isNotEmpty) IconLine(Icons.chat_bubble_outline_rounded, note),
                    if (decided != null) IconLine(Icons.history_rounded, 'Decided ${fmtRelative(decided.toLocal())}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The ink stamp on a decided slip: a double frame and the word, set at a slight angle as if pressed by hand.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Transform.rotate(
        angle: -0.12,
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.85), width: 1.5)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: color.withValues(alpha: 0.85), width: 1)),
            child: Text(label, style: displayStyle(19, color: color.withValues(alpha: 0.92), weight: FontWeight.w700, letterSpacing: 0.4, height: 1.2)),
          ),
        ),
      ),
    );
  }
}
