import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../widgets/entity_watcher.dart';
import 'base_entity_card.dart';

/// Replicates `hemma_lock.yaml`'s state-driven icon/label switching.
class LockCard extends StatelessWidget {
  final String entityId;
  final int position;
  /// Optional display-name override from the card config.
  final String? label;

  const LockCard(
      {super.key, required this.entityId, this.label, this.position = 0});

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StateStore>(context, listen: false);
    return EntityWatcher(
      entityIds: [entityId],
      builder: (context, states) {
        final entity = states[entityId];
        final state = entity?.state ?? 'locked';
        final (icon, stateLabel) = switch (state) {
          'unlocked' => ('lock-open', 'Unlocked'),
          'locking' => ('lock', 'Locking...'),
          'unlocking' => ('lock-unlocking', 'Unlocking...'),
          _ => ('lock', 'Locked'),
        };
        return HemmaEntityCard(
          iconName: icon,
          label: label ?? entity?.attr<String>('friendly_name', entityId) ?? entityId,
          stateText: stateLabel,
          active: state == 'unlocked',
          position: position,
          onTap: () => store.callService(
            'lock',
            state == 'unlocked' ? 'lock' : 'unlock',
            entityId: entityId,
          ),
        );
      },
    );
  }
}
