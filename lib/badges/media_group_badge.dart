import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/helper_store.dart';
import '../theme/tokens.dart';
import '../widgets/entity_watcher.dart';
import 'group_badge.dart';

class MediaGroupBadge extends StatelessWidget {
  final List<String> mediaPlayerEntityIds;
  final int pauseTimeoutMinutes;

  /// Normally the badge hides when nothing is playing; edit mode needs it
  /// visible so it can carry its ✕/tap-to-edit chrome.
  final bool showWhenIdle;

  const MediaGroupBadge({
    super.key,
    required this.mediaPlayerEntityIds,
    this.pauseTimeoutMinutes = 5,
    this.showWhenIdle = false,
  });

  @override
  Widget build(BuildContext context) {
    final helpers = Provider.of<HelperStore>(context, listen: false);
    return EntityWatcher(
      entityIds: mediaPlayerEntityIds,
      builder: (context, states) {
        final activeCount = mediaPlayerEntityIds.where((id) {
          final e = states[id];
          if (e == null) return false;
          if (e.state == 'playing' || e.state == 'buffering' || e.state == 'on') return true;
          if (e.state == 'paused') {
            final elapsed = DateTime.now().difference(e.lastChanged);
            return elapsed.inMinutes < pauseTimeoutMinutes;
          }
          return false;
        }).length;

        if (activeCount == 0 && !showWhenIdle) return const SizedBox.shrink();

        return GroupBadge(
          iconName: 'speaker',
          label: 'Media',
          subLabel: activeCount == 0
              ? '${mediaPlayerEntityIds.length} Players'
              : '$activeCount Playing',
          // hemma-badge-media-color
          accent: activeCount == 0 ? KotiTokens.secondaryOnDark : const Color(0xFFFF4D70),
          onTap: () => helpers.toggleExpandedRow(ExpandedRow.media),
        );
      },
    );
  }
}
