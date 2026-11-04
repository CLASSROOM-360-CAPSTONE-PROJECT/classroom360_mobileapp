import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/inbox.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'page_header.dart';
import 'theme.dart';
import 'widgets.dart';

/// The person's messages: new room requests, urgent alerts. Tapping one marks it read and goes to the page it is about.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key, required this.store, required this.onOpenTab});

  final AppStore store;

  /// switches the app to one of its pages (0 Rooms, 1 Requests, 2 Cameras)
  final void Function(int tab) onOpenTab;

  Future<void> _open(BuildContext context, InboxMessage m) async {
    final tab = tabForLink(m.link);
    final navigator = Navigator.of(context);
    final read = store.markRead(m);
    if (tab != null) {
      navigator.pop();
      onOpenTab(tab);
    }
    await read;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: store.changes,
      initialData: store.version,
      builder: (context, _) {
        final unread = store.unread;
        return Scaffold(
          body: Column(
            children: [
              SubPageHeader(
                title: 'Notifications',
                subtitle: !store.inboxLoaded ? null : (unread == 0 ? 'All read' : '$unread unread'),
                trailing: TextButton(
                  onPressed: unread == 0 ? null : store.markAllRead,
                  style: TextButton.styleFrom(foregroundColor: Palette.brass300, disabledForegroundColor: Palette.ink500, minimumSize: const Size(48, 48)),
                  child: const Text('Mark all read'),
                ),
              ),
              Expanded(child: PageWidth(child: _body(context))),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refresh() async {
    await store.sweepAlerts();
    await store.refreshInbox();
  }

  Widget _body(BuildContext context) {
    if (!store.inboxLoaded) return const SkeletonList(count: 4, height: 96);
    if (store.inbox.isEmpty) {
      return RefreshIndicator(
        color: Palette.brass500,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            StatusMessage(icon: Icons.notifications_none_rounded, text: 'Nothing yet. New room requests and urgent alerts will appear here.'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: Palette.brass500,
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        itemCount: store.inbox.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => Reveal(
          key: ValueKey<String>('note-${store.inbox[i].id}'),
          index: i,
          child: _MessageCard(message: store.inbox[i], onTap: () => _open(context, store.inbox[i])),
        ),
      ),
    );
  }
}

IconData _iconFor(String severity) {
  switch (severity) {
    case 'high':
      return Icons.priority_high_rounded;
    case 'medium':
      return Icons.schedule_rounded;
  }
  return Icons.notifications_none_rounded;
}

/// One message as a note pinned to the board: a stripe down the left edge in the colour of how urgent it is,
/// a round icon, and a lamp that is lit while the message is unread (and blinks if it is urgent).
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.onTap});

  final InboxMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final tone = toneColors(inboxTone(m.severity));
    final lamp = toneLamp(inboxTone(m.severity));
    final onWeb = m.link != null && tabForLink(m.link) == null;
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: '${m.isUnread ? 'Unread. ' : ''}${m.severity == 'info' ? '' : '${inboxSeverityLabel(m.severity)}. '}${m.title}. ${m.body}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: m.isUnread ? Palette.brass50 : Colors.white,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: m.isUnread ? Palette.brass200 : Palette.ink200)),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: m.severity == 'info' ? Palette.ink200 : lamp),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: tone.background, shape: BoxShape.circle),
                          child: Icon(_iconFor(m.severity), size: 20, color: tone.foreground),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m.isUnread)
                                    Padding(padding: const EdgeInsets.only(top: 5, right: 8), child: Lamp(color: lamp, size: 8, pulse: m.severity == 'high')),
                                  Expanded(
                                    child: Text(m.title, style: bodyStyle(15.5, color: Palette.ink900, weight: m.isUnread ? FontWeight.w700 : FontWeight.w500, height: 1.3)),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(fmtRelative(m.createdAt), style: monoStyle(11.5, color: Palette.ink500))),
                                ],
                              ),
                              if (m.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(m.body, style: bodyStyle(14, color: Palette.ink700, height: 1.4))),
                              if (m.severity != 'info') Padding(padding: const EdgeInsets.only(top: 8), child: ToneBadge(inboxSeverityLabel(m.severity), inboxTone(m.severity))),
                              if (onWeb) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Open this in the web app.', style: bodyStyle(12.5, color: Palette.ink500))),
                            ],
                          ),
                        ),
                      ],
                    ),
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
