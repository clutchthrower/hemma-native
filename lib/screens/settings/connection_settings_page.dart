import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store/settings_store.dart';

/// Identity/credentials only — reconnect interval, request timeout, and
/// Test Connection live under Diagnostics instead (they're live network
/// tuning tools you'd reach for while troubleshooting, not something you
/// set once and forget like a URL or token, so lumping them in here made
/// this page's save model inconsistent: URL/token/mode staged and only
/// committed on Save, while those tuning fields wrote immediately per
/// drag — splitting them out fixes that).
class ConnectionSettingsPage extends StatefulWidget {
  const ConnectionSettingsPage({super.key});

  @override
  State<ConnectionSettingsPage> createState() => _ConnectionSettingsPageState();
}

class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
  late final TextEditingController _localUrlController;
  late final TextEditingController _remoteUrlController;
  late final TextEditingController _tokenController;
  ConnectionMode _mode = ConnectionMode.localOnly;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsStore>(context, listen: false);
    _localUrlController = TextEditingController(text: settings.localUrl);
    _remoteUrlController = TextEditingController(text: settings.remoteUrl);
    _tokenController = TextEditingController(text: settings.accessToken ?? '');
    _mode = settings.connectionMode;
  }

  @override
  void dispose() {
    _localUrlController.dispose();
    _remoteUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = Provider.of<SettingsStore>(context, listen: false);
    await settings.setConnection(
      localUrl: _localUrlController.text.trim(),
      remoteUrl: _remoteUrlController.text.trim(),
      accessToken: _tokenController.text.trim(),
      mode: _mode,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection settings saved — restart to reconnect')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Home Assistant Instance', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _localUrlController,
            decoration: const InputDecoration(
              labelText: 'Local URL',
              hintText: 'http://192.168.1.100:8123',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remoteUrlController,
            decoration: const InputDecoration(
              labelText: 'Remote URL (optional)',
              hintText: 'https://myhome.duckdns.org',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Long-Lived Access Token',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Connection Mode', style: TextStyle(fontWeight: FontWeight.bold)),
          SegmentedButton<ConnectionMode>(
            segments: const [
              ButtonSegment(value: ConnectionMode.localOnly, label: Text('Local')),
              ButtonSegment(value: ConnectionMode.remoteOnly, label: Text('Remote')),
              ButtonSegment(value: ConnectionMode.auto, label: Text('Auto')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
