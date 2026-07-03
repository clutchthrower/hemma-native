import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../popups/battery_popup.dart';
import 'base_entity_card.dart';

class BatteryCard extends StatefulWidget {
  final List<String>? entityFilter;
  final int lowThreshold;
  final int position;

  const BatteryCard({super.key, this.entityFilter, this.lowThreshold = 20, this.position = 0});

  @override
  State<BatteryCard> createState() => _BatteryCardState();
}

class _BatteryCardState extends State<BatteryCard> {
  @override
  void initState() {
    super.initState();
    Provider.of<StateStore>(context, listen: false).addListener(_onChange);
  }

  @override
  void dispose() {
    Provider.of<StateStore>(context, listen: false).removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => mounted ? setState(() {}) : null;

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StateStore>(context, listen: false);
    final batteries = store.all.values.where((e) =>
        e.attr<String>('device_class', '') == 'battery' &&
        (widget.entityFilter == null || widget.entityFilter!.contains(e.entityId)));
    final needsAttention = batteries.any((e) {
      final level = double.tryParse(e.state) ?? 100;
      return level <= widget.lowThreshold;
    });

    return HemmaEntityCard(
      iconName: 'battery',
      label: 'Batteries',
      stateText: needsAttention ? 'Needs Attention' : 'All Good',
      active: needsAttention,
      position: widget.position,
      onTap: () => showBatteryPopup(context, widget.entityFilter, widget.lowThreshold),
    );
  }
}
