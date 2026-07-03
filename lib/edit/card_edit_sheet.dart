import 'package:flutter/material.dart';

import '../models/room_config.dart';
import '../widgets/entity_picker.dart';

/// Human-readable names for card types, used everywhere card types are
/// shown to the user (edit sheets, room settings).
String cardTypeLabel(HemmaCardType type) => switch (type) {
      HemmaCardType.light => 'Light',
      HemmaCardType.thermostat => 'Thermostat',
      HemmaCardType.fan => 'Fan',
      HemmaCardType.humidifier => 'Humidifier',
      HemmaCardType.airPurifier => 'Air Purifier',
      HemmaCardType.media => 'Media Player',
      HemmaCardType.lock => 'Lock',
      HemmaCardType.motion => 'Motion Sensor',
      HemmaCardType.doorbell => 'Doorbell',
      HemmaCardType.vacuum => 'Vacuum',
      HemmaCardType.curtain => 'Curtain / Cover',
      HemmaCardType.energy => 'Energy Usage',
      HemmaCardType.network => 'Network',
      HemmaCardType.battery => 'Battery Levels',
      HemmaCardType.updates => 'Updates',
      HemmaCardType.plant => 'Plant',
      HemmaCardType.custom => 'Custom',
    };

/// Which entity domains fit each card type (null = no entity needed).
List<String>? cardTypeDomains(HemmaCardType type) => switch (type) {
      HemmaCardType.light => const ['light'],
      HemmaCardType.thermostat => const ['climate'],
      HemmaCardType.fan => const ['fan'],
      HemmaCardType.humidifier => const ['humidifier'],
      HemmaCardType.airPurifier => const ['fan', 'humidifier'],
      HemmaCardType.media => const ['media_player'],
      HemmaCardType.lock => const ['lock'],
      HemmaCardType.motion => const ['binary_sensor'],
      HemmaCardType.doorbell => const ['binary_sensor', 'camera'],
      HemmaCardType.vacuum => const ['vacuum'],
      HemmaCardType.curtain => const ['cover'],
      HemmaCardType.energy => const ['sensor'],
      HemmaCardType.network => const ['sensor'],
      HemmaCardType.battery => null,
      HemmaCardType.updates => null,
      HemmaCardType.plant => const ['plant'],
      HemmaCardType.custom => null,
    };

/// Result of [showCardEditSheet]: either a card to save, or a deletion.
class CardEditResult {
  final CardConfig? card;
  final bool deleted;
  const CardEditResult.saved(this.card) : deleted = false;
  const CardEditResult.delete()
      : card = null,
        deleted = true;
}

/// One card editor for the whole app: pick what the card is, which device
/// it controls, and (optionally) a friendlier display name.
Future<CardEditResult?> showCardEditSheet(
  BuildContext context, {
  CardConfig? existing,
}) {
  return showModalBottomSheet<CardEditResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CardEditSheet(existing: existing),
  );
}

class _CardEditSheet extends StatefulWidget {
  final CardConfig? existing;
  const _CardEditSheet({this.existing});

  @override
  State<_CardEditSheet> createState() => _CardEditSheetState();
}

class _CardEditSheetState extends State<_CardEditSheet> {
  late HemmaCardType _type;
  String? _entityId;
  late final TextEditingController _label;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? HemmaCardType.light;
    _entityId =
        (widget.existing?.entityId.isEmpty ?? true) ? null : widget.existing!.entityId;
    _label = TextEditingController(text: widget.existing?.labelOverride ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  bool get _canSave => _entityId != null || cardTypeDomains(_type) == null;

  void _save() {
    Navigator.of(context).pop(CardEditResult.saved(CardConfig(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      entityId: _entityId ?? '',
      extraEntityIds: widget.existing?.extraEntityIds ?? const [],
      labelOverride: _label.text.trim().isEmpty ? null : _label.text.trim(),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

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
          Text(isNew ? 'Add Card' : 'Edit Card',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<HemmaCardType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Card type',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final t in HemmaCardType.values)
                if (t != HemmaCardType.custom)
                  DropdownMenuItem(value: t, child: Text(cardTypeLabel(t))),
            ],
            onChanged: (v) => setState(() {
              _type = v!;
              _entityId = null; // domain changed, old entity no longer fits
            }),
          ),
          const SizedBox(height: 12),
          if (cardTypeDomains(_type) != null)
            EntityPickerField(
              label: 'Device',
              value: _entityId,
              domains: cardTypeDomains(_type),
              onChanged: (v) => setState(() => _entityId = v),
            )
          else
            Text(
              'This card finds its devices automatically.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Display name (optional)',
              hintText: 'Leave empty to use the device\'s own name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (!isNew)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Remove', style: TextStyle(color: Colors.red)),
                  onPressed: () =>
                      Navigator.of(context).pop(const CardEditResult.delete()),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: Text(isNew ? 'Add' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
