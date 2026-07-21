import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../popups/updates_popup.dart';
import 'base_entity_card.dart';

class UpdatesCard extends StatefulWidget {
  final int position;
  const UpdatesCard({super.key, this.position = 0});

  @override
  State<UpdatesCard> createState() => _UpdatesCardState();
}

class _UpdatesCardState extends State<UpdatesCard> {
  late final StateStore _store;

  @override
  void initState() {
    super.initState();
    _store = Provider.of<StateStore>(context, listen: false);
    _store.addListener(_onChange);
  }

  @override
  void dispose() {
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => mounted ? setState(() {}) : null;

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final count =
        store.all.values.where((e) => e.domain == 'update' && e.state == 'on').length;

    return KotiEntityCard(
      iconName: 'updates',
      label: 'Updates',
      stateText: count > 0 ? '$count available' : 'Up to date',
      active: count > 0,
      position: widget.position,
      onTap: () => showUpdatesPopup(context),
    );
  }
}
