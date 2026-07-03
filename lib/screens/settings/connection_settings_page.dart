import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../store/settings_store.dart';

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
  String? _testResult;
  bool _testing = false;

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

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final url = _localUrlController.text.trim();
    final token = _tokenController.text.trim();
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse('$url/api/'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();
      if (response.statusCode == 200) {
        setState(() => _testResult =
            'Connected · ${stopwatch.elapsedMilliseconds}ms');
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
    final settings = context.watch<SettingsStore>();
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _testConnection,
                  child: Text(_testing ? 'Testing…' : 'Test Connection'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(_testResult!),
          ],
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
