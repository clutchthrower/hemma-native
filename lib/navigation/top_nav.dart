import 'package:flutter/material.dart';

import '../models/room_config.dart';

/// The original dashboard's navigation: a row of text tabs across the top
/// — Home, then each room by name, then "Scenes ⌄" — inside a translucent
/// pill (tablet style). The selected tab gets a lighter pill highlight.
class KotiTopNav extends StatelessWidget {
  final List<RoomConfig> rooms;

  /// Selected room id, or null when the Home tab is active.
  final String? selectedRoomId;

  /// Called with the tapped room, or null for the Home tab.
  final ValueChanged<RoomConfig?> onSelect;
  final VoidCallback onScenes;

  const KotiTopNav({
    super.key,
    required this.rooms,
    required this.selectedRoomId,
    required this.onSelect,
    required this.onScenes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(0, 0, 0, 0.28),
        borderRadius: BorderRadius.circular(9999),
      ),
      padding: const EdgeInsets.all(5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavTab(
              label: 'Home',
              selected: selectedRoomId == null,
              onTap: () => onSelect(null),
            ),
            for (final room in rooms)
              _NavTab(
                label: room.name,
                selected: room.id == selectedRoomId,
                onTap: () => onSelect(room),
              ),
            _NavTab(
              label: 'Scenes',
              selected: false,
              trailing: const Icon(Icons.expand_more, size: 18, color: Colors.white70),
              onTap: onScenes,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NavTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color.fromRGBO(255, 255, 255, 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 16,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 2), trailing!],
          ],
        ),
      ),
    );
  }
}
