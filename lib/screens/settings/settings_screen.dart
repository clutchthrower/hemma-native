import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/glass_page_route.dart';
import 'app_info_settings_page.dart';
import 'diagnostics_settings_page.dart';
import 'display_settings_page.dart';
import 'home_assistant_settings_page.dart';
import 'music_assistant_settings_page.dart';

/// Full settings hub. The sidebar links to the common pages directly, but
/// everything must also be reachable from here — this is the only settings
/// entry point on screens without the drawer (e.g. the no-rooms prompt).
/// Same 6 top-level entries as [SettingsView]'s grid, just as a flat list —
/// no need to unify the visual idiom, only the content, since this screen
/// and the grid used to drift into genuinely different sets of tiles.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.home_work_outlined),
            title: const Text('Home Assistant'),
            subtitle: const Text('Device name, Bluetooth proxy, rooms, connection'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushGlassSheet(context, const HomeAssistantSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.library_music_outlined),
            title: const Text('Music Assistant'),
            subtitle: const Text('Swipeable Music page, and use this tablet as a speaker'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushGlassSheet(context, const MusicAssistantSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Display'),
            subtitle: const Text('Appearance, screensaver, power'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushGlassSheet(context, const DisplaySettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.developer_mode_outlined),
            title: const Text('Diagnostics'),
            subtitle: const Text('Network tuning, debug tools, reset'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushGlassSheet(context, const DiagnosticsSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Info'),
            subtitle: const Text('Version, updates, credits'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushGlassSheet(context, const AppInfoSettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Exit'),
            subtitle: const Text('Quit Koti'),
            onTap: () => SystemNavigator.pop(),
          ),
        ],
      ),
    );
  }
}
