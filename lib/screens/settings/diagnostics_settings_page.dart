import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../api/ha_websocket_client.dart';
import '../../store/settings_store.dart';
import '../../store/state_store.dart';
import '../../theme/koti_theme.dart';
import '../../widgets/koti_switch.dart';

/// Live network tuning + troubleshooting tools — split out from Connection
/// (which now only holds identity/credentials, staged + saved explicitly)
/// so this page's controls, which all apply immediately, don't share a
/// page with fields that only take effect on Save.
class DiagnosticsSettingsPage extends StatefulWidget {
  const DiagnosticsSettingsPage({super.key});

  @override
  State<DiagnosticsSettingsPage> createState() => _DiagnosticsSettingsPageState();
}

class _DiagnosticsSettingsPageState extends State<DiagnosticsSettingsPage> {
  String? _testResult;
  bool _testing = false;

  Future<void> _testConnection(SettingsStore settings) async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse('${settings.localUrl}/api/'),
              headers: {'Authorization': 'Bearer ${settings.accessToken}'})
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();
      if (response.statusCode == 200) {
        setState(() => _testResult = 'Connected · ${stopwatch.elapsedMilliseconds}ms');
      } else if (response.statusCode == 401) {
        setState(() => _testResult = 'Unauthorized — check your access token');
      } else {
        setState(() => _testResult = 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _testResult = 'Failed: $e');
    } finally {
      setState(() => _testing = false);
    }
  }

  void _resetHome(SettingsStore settings) {
    settings.setHomeRoom(null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Home reset to automatic')),
    );
  }

  void _factoryReset(SettingsStore settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all settings?'),
        content: const Text(
            'This clears your connection, theme, and room configuration. '
            'You\'ll go through setup again next launch. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              settings.resetToDefaults();
              context.read<ThemeController>().resetToDefaults();
              Navigator.pop(context);
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StateStore>();
    final settings = context.watch<SettingsStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Reconnect interval: ${settings.reconnectSeconds}s'),
          Slider(
            value: settings.reconnectSeconds.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: '${settings.reconnectSeconds}s',
            onChanged: (v) => settings.setReconnectSeconds(v.round()),
          ),
          Text('Request timeout: ${settings.timeoutSeconds}s'),
          Slider(
            value: settings.timeoutSeconds.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            label: '${settings.timeoutSeconds}s',
            onChanged: (v) => settings.setTimeoutSeconds(v.round()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : () => _testConnection(settings),
                  child: Text(_testing ? 'Testing…' : 'Test Connection'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(_testResult!),
          ],
          const Divider(height: 32),
          ListTile(
            title: const Text('WebSocket Status'),
            trailing: Text(_statusLabel(store.connectionStatus)),
          ),
          KotiSwitchListTile(
            title: const Text('WebSocket Debug Log'),
            value: store.ws.debugLoggingEnabled,
            onChanged: (v) => setState(() {
              store.ws.debugLoggingEnabled = v;
              if (!v) store.ws.clearDebugLog();
            }),
          ),
          if (store.ws.debugLoggingEnabled) _DebugLogView(client: store.ws),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Reset',
                style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          ListTile(
            title: const Text('Reset Home'),
            subtitle: const Text('Go back to the automatic whole-home Home tab'),
            onTap: settings.homeRoom == null ? null : () => _resetHome(settings),
          ),
          ListTile(
            title: const Text('Factory Reset'),
            subtitle: const Text('Wipes connection, theme, and room configuration'),
            textColor: Colors.red,
            onTap: () => _factoryReset(settings),
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

class _DebugLogView extends StatelessWidget {
  final HaWebSocketClient client;
  const _DebugLogView({required this.client});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<WsDebugFrame>>(
      valueListenable: client.debugLog,
      builder: (context, frames, _) {
        return Container(
          height: 220,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: frames.isEmpty
              ? const Center(
                  child: Text('Waiting for traffic…',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                )
              : ListView.builder(
                  reverse: true,
                  itemCount: frames.length,
                  itemBuilder: (context, i) {
                    final frame = frames[frames.length - 1 - i];
                    final time = frame.timestamp.toIso8601String().substring(11, 23);
                    final arrow = frame.outgoing ? '→' : '←';
                    final color = frame.outgoing ? Colors.lightBlueAccent : Colors.greenAccent;
                    return Text(
                      '$time $arrow ${frame.raw}',
                      style: TextStyle(color: color, fontSize: 11, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
        );
      },
    );
  }
}
