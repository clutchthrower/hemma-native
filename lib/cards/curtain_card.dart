import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../widgets/entity_watcher.dart';
import 'base_entity_card.dart';

class CurtainCard extends StatelessWidget {
  final String entityId;
  final int position;
  /// Optional display-name override from the card config.
  final String? label;

  const CurtainCard(
      {super.key, required this.entityId, this.label, this.position = 0});

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StateStore>(context, listen: false);
    return EntityWatcher(
      entityIds: [entityId],
      builder: (context, states) {
        final entity = states[entityId];
        final open = entity?.state == 'open' || entity?.state == 'opening';
        final positionPct = entity?.attrDouble('current_position');
        return HemmaEntityCard(
          iconName: open ? 'curtain-open' : 'curtain-closed',
          label: label ?? entity?.attr<String>('friendly_name', entityId) ?? entityId,
          stateText: positionPct != null ? '${positionPct.toStringAsFixed(0)}%' : (entity?.state ?? 'Closed'),
          active: open,
          position: position,
          progress: positionPct != null ? positionPct / 100 : null,
          onTap: () => store.callService(
            'cover',
            open ? 'close_cover' : 'open_cover',
            entityId: entityId,
          ),
        );
      },
    );
  }
}
