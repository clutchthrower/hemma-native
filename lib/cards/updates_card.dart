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
    final count =
        store.all.values.where((e) => e.domain == 'update' && e.state == 'on').length;

    return HemmaEntityCard(
      iconName: 'updates',
      label: 'Updates',
      stateText: count > 0 ? '$count available' : 'Up to date',
      active: count > 0,
      position: widget.position,
      onTap: () => showUpdatesPopup(context),
    );
  }
}
