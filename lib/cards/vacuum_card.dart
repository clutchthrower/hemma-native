import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../widgets/entity_watcher.dart';
import 'base_entity_card.dart';

class VacuumCard extends StatelessWidget {
  final String entityId;
  final int position;
  /// Optional display-name override from the card config.
  final String? label;

  const VacuumCard(
      {super.key, required this.entityId, this.label, this.position = 0});

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StateStore>(context, listen: false);
    return EntityWatcher(
      entityIds: [entityId],
      builder: (context, states) {
        final entity = states[entityId];
        final state = entity?.state ?? 'docked';
        final icon = switch (state) {
          'cleaning' || 'returning' => 'vacuum-clean',
          'charging' => 'vacuum-charge',
          _ => 'vacuum',
        };
        final progress = entity?.attrDouble('battery_level') != null
            ? entity!.attrDouble('battery_level')! / 100
            : null;
        return HemmaEntityCard(
          iconName: icon,
          label: label ?? entity?.attr<String>('friendly_name', entityId) ?? entityId,
          stateText: state[0].toUpperCase() + state.substring(1),
          active: state == 'cleaning' || state == 'returning',
          position: position,
          progress: progress,
          onTap: () => store.callService(
            'vacuum',
            state == 'cleaning' ? 'return_to_base' : 'start',
            entityId: entityId,
          ),
        );
      },
    );
  }
}
