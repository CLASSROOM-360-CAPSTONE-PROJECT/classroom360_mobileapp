import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/locker_view.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'art.dart';
import 'cameras_page.dart';
import 'inbox_page.dart';
import 'requests_page.dart';
import 'rooms_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// The signed-in app: three pages (Rooms, Requests, Cameras) over one [AppStore] that keeps itself fresh.
/// A steel header with the clock sits on top, and the pages are chosen from a locker-style bar at the bottom.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.backend, required this.profile, required this.onSignOut});

  final Backend backend;
  final Profile profile;
  final Future<void> Function() onSignOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late final AppStore _store = AppStore(widget.backend, timezone: widget.profile.timezone);
  StreamSubscription<InboxMessage>? _arrivalSub;
  int _tab = 0;

  static const _titles = ['Rooms', 'Requests', 'Cameras'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arrivalSub = _store.arrivals.listen(_announce);
    _store.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _arrivalSub?.cancel();
    _store.dispose();
    super.dispose();
  }

  /// A message that arrives while the app is open: a banner at the bottom with a button to read it.
  void _announce(InboxMessage m) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final urgent = m.severity == 'high';
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: urgent ? 10 : 6),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      content: Row(
        children: [
          Lamp(color: urgent ? Palette.rose400 : Palette.brass400, size: 10, pulse: urgent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(14.5, color: Colors.white, weight: FontWeight.w700)),
                if (m.body.isNotEmpty) Text(m.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(13, color: Palette.ink200, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
      action: SnackBarAction(label: 'View', onPressed: _openInbox),
    ));
  }

  void _pickTab(int i) {
    if (i != _tab) HapticFeedback.selectionClick();
    if (i != 1) _store.clearNotice();
    setState(() => _tab = i);
  }

  void _openInbox() {
    if (!mounted) return;
    Navigator.of(context).push(softRoute<void>((_) => InboxPage(store: _store, onOpenTab: _pickTab)));
  }

  /// No refreshing in the background (saves battery); load fresh data as soon as the app is back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _store.start();
    } else if (state == AppLifecycleState.paused) {
      _store.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _store.changes,
      initialData: _store.version,
      builder: (context, _) {
        final attention = _store.attentionCount;
        final waiting = _store.pending.length;
        final pages = <Widget>[
          RoomsPage(store: _store),
          RequestsPage(store: _store),
          CamerasPage(store: _store),
        ];
        return AnnotatedRegion<SystemUiOverlayStyle>(
          // light icons on the dark header, and the phone's own navigation bar in the same steel as ours
          value: SystemUiOverlayStyle.light.copyWith(
            systemNavigationBarColor: Palette.ink900,
            systemNavigationBarDividerColor: Palette.ink900,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            body: Column(
              children: [
                _Header(
                  title: _titles[_tab],
                  profile: widget.profile,
                  unread: _store.unread,
                  showBell: _store.inboxAvailable,
                  onBell: _openInbox,
                  onSignOut: widget.onSignOut,
                ),
                Expanded(child: PageWidth(child: IndexedStack(index: _tab, children: pages))),
              ],
            ),
            // the bar keeps its height when the phone's text size is turned up, like Material's own bar
            bottomNavigationBar: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: _LockerNavBar(
                selected: _tab,
                onSelected: _pickTab,
                items: [
                  _NavItem(label: 'Rooms', icon: Icons.meeting_room_outlined, selectedIcon: Icons.meeting_room_rounded, badge: attention, badgeNote: 'need attention', alert: true),
                  _NavItem(label: 'Requests', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, badge: waiting, badgeNote: 'waiting'),
                  const _NavItem(label: 'Cameras', icon: Icons.videocam_outlined, selectedIcon: Icons.videocam_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------------------------------------ the header

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.profile, required this.unread, required this.showBell, required this.onBell, required this.onSignOut});

  final String title;
  final Profile profile;
  final int unread;
  final bool showBell;
  final VoidCallback onBell;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final reduced = motionReduced(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.ink950, Palette.ink900])),
        child: Stack(
          children: [
            const Positioned.fill(child: ExcludeSemantics(child: IgnorePointer(child: DraftingGrid(opacity: 0.2, spacing: 20)))),
            // a thin brass edge along the bottom, brightest in the middle
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Palette.brass500.withValues(alpha: 0), Palette.brass400, Palette.brass500.withValues(alpha: 0)])),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
                child: Row(
                  children: [
                    const ExcludeSemantics(child: LogoMark(size: 40)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation), child: child),
                            ),
                            layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, if (current != null) current]),
                            child: Semantics(
                              key: ValueKey<String>(title),
                              header: true,
                              child: Text(title, style: displayStyle(28, color: Colors.white, height: 1.1)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const _HeaderClock(),
                        ],
                      ),
                    ),
                    if (showBell) _Bell(unread: unread, onTap: onBell),
                    _Avatar(profile: profile, onSignOut: onSignOut),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The phone's date and time under the page title, so a dean can see at a glance which class period it is.
/// It updates itself a few times a minute and only redraws when the minute changes.
class _HeaderClock extends StatefulWidget {
  const _HeaderClock();

  @override
  State<_HeaderClock> createState() => _HeaderClockState();
}

class _HeaderClockState extends State<_HeaderClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      final t = DateTime.now();
      if (!mounted || t.minute == _now.minute && t.hour == _now.hour && t.day == _now.day) return;
      setState(() => _now = t);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = '${_weekdayNames[_now.weekday - 1]}, ${_monthNames[_now.month - 1]} ${_now.day}';
    return Semantics(
      label: '$day, ${fmtClock(_now)}',
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.centerLeft,
        // on a very narrow phone the line shrinks a little instead of running under the buttons
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Lamp(color: Palette.emerald400, size: 6),
              const SizedBox(width: 8),
              Text(day, style: bodyStyle(13, color: Palette.ink300)),
              const SizedBox(width: 8),
              Text(fmtClock(_now), style: monoStyle(13, color: Palette.brass300)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      onPressed: onTap,
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_none_rounded, color: Palette.ink200, size: 26),
      ),
    );
  }
}

/// The round badge with the dean's initials, which opens a small menu with who is signed in and Sign out.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.onSignOut});

  final Profile profile;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final subtitle = [roleLabel(profile.role), if (profile.institution != null) profile.institution!].join(' · ');
    return PopupMenuButton<String>(
      tooltip: 'Account, ${profile.displayName}',
      offset: const Offset(0, 52),
      onSelected: (v) {
        if (v == 'out') onSignOut();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.displayName, style: bodyStyle(15, color: Palette.ink900, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: bodyStyle(12.5, color: Palette.ink600)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'out',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 20, color: Palette.ink700),
              const SizedBox(width: 12),
              Text('Sign out', style: bodyStyle(15, color: Palette.ink900, weight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.ink800,
              border: Border.all(color: Palette.brass400, width: 1.5),
            ),
            child: Text(initialsOf(profile.displayName), style: displayStyle(16, color: Palette.brass300, height: 1)),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ the bottom bar

class _NavItem {
  const _NavItem({required this.label, required this.icon, required this.selectedIcon, this.badge = 0, this.badgeNote = '', this.alert = false});

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// a count shown on the icon; 0 shows nothing
  final int badge;
  final String badgeNote;

  /// the count is a warning (amber) rather than a tally (brass)
  final bool alert;
}

/// The bottom bar, drawn as the bottom rail of the cabinet: dark steel with the chosen page lit by a brass lamp.
class _LockerNavBar extends StatelessWidget {
  const _LockerNavBar({required this.selected, required this.onSelected, required this.items});

  final int selected;
  final ValueChanged<int> onSelected;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.ink900,
        border: Border(top: BorderSide(color: Palette.ink700)),
        boxShadow: [BoxShadow(color: Color(0x330B1524), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _NavButton(item: items[i], selected: i == selected, onTap: () => onSelected(i))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = motionReduced(context) ? Duration.zero : const Duration(milliseconds: 240);
    final badgeColor = item.alert ? Palette.amber400 : Palette.brass400;
    return Semantics(
      button: true,
      selected: selected,
      label: item.badge > 0 ? '${item.label}, ${item.badge} ${item.badgeNote}' : item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        splashColor: Palette.brass400.withValues(alpha: 0.18),
        highlightColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // the lamp over the chosen page
            AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              width: selected ? 30 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: Palette.brass400,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                boxShadow: selected ? [BoxShadow(color: Palette.brass400.withValues(alpha: 0.7), blurRadius: 10)] : const [],
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    width: 56,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: selected ? Palette.brass400.withValues(alpha: 0.16) : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                    child: Badge(
                      isLabelVisible: item.badge > 0,
                      backgroundColor: badgeColor,
                      textColor: Palette.ink950,
                      label: Text(item.badge > 99 ? '99+' : '${item.badge}'),
                      child: Icon(selected ? item.selectedIcon : item.icon, size: 24, color: selected ? Palette.brass300 : Palette.ink400),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(item.label, style: bodyStyle(12, color: selected ? Colors.white : Palette.ink400, weight: selected ? FontWeight.w700 : FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
