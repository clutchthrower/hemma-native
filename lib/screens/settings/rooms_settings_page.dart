import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/room_config.dart';
import '../../store/settings_store.dart';
import '../../widgets/entity_picker.dart';
import '../../widgets/glass_page_route.dart';
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
              final room =
                  await pushGlassSheet<RoomConfig>(context, const RoomEditPage());
              if (room != null) {
                await settings.setRooms([...settings.rooms, room]);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: EntityPickerField(
              label: 'Weather entity',
              value: settings.weatherEntityId,
              domains: const ['weather'],
              onChanged: settings.setWeatherEntityId,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Powers the temperature/weather shown on Home. Also editable '
              'by long-pressing it there. Most Home Assistant setups only '
              'have one weather entity, already picked automatically.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView(
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
                      final updated = await pushGlassSheet<RoomConfig>(
                          context, RoomEditPage(existing: room));
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
                        final rooms = List.of(settings.rooms)
                          ..removeWhere((r) => r.id == room.id);
                        settings.setRooms(rooms);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
