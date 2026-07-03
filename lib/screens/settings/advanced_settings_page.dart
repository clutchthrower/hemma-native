import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/ha_websocket_client.dart';
import '../../store/settings_store.dart';
import '../../store/state_store.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  bool _debugLog = false;
  final List<String> _log = [];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StateStore>();
    final settings = Provider.of<SettingsStore>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced / Developer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('WebSocket Status'),
            trailing: Text(_statusLabel(store.connectionStatus)),
          ),
          SwitchListTile(
            title: const Text('WebSocket Debug Log'),
            value: _debugLog,
            onChanged: (v) => setState(() => _debugLog = v),
          ),
          if (_debugLog)
            Container(
              height: 160,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                children: _log
                    .map((e) => Text(e, style: const TextStyle(color: Colors.greenAccent, fontSize: 11)))
                    .toList(),
              ),
            ),
          const Divider(height: 32),
          ListTile(
            title: const Text('State Inspector'),
            subtitle: Text('${store.all.length} entities cached'),
            onTap: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Entity States'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: ListView(
                    children: store.all.values
                        .map((e) => ListTile(
                              dense: true,
                              title: Text(e.entityId),
                              subtitle: Text('${e.state} · ${jsonEncode(e.attributes)}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('Force Refresh All States'),
            trailing: const Icon(Icons.refresh),
            onTap: () => store.forceRefresh(),
          ),
          ListTile(
            title: const Text('Clear Local State Cache'),
            trailing: const Icon(Icons.delete_outline),
            onTap: () => store.clearCache(),
          ),
          const Divider(height: 32),
          ListTile(
            title: const Text('Reset to Defaults'),
            textColor: Colors.red,
            onTap: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Reset all settings?'),
                content: const Text('This clears your connection, theme, and room configuration.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () {
                      settings.resetToDefaults();
                      Navigator.pop(context);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(HaConnectionStatus status) => switch (status) {
        HaConnectionStatus.connected => 'Connected',
        HaConnectionStatus.connecting => 'Connecting…',
        HaConnectionStatus.reconnecting => 'Reconnecting…',
        HaConnectionStatus.disconnected => 'Disconnected',
      };
}
