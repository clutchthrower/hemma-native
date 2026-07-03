import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/helper_store.dart';
import '../widgets/entity_watcher.dart';
import 'group_badge.dart';

class LightGroupBadge extends StatelessWidget {
  final List<String> lightEntityIds;

  const LightGroupBadge({super.key, required this.lightEntityIds});

  @override
  Widget build(BuildContext context) {
    final helpers = Provider.of<HelperStore>(context, listen: false);
    return EntityWatcher(
      entityIds: lightEntityIds,
      builder: (context, states) {
        final onCount = lightEntityIds.where((id) => states[id]?.state == 'on').length;
        // Bold "Lights" + count sub-line, warm yellow bulb when any are on.
        return GroupBadge(
          iconName: 'light',
          label: 'Lights',
          subLabel: onCount > 0 ? '$onCount On' : 'Off',
          accent: onCount > 0 ? const Color(0xFFFFC531) : Colors.white70,
          onTap: () => helpers.toggleExpandedRow(ExpandedRow.lights),
        );
      },
    );
  }
}
