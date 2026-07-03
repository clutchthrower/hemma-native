import 'package:flutter/material.dart';

import '../widgets/entity_watcher.dart';
import '../popups/energy_popup.dart';
import 'base_entity_card.dart';

class EnergyCard extends StatelessWidget {
  final String powerSensorEntityId;
  final double highThreshold;
  final int position;

  const EnergyCard({
    super.key,
    required this.powerSensorEntityId,
    this.highThreshold = 500,
    this.position = 0,
  });

  @override
  Widget build(BuildContext context) {
    return EntityWatcher(
      entityIds: [powerSensorEntityId],
      builder: (context, states) {
        final entity = states[powerSensorEntityId];
        final watts = double.tryParse(entity?.state ?? '') ?? 0;
        return HemmaEntityCard(
          iconName: 'energy',
          label: entity?.attr<String>('friendly_name', 'Energy') ?? 'Energy',
          stateText: '${watts.toStringAsFixed(0)}W',
          active: watts > highThreshold,
          position: position,
          onTap: () => showEnergyPopup(context, powerSensorEntityId),
        );
      },
    );
  }
}
