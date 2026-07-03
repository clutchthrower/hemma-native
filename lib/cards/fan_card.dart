import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../widgets/entity_watcher.dart';
import 'base_entity_card.dart';

class FanCard extends StatelessWidget {
  final String entityId;
  final int position;
  /// Optional display-name override from the card config.
  final String? label;

  const FanCard(
      {super.key, required this.entityId, this.label, this.position = 0});

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StateStore>(context, listen: false);
    return EntityWatcher(
      entityIds: [entityId],
      builder: (context, states) {
        final entity = states[entityId];
        final active = entity?.state == 'on';
        return HemmaEntityCard(
          iconName: 'fan',
          label: label ?? entity?.attr<String>('friendly_name', entityId) ?? entityId,
          stateText: active ? 'On' : 'Off',
          active: active,
          position: position,
          onTap: () => store.callService('fan', 'toggle', entityId: entityId),
        );
      },
    );
  }
}
