import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../widgets/entity_watcher.dart';
import 'base_entity_card.dart';

/// Replicates `hemma_motion.yaml`: aggregates up to 6 sensors, active if any
/// reports `on`, and labels itself after whichever sensor is currently active
/// (falling back to the most recently triggered one).
class MotionCard extends StatelessWidget {
  final List<String> sensorEntityIds;
  final List<String>? labels;
  final int position;

  const MotionCard({
    super.key,
    required this.sensorEntityIds,
    this.labels,
    this.position = 0,
  });

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StateStore>(context, listen: false);
    return EntityWatcher(
      entityIds: sensorEntityIds,
      builder: (context, states) {
        int? activeIndex;
        for (var i = 0; i < sensorEntityIds.length; i++) {
          if (states[sensorEntityIds[i]]?.state == 'on') {
            activeIndex = i;
            break;
          }
        }

        String label;
        if (activeIndex != null) {
          label = labels != null && activeIndex < labels!.length
              ? labels![activeIndex]
              : 'Motion';
        } else {
          label = 'No Motion';
        }

        String? mostRecentId;
        if (activeIndex == null && sensorEntityIds.isNotEmpty) {
          mostRecentId = sensorEntityIds.reduce((a, b) {
            final aTime = states[a]?.lastChanged ?? DateTime(0);
            final bTime = states[b]?.lastChanged ?? DateTime(0);
            return aTime.isAfter(bTime) ? a : b;
          });
        }

        return KotiEntityCard(
          iconName: 'motion',
          label: 'Motion',
          stateText: label,
          active: activeIndex != null,
          position: position,
          onTap: () {
            // "more-info" equivalent: surface the relevant sensor's raw state.
            final targetId = activeIndex != null
                ? sensorEntityIds[activeIndex]
                : mostRecentId;
            if (targetId == null) return;
            final entity = states[targetId] ?? store.get(targetId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$targetId: ${entity?.state ?? 'unknown'}')),
            );
          },
        );
      },
    );
  }
}
