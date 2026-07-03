import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/helper_store.dart';
import '../widgets/entity_watcher.dart';
import 'group_badge.dart';

class PresenceGroupBadge extends StatelessWidget {
  final List<String> personEntityIds;

  const PresenceGroupBadge({super.key, required this.personEntityIds});

  @override
  Widget build(BuildContext context) {
    final helpers = Provider.of<HelperStore>(context, listen: false);
    return EntityWatcher(
      entityIds: personEntityIds,
      builder: (context, states) {
        final away = personEntityIds.where((id) {
          final s = states[id]?.state;
          return s != null && s != 'home' && s != 'just_arrived';
        }).length;

        // Bold "People" + status sub-line, green person like the original.
        return GroupBadge(
          iconName: 'person',
          label: 'People',
          subLabel: away == 0 ? 'All Home' : '$away Away',
          accent: away == 0 ? const Color(0xFF4CD964) : Colors.white70,
          onTap: () => helpers.toggleExpandedRow(ExpandedRow.presence),
        );
      },
    );
  }
}
