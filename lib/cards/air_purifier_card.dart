import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../widgets/entity_watcher.dart';
import 'base_entity_card.dart';

class AirPurifierCard extends StatelessWidget {
  final String entityId;
  final int position;
  const AirPurifierCard({super.key, required this.entityId, this.position = 0});

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StateStore>(context, listen: false);
    final domain = entityId.split('.').first;
    return EntityWatcher(
      entityIds: [entityId],
      builder: (context, states) {
        final entity = states[entityId];
        final active = entity?.state == 'on';
        return KotiEntityCard(
          iconName: 'purifier',
          label: entity?.attr<String>('friendly_name', entityId) ?? entityId,
          stateText: active ? 'On' : 'Off',
          active: active,
          position: position,
          onTap: () => store.callService(
            domain == 'humidifier' ? 'humidifier' : 'fan',
            'toggle',
            entityId: entityId,
          ),
        );
      },
    );
  }
}
