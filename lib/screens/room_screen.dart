import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../hero/hero_room_card.dart';
import '../layout/entity_grid.dart';
import '../models/room_config.dart';
import '../store/settings_store.dart';

/// A single room's content: hero background + entity grid, replicating
/// `hemma_screen_layout.yaml`'s overlapping hero/entities areas. No
/// Scaffold/navbar of its own — [AppShell] owns those and swaps this in as
/// the body for whichever room is currently selected. Edits made in
/// homescreen-style edit mode save straight back to settings.
class RoomView extends StatelessWidget {
  final RoomConfig room;
  const RoomView({super.key, required this.room});

  Future<void> _save(BuildContext context, RoomConfig updated) async {
    final settings = Provider.of<SettingsStore>(context, listen: false);
    final rooms = List.of(settings.rooms);
    final i = rooms.indexWhere((r) => r.id == room.id);
    if (i == -1) return;
    rooms[i] = updated;
    await settings.setRooms(rooms);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: HeroRoomCard(
            room: room,
            onRoomChanged: (updated) => _save(context, updated),
          ),
        ),
        Positioned.fill(
          child: EntityGrid(
            cards: room.cards,
            onCardsChanged: (cards) =>
                _save(context, room.copyWith(cards: cards)),
          ),
        ),
      ],
    );
  }
}
