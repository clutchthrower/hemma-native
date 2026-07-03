import 'package:flutter/material.dart';

import '../models/room_config.dart';
import '../widgets/entity_picker.dart';

/// The four hero badges and which room fields each one reads.
enum BadgeKind { climate, lights, people, media }

String badgeKindLabel(BadgeKind kind) => switch (kind) {
      BadgeKind.climate => 'Climate',
      BadgeKind.lights => 'Lights',
      BadgeKind.people => 'People',
      BadgeKind.media => 'Media',
    };

/// Whether the room currently shows this badge.
bool roomHasBadge(RoomConfig room, BadgeKind kind) => switch (kind) {
      BadgeKind.climate =>
        room.temperatureSensor != null || room.climateEntity != null,
      BadgeKind.lights =>
        room.lightEntities.isNotEmpty || room.lightGroupEntity != null,
      BadgeKind.people => room.presenceEntities.isNotEmpty,
      BadgeKind.media => room.mediaPlayers.isNotEmpty,
    };

/// Edits the devices behind one badge. Returns the updated room, or null
/// if cancelled. "Remove badge" clears the badge's fields.
Future<RoomConfig?> showBadgeEditSheet(
  BuildContext context, {
  required BadgeKind kind,
  required RoomConfig room,
}) {
  return showModalBottomSheet<RoomConfig>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _BadgeEditSheet(kind: kind, room: room),
  );
}

class _BadgeEditSheet extends StatefulWidget {
  final BadgeKind kind;
  final RoomConfig room;
  const _BadgeEditSheet({required this.kind, required this.room});

  @override
  State<_BadgeEditSheet> createState() => _BadgeEditSheetState();
}

class _BadgeEditSheetState extends State<_BadgeEditSheet> {
  late RoomConfig _room = widget.room;

  RoomConfig get _cleared => switch (widget.kind) {
        BadgeKind.climate => _room.copyWith(
            climateEntity: null, temperatureSensor: null, humiditySensor: null),
        BadgeKind.lights =>
          _room.copyWith(lightEntities: const [], lightGroupEntity: null),
        BadgeKind.people => _room.copyWith(presenceEntities: const []),
        BadgeKind.media => _room.copyWith(mediaPlayers: const []),
      };

  List<Widget> _fields() {
    switch (widget.kind) {
      case BadgeKind.climate:
        return [
          EntityPickerField(
            label: 'Temperature sensor',
            value: _room.temperatureSensor,
            domains: const ['sensor'],
            deviceClasses: const ['temperature'],
            onChanged: (v) => setState(() => _room = _room.copyWith(temperatureSensor: v)),
          ),
          const SizedBox(height: 12),
          EntityPickerField(
            label: 'Humidity sensor (optional)',
            value: _room.humiditySensor,
            domains: const ['sensor'],
            deviceClasses: const ['humidity'],
            onChanged: (v) => setState(() => _room = _room.copyWith(humiditySensor: v)),
          ),
          const SizedBox(height: 12),
          EntityPickerField(
            label: 'Thermostat (optional)',
            value: _room.climateEntity,
            domains: const ['climate'],
            onChanged: (v) => setState(() => _room = _room.copyWith(climateEntity: v)),
          ),
        ];
      case BadgeKind.lights:
        return [
          MultiEntityPickerField(
            label: 'Lights counted by this badge',
            values: _room.lightEntities,
            domains: const ['light'],
            maxCount: 8,
            onChanged: (v) => setState(() => _room = _room.copyWith(lightEntities: v)),
          ),
        ];
      case BadgeKind.people:
        return [
          MultiEntityPickerField(
            label: 'People shown by this badge',
            values: _room.presenceEntities,
            domains: const ['person', 'device_tracker'],
            maxCount: 4,
            onChanged: (v) =>
                setState(() => _room = _room.copyWith(presenceEntities: v)),
          ),
        ];
      case BadgeKind.media:
        return [
          MultiEntityPickerField(
            label: 'Media players watched by this badge',
            values: _room.mediaPlayers,
            domains: const ['media_player'],
            maxCount: 14,
            onChanged: (v) => setState(() => _room = _room.copyWith(mediaPlayers: v)),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBadge = roomHasBadge(widget.room, widget.kind);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${badgeKindLabel(widget.kind)} Badge',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ..._fields(),
          const SizedBox(height: 20),
          Row(
            children: [
              if (hasBadge)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Remove badge',
                      style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(_cleared),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_room),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
