import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../widgets/entity_watcher.dart';
import 'base_entity_card.dart';

class HumidifierCard extends StatelessWidget {
  final String entityId;
  final int position;
  const HumidifierCard({super.key, required this.entityId, this.position = 0});

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StateStore>(context, listen: false);
    return EntityWatcher(
      entityIds: [entityId],
      builder: (context, states) {
        final entity = states[entityId];
        final active = entity?.state == 'on';
        return KotiEntityCard(
          iconName: active ? 'humidifier-on' : 'humidifier',
          label: entity?.attr<String>('friendly_name', entityId) ?? entityId,
          stateText: active ? 'On' : 'Off',
          active: active,
          position: position,
          onTap: () => store.callService('humidifier', 'toggle', entityId: entityId),
        );
      },
    );
  }
}
