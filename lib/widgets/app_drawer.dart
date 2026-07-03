import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/room_config.dart';
import '../screens/home_overview_screen.dart';
import '../store/settings_store.dart';
import '../store/state_store.dart';
import '../theme/hemma_theme.dart';
import '../screens/settings/connection_settings_page.dart';
import '../screens/settings/display_settings_page.dart';
import '../screens/settings/room_edit_page.dart';
import '../screens/settings/rooms_settings_page.dart';
import '../screens/settings/settings_screen.dart';

/// Sidebar menu (Flutter's own `Drawer` — swipes/taps out of the way on
/// its own, satisfying "auto-hiding"). Holds the things that aren't part
/// of daily use: editing the current room, app-wide settings, and exit.
class AppDrawer extends StatelessWidget {
  final RoomConfig? currentRoom;
  const AppDrawer({super.key, this.currentRoom});

  @override
  Widget build(BuildContext context) {
    final tokens = HemmaTheme.of(context);
    final settings = Provider.of<SettingsStore>(context, listen: false);

    return Drawer(
      backgroundColor: tokens.cardBackground,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Text(
                'Hemma',
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            if (currentRoom != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Room'),
                subtitle: Text(currentRoom!.name),
                onTap: () async {
                  Navigator.of(context).pop();
                  final updated = await Navigator.of(context).push<RoomConfig>(
                    MaterialPageRoute(builder: (_) => RoomEditPage(existing: currentRoom)),
                  );
                  if (updated != null) {
                    final rooms = List.of(settings.rooms);
                    final i = rooms.indexWhere((r) => r.id == currentRoom!.id);
                    if (i != -1) {
                      rooms[i] = updated;
                      await settings.setRooms(rooms);
                    }
                  }
                },
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Home'),
                subtitle: const Text('Badges and overview cards'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final store = Provider.of<StateStore>(context, listen: false);
                  // Seed the editor with whatever Home currently shows —
                  // the saved layout, or today's auto-derived one.
                  final current = effectiveHomeConfig(
                    rooms: settings.rooms,
                    store: store,
                    saved: settings.homeRoom,
                  );
                  final updated = await Navigator.of(context).push<RoomConfig>(
                    MaterialPageRoute(builder: (_) => RoomEditPage(existing: current)),
                  );
                  if (updated != null) await settings.setHomeRoom(updated);
                },
              ),
              if (settings.homeRoom != null)
                ListTile(
                  leading: const Icon(Icons.restart_alt),
                  title: const Text('Reset Home to Automatic'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await settings.setHomeRoom(null);
                  },
                ),
            ],
            ExpansionTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  leading: const Icon(Icons.wifi),
                  title: const Text('Connection'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ConnectionSettingsPage()));
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Display'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DisplaySettingsPage()));
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: const Text('Manage Rooms'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const RoomsSettingsPage()));
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  leading: const Icon(Icons.more_horiz),
                  title: const Text('More'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Exit'),
              onTap: () => SystemNavigator.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
