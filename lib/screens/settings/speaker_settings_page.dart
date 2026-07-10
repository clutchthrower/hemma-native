import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store/settings_store.dart';
import '../../widgets/entity_picker.dart';

/// Settings for "tablet as a speaker": enable the local Koti player server
/// + its mDNS advertisement, and let the user confirm which resulting HA
/// entity is this device (so the Music page can default to it) once the
/// Koti Home Assistant integration has auto-discovered it.
class SpeakerSettingsPage extends StatelessWidget {
  const SpeakerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Speaker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Use this tablet as a speaker'),
            subtitle: Text(
                'Makes "${settings.deviceName}" discoverable on the network as '
                'a Koti player — Home Assistant finds it automatically, no '
                'IP address or password to enter.'),
            value: settings.speakerEnabled,
            onChanged: settings.setSpeakerEnabled,
          ),
          if (settings.speakerEnabled) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('In Home Assistant',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 20),
              child: Text(
                'Install the Koti integration (not on HACS yet — copy '
                'custom_components/koti from the Koti GitHub repo into your HA '
                'config and restart). It discovers this tablet on its own; '
                'approve the notification when it appears and a player entity '
                'is created for it automatically.',
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('Which entity is this tablet?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text(
                'Once added, pick the resulting entity below so the Music '
                'page defaults to controlling this tablet.',
              ),
            ),
            EntityPickerField(
              label: 'This tablet\'s speaker entity',
              value: settings.selfSpeakerEntityId,
              domains: const ['media_player'],
              onChanged: settings.setSelfSpeakerEntityId,
            ),
          ],
        ],
      ),
    );
  }
}
