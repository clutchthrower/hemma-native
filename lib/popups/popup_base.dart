import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/koti_theme.dart';

/// Popover-style popup that grows out of the widget that opened it (the
/// calling [context]'s render box): sized to its content, a bit wider than
/// its parent card, positioned adjacent to it — not a full-width sheet.
/// Falls back to a centered dialog when the caller has no usable anchor
/// (e.g. opened from the nav bar). Per CLAUDE.md, a solid translucent
/// background is tried first; here it wasn't enough on its own to keep
/// whatever's behind the card (room photo, room title text) from reading
/// through and blending with the popup's own text, so the card also gets a
/// real `BackdropFilter` blur — a single static blur region behind one
/// modal popup at a time, not a continuous/animated cost.
Future<T?> showKotiPopup<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final tokens = KotiTheme.of(context);
  final screen = MediaQuery.sizeOf(context);

  // Anchor = the widget this popup was opened from.
  Rect? anchor;
  final ro = context.findRenderObject();
  if (ro is RenderBox && ro.attached && ro.hasSize) {
    final rect = ro.localToGlobal(Offset.zero) & ro.size;
    // A "card-sized" anchor only — if the caller passed a whole-screen
    // context (nav, shell), treat it as unanchored and center instead.
    if (rect.width < screen.width * 0.7 && rect.height < screen.height * 0.5) {
      anchor = rect;
    }
  }

  final width = anchor == null
      ? (screen.width * 0.9).clamp(280.0, 460.0)
      : (anchor.width * 1.5).clamp(300.0, screen.width - 24.0).clamp(300.0, 480.0);

  // Horizontal: centered on the anchor, clamped inside the screen.
  final left = anchor == null
      ? (screen.width - width) / 2
      : (anchor.center.dx - width / 2).clamp(12.0, screen.width - width - 12.0);

  // Vertical: prefer opening upward from a bottom-row card; open downward
  // when the anchor sits high (badges); center when unanchored.
  double? top;
  double? bottom;
  Alignment growFrom = Alignment.center;
  double maxHeight = screen.height * 0.75;
  if (anchor != null) {
    final spaceAbove = anchor.top - 24;
    final spaceBelow = screen.height - anchor.bottom - 24;
    if (spaceAbove >= 220 || spaceAbove >= spaceBelow) {
      bottom = screen.height - anchor.top + 8;
      growFrom = Alignment.bottomCenter;
      maxHeight = spaceAbove.clamp(180.0, screen.height * 0.75);
    } else {
      top = anchor.bottom + 8;
      growFrom = Alignment.topCenter;
      maxHeight = spaceBelow.clamp(180.0, screen.height * 0.75);
    }
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, __) {
      final popup = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: width,
                decoration: BoxDecoration(
                  color: tokens.dialogBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(child: Builder(builder: builder)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      if (anchor == null) return Center(child: popup);
      return Stack(
        children: [
          Positioned(left: left, top: top, bottom: bottom, child: popup),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          alignment: growFrom,
          child: child,
        ),
      );
    },
  );
}

/// A `showDialog` confirm/detail dialog in the same glass-blurred style as
/// [showKotiPopup], instead of Flutter's stock `AlertDialog` — left
/// undecorated, that falls back to `ColorScheme.surface` (the warm
/// tan/charcoal this app uses for ordinary opaque surfaces, not the
/// translucent-blurred look every other popup in the app has). Same
/// title/content/actions shape as `AlertDialog` so call sites barely
/// change.
class KotiAlertDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const KotiAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: tokens.dialogBackground,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: DefaultTextStyle(
                    style: TextStyle(color: tokens.textSecondary, fontSize: 14),
                    child: content,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions[i],
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
