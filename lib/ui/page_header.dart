import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art.dart';
import 'theme.dart';

/// The steel header of a page the app pushes on top of the tabs (the camera view and the notifications):
/// a back button, an optional key tag, the title and a line under it, and an optional button on the right.
/// It matches the header of the home screen, with its drafting grid and brass edge.
class SubPageHeader extends StatelessWidget {
  const SubPageHeader({super.key, required this.title, this.subtitle, this.chip, this.trailing});

  final String title;
  final String? subtitle;

  /// a widget shown before the title, usually a [KeyTagChip]
  final Widget? chip;

  /// a widget at the right end, usually a text button
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.ink950, Palette.ink900])),
          child: Stack(
            children: [
              const Positioned.fill(child: ExcludeSemantics(child: IgnorePointer(child: DraftingGrid(opacity: 0.2, spacing: 20)))),
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
                  padding: const EdgeInsets.fromLTRB(4, 6, 8, 16),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 2),
                      if (chip != null) ...[ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: chip!), const SizedBox(width: 12)],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(header: true, child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: displayStyle(26, color: Colors.white, height: 1.1))),
                            if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(13, color: Palette.ink300)),
                          ],
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
