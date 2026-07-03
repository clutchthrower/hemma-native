import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../edit/card_edit_sheet.dart';
import '../../models/room_config.dart';
import '../../store/state_store.dart';
import '../../widgets/entity_picker.dart';

/// Full room editor, organized into plain-language sections: Room, Badges,
/// Cards, and Advanced. The quick way to tweak a room is the in-place edit
/// mode (long-press a card or badge); this page is the complete version.
class RoomEditPage extends StatefulWidget {
  final RoomConfig? existing;
  const RoomEditPage({super.key, this.existing});

  @override
  State<RoomEditPage> createState() => _RoomEditPageState();
}

class _RoomEditPageState extends State<RoomEditPage> {
  late TextEditingController _name;
  late TextEditingController _id;
  String? _climate;
  String? _tempSensor;
  String? _humiditySensor;
  String? _aqiSensor;
  String? _lightGroup;
  List<String> _lights = [];
  List<String> _mediaPlayers = [];
  String? _motion;
  List<String> _locks = [];
  List<String> _covers = [];
  List<String> _presence = [];
  List<CardConfig> _cards = [];

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _name = TextEditingController(text: r?.name ?? '');
    _id = TextEditingController(text: r?.id ?? '');
    _climate = r?.climateEntity;
    _tempSensor = r?.temperatureSensor;
    _humiditySensor = r?.humiditySensor;
    _aqiSensor = r?.aqiSensor;
    _lightGroup = r?.lightGroupEntity;
    _lights = List.of(r?.lightEntities ?? const []);
    _mediaPlayers = List.of(r?.mediaPlayers ?? const []);
    _motion = r?.motionSensor;
    _locks = List.of(r?.lockEntities ?? const []);
    _covers = List.of(r?.coverEntities ?? const []);
    _presence = List.of(r?.presenceEntities ?? const []);
    _cards = List.of(r?.cards ?? const []);
  }

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    super.dispose();
  }

  Future<void> _addCard() async {
    final result = await showCardEditSheet(context);
    if (result?.card != null) setState(() => _cards.add(result!.card!));
  }

  Future<void> _editCard(CardConfig card) async {
    final result = await showCardEditSheet(context, existing: card);
    if (result == null) return;
    setState(() {
      final i = _cards.indexWhere((c) => c.id == card.id);
      if (i == -1) return;
      if (result.deleted) {
        _cards.removeAt(i);
      } else {
        _cards[i] = result.card!;
      }
    });
  }

  void _save() {
    final config = RoomConfig(
      id: _id.text.trim().isEmpty
          ? _name.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-')
          : _id.text.trim(),
      name: _name.text.trim(),
      climateEntity: _climate,
      temperatureSensor: _tempSensor,
      humiditySensor: _humiditySensor,
      aqiSensor: _aqiSensor,
      lightGroupEntity: _lightGroup,
      lightEntities: _lights,
      mediaPlayers: _mediaPlayers,
      motionSensor: _motion,
      lockEntities: _locks,
      coverEntities: _covers,
      presenceEntities: _presence,
      cards: _cards,
      backgroundAsset: widget.existing?.backgroundAsset,
    );
    Navigator.of(context).pop(config);
  }

  Widget _section(String title, String subtitle, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    color: Theme.of(context).hintColor, fontSize: 12)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  String _cardSubtitle(CardConfig card) {
    if (card.entityId.isEmpty) return 'Automatic';
    final store = Provider.of<StateStore>(context, listen: false);
    return store.get(card.entityId)?.attr<String>('friendly_name', card.entityId) ??
        card.entityId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Room' : 'Edit ${widget.existing!.name}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Room', 'What this room is called.', [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
            ),
          ]),
          _section(
            'Badges',
            'The small pills under the room name. A badge shows up once it has at least one device.',
            [
              _BadgeGroup(
                icon: Icons.thermostat,
                title: 'Climate',
                children: [
                  EntityPickerField(
                    label: 'Temperature sensor',
                    value: _tempSensor,
                    domains: const ['sensor'],
                    deviceClasses: const ['temperature'],
                    onChanged: (v) => setState(() => _tempSensor = v),
                  ),
                  const SizedBox(height: 12),
                  EntityPickerField(
                    label: 'Humidity sensor',
                    value: _humiditySensor,
                    domains: const ['sensor'],
                    deviceClasses: const ['humidity'],
                    onChanged: (v) => setState(() => _humiditySensor = v),
                  ),
                  const SizedBox(height: 12),
                  EntityPickerField(
                    label: 'Thermostat',
                    value: _climate,
                    domains: const ['climate'],
                    onChanged: (v) => setState(() => _climate = v),
                  ),
                ],
              ),
              _BadgeGroup(
                icon: Icons.lightbulb_outline,
                title: 'Lights',
                children: [
                  MultiEntityPickerField(
                    label: 'Lights in this room',
                    values: _lights,
                    domains: const ['light'],
                    maxCount: 8,
                    onChanged: (v) => setState(() => _lights = v),
                  ),
                ],
              ),
              _BadgeGroup(
                icon: Icons.person_outline,
                title: 'People',
                children: [
                  MultiEntityPickerField(
                    label: 'People shown here',
                    values: _presence,
                    domains: const ['person', 'device_tracker'],
                    maxCount: 4,
                    onChanged: (v) => setState(() => _presence = v),
                  ),
                ],
              ),
              _BadgeGroup(
                icon: Icons.speaker_outlined,
                title: 'Media',
                children: [
                  MultiEntityPickerField(
                    label: 'Media players in this room',
                    values: _mediaPlayers,
                    domains: const ['media_player'],
                    maxCount: 14,
                    onChanged: (v) => setState(() => _mediaPlayers = v),
                  ),
                ],
              ),
            ],
          ),
          _section(
            'Cards',
            'The tiles along the bottom of the room. Drag to reorder, tap to edit.',
            [
              if (_cards.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('No cards yet.',
                      style: TextStyle(color: Theme.of(context).hintColor)),
                ),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _cards.removeAt(oldIndex);
                    _cards.insert(newIndex, item);
                  });
                },
                children: [
                  for (var i = 0; i < _cards.length; i++)
                    ListTile(
                      key: ValueKey(_cards[i].id),
                      contentPadding: EdgeInsets.zero,
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_indicator),
                      ),
                      title: Text(
                          _cards[i].labelOverride ?? cardTypeLabel(_cards[i].type)),
                      subtitle: Text(_cardSubtitle(_cards[i])),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editCard(_cards[i]),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Card'),
                onPressed: _addCard,
              ),
            ],
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              title: const Text('Advanced'),
              subtitle:
                  const Text('Rarely-needed extras', style: TextStyle(fontSize: 12)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                TextField(
                  controller: _id,
                  decoration: const InputDecoration(
                    labelText: 'Room ID',
                    helperText:
                        'Used internally and to pick the background photo. Usually leave alone.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                EntityPickerField(
                  label: 'Light group entity',
                  value: _lightGroup,
                  domains: const ['light'],
                  onChanged: (v) => setState(() => _lightGroup = v),
                ),
                const SizedBox(height: 12),
                EntityPickerField(
                  label: 'Air quality sensor',
                  value: _aqiSensor,
                  domains: const ['sensor'],
                  onChanged: (v) => setState(() => _aqiSensor = v),
                ),
                const SizedBox(height: 12),
                EntityPickerField(
                  label: 'Motion sensor',
                  value: _motion,
                  domains: const ['binary_sensor'],
                  deviceClasses: const ['motion'],
                  onChanged: (v) => setState(() => _motion = v),
                ),
                const SizedBox(height: 12),
                MultiEntityPickerField(
                  label: 'Locks',
                  values: _locks,
                  domains: const ['lock'],
                  onChanged: (v) => setState(() => _locks = v),
                ),
                const SizedBox(height: 12),
                MultiEntityPickerField(
                  label: 'Curtains / covers',
                  values: _covers,
                  domains: const ['cover'],
                  onChanged: (v) => setState(() => _covers = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One collapsible badge group inside the Badges section — collapsed rows
/// keep the page short; the summary line shows what's configured.
class _BadgeGroup extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _BadgeGroup({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(icon),
      title: Text(title),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      children: children,
    );
  }
}
