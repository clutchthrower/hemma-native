import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/settings_store.dart';
import '../widgets/entity_watcher.dart';
import 'base_entity_card.dart';

class DoorbellCard extends StatelessWidget {
  final String entityId;
  final int position;
  /// Optional display-name override from the card config.
  final String? label;

  const DoorbellCard(
      {super.key, required this.entityId, this.label, this.position = 0});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsStore>(context, listen: false);
    return EntityWatcher(
      entityIds: [entityId],
      builder: (context, states) {
        final entity = states[entityId];
        return HemmaEntityCard(
          iconName: 'doorbell',
          label: label ?? entity?.attr<String>('friendly_name', entityId) ?? entityId,
          stateText: entity?.state ?? 'Idle',
          active: entity?.state == 'on',
          position: position,
          onTap: () {
            final url =
                '${settings.activeUrl}/api/camera_proxy/$entityId';
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Doorbell Camera'),
                content: Image.network(
                  url,
                  headers: {'Authorization': 'Bearer ${settings.accessToken}'},
                  errorBuilder: (_, __, ___) => const Text('Camera unavailable'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
