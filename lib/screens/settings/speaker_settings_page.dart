import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../speaker/kiosk_audio_server.dart';
import '../../store/settings_store.dart';
import '../../widgets/entity_picker.dart';

/// Settings for "tablet as a speaker": enable the local Fully Kiosk-
/// compatible audio server, show the connection info to paste into Music
/// Assistant's Fully Kiosk player provider, and let the user confirm which
/// resulting HA entity is this device (so the Music page can default to it).
class SpeakerSettingsPage extends StatefulWidget {
  const SpeakerSettingsPage({super.key});

  @override
  State<SpeakerSettingsPage> createState() => _SpeakerSettingsPageState();
}

class _SpeakerSettingsPageState extends State<SpeakerSettingsPage> {
  String? _ip;
  late final TextEditingController _passwordController;
  // Enabling the feature generates a password asynchronously (after this
  // widget's initState already ran with an empty value), and toggling the
  // switch on this same page rebuilds it — keep the field in sync with
  // that generated value until the user actually starts editing it.
  bool _userEditedPassword = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsStore>(context, listen: false);
    _passwordController = TextEditingController(text: settings.speakerPassword);
    _loadIp();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadIp() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            if (mounted) setState(() => _ip = addr.address);
            return;
          }
        }
      }
    } catch (_) {
      // Leave _ip null — shown as "unavailable" below.
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final deviceName = 'Koti (${settings.deviceId.substring(0, settings.deviceId.length.clamp(0, 6))})';

    if (!_userEditedPassword && _passwordController.text != settings.speakerPassword) {
      _passwordController.text = settings.speakerPassword;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Speaker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Use this tablet as a speaker'),
            subtitle: const Text(
                'Runs a local server that Music Assistant\'s built-in "Fully '
                'Kiosk" player provider can control directly — no custom '
                'Home Assistant integration to install.'),
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
              padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text(
                'Music Assistant → Settings → Player Providers → add "Fully '
                'Kiosk Browser", then add a player with:',
              ),
            ),
            _InfoRow(label: 'Host', value: _ip ?? 'Looking up…'),
            _InfoRow(label: 'Port', value: '${KioskAudioServer.defaultPort}'),
            _InfoRow(label: 'Password', value: settings.speakerPassword),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'Change this before adding the player in MA if you want '
                    'something other than the generated one.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _userEditedPassword = true,
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) settings.setSpeakerPassword(v.trim());
              },
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('Which entity is this tablet?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text(
                'After adding the player above, Music Assistant names the '
                'resulting entity after this device\'s reported name '
                '("$deviceName" by default). Pick it below so the Music page '
                'defaults to controlling this tablet.',
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Theme.of(context).hintColor))),
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy',
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
          ),
        ],
      ),
    );
  }
}
