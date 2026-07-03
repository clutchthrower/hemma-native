import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/room_config.dart';
import '../../store/settings_store.dart';
import 'room_edit_page.dart';

class RoomsSettingsPage extends StatelessWidget {
  const RoomsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final room = await Navigator.of(context).push<RoomConfig>(
                MaterialPageRoute(builder: (_) => const RoomEditPage()),
              );
              if (room != null) {
                await settings.setRooms([...settings.rooms, room]);
              }
            },
          ),
        ],
      ),
      body: ReorderableListView(
        onReorder: (oldIndex, newIndex) {
          final rooms = List.of(settings.rooms);
          if (newIndex > oldIndex) newIndex--;
          final item = rooms.removeAt(oldIndex);
          rooms.insert(newIndex, item);
          settings.setRooms(rooms);
        },
        children: [
          for (final room in settings.rooms)
            ListTile(
              key: ValueKey(room.id),
              title: Text(room.name),
              subtitle: Text('${room.cards.length} cards'),
              onTap: () async {
                final updated = await Navigator.of(context).push<RoomConfig>(
                  MaterialPageRoute(builder: (_) => RoomEditPage(existing: room)),
                );
                if (updated != null) {
                  final rooms = List.of(settings.rooms);
                  final i = rooms.indexWhere((r) => r.id == room.id);
                  rooms[i] = updated;
                  await settings.setRooms(rooms);
                }
              },
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  final rooms = List.of(settings.rooms)..removeWhere((r) => r.id == room.id);
                  settings.setRooms(rooms);
                },
              ),
            ),
        ],
      ),
    );
  }
}
