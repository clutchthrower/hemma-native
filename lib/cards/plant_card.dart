import 'package:flutter/material.dart';

import '../widgets/entity_watcher.dart';
import '../popups/plant_popup.dart';
import 'base_entity_card.dart';

/// Replicates `hemma_plant.yaml`'s health scoring: fraction of the plant's
/// `*_status` attributes reporting a good value.
class PlantCard extends StatelessWidget {
  final String plantEntityId;
  final int position;
  const PlantCard({super.key, required this.plantEntityId, this.position = 0});

  static const _statusKeys = ['moisture_status', 'temperature_status', 'illuminance_status', 'conductivity_status'];

  @override
  Widget build(BuildContext context) {
    return EntityWatcher(
      entityIds: [plantEntityId],
      builder: (context, states) {
        final entity = states[plantEntityId];
        final statuses = _statusKeys
            .map((k) => entity?.attributes[k] as String?)
            .where((v) => v != null)
            .toList();
        final total = statuses.length;
        final good = statuses.where((s) => s == 'ok' || s == 'good').length;
        final ratio = total > 0 ? good / total : 1.0;

        final label = ratio >= 1.0
            ? 'Healthy'
            : ratio >= 0.8
                ? 'Needs care'
                : ratio >= 0.6
                    ? 'Struggling'
                    : ratio >= 0.4
                        ? 'Poor'
                        : 'Critical';

        return HemmaEntityCard(
          iconName: 'plant',
          label: entity?.attr<String>('friendly_name', plantEntityId) ?? plantEntityId,
          stateText: label,
          active: ratio < 1.0,
          progress: ratio,
          position: position,
          onTap: () => showPlantPopup(context, plantEntityId),
        );
      },
    );
  }
}
