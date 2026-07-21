import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/app_update.dart';
import '../../popups/update_popup.dart';
import '../../store/local_stats_store.dart';
import '../../store/settings_store.dart';

class AppInfoSettingsPage extends StatefulWidget {
  const AppInfoSettingsPage({super.key});

  @override
  State<AppInfoSettingsPage> createState() => _AppInfoSettingsPageState();
}

class _AppInfoSettingsPageState extends State<AppInfoSettingsPage> {
  String? _version;
  bool _checkingUpdate = false;
  bool _checkedUpdateOnce = false;
  AppUpdateInfo? _availableUpdate;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    final settings = Provider.of<SettingsStore>(context, listen: false);
    if (settings.updateChecksEnabled) _checkForUpdate(silent: true);
  }

  Future<void> _checkForUpdate({bool silent = false}) async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = !silent);
    try {
      final info = await AppUpdateChecker().check(currentVersion: _version);
      if (!mounted) return;
      setState(() {
        _availableUpdate = info;
        _checkedUpdateOnce = true;
        _checkingUpdate = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _openUpdate() {
    final info = _availableUpdate;
    if (info == null) return;
    showUpdatePopup(context, info: info, currentVersion: _version ?? '0.0.0');
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<LocalStatsStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('App Info')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Version'),
            trailing: Text(_version ?? '…'),
          ),
          if (_availableUpdate != null)
            ListTile(
              leading: const Icon(Icons.system_update_alt, color: Colors.amber),
              title: const Text('Update Available'),
              subtitle: Text('Version ${_availableUpdate!.version}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openUpdate,
            )
          else
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text('Check for Updates'),
              subtitle: Text(_checkingUpdate
                  ? 'Checking…'
                  : _checkedUpdateOnce
                      ? 'Up to date'
                      : 'Tap to check'),
              onTap: _checkingUpdate ? null : () => _checkForUpdate(),
            ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub'),
            subtitle: const Text('github.com/clutchthrower/koti'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(Uri.parse('https://github.com/clutchthrower/koti'),
                mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('License'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Koti',
              applicationVersion: _version,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Credits'),
            subtitle: const Text(
                'willsanderson/Hemma (visual design), iamtherufus/Homio (inspiration), '
                'and Claude (Anthropic) — built with Claude Code'),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Local Stats',
                style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Never leaves this device — nothing here is sent anywhere.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ListTile(
            title: const Text('App Opens'),
            trailing: Text('${stats.launchCount}'),
          ),
          ListTile(
            title: const Text('Days Since Install'),
            trailing: Text('${stats.daysSinceInstall}'),
          ),
        ],
      ),
    );
  }
}
