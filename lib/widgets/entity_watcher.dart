import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entity_state.dart';
import '../store/state_store.dart';

/// Bridges [StateStore]'s per-entity pub/sub to a single widget subtree so
/// only the card whose entity actually changed repaints ("atomic repaints"
/// per CLAUDE.md) instead of the whole entity grid.
class EntityWatcher extends StatefulWidget {
  final List<String> entityIds;
  final Widget Function(BuildContext context, Map<String, EntityState?> states)
      builder;

  const EntityWatcher({super.key, required this.entityIds, required this.builder});

  @override
  State<EntityWatcher> createState() => _EntityWatcherState();
}

class _EntityWatcherState extends State<EntityWatcher> {
  late StateStore _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = Provider.of<StateStore>(context, listen: false);
    for (final id in widget.entityIds) {
      _store.subscribe(id, _onChange);
    }
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final id in widget.entityIds) {
      _store.unsubscribe(id, _onChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final states = <String, EntityState?>{
      for (final id in widget.entityIds) id: _store.get(id),
    };
    return widget.builder(context, states);
  }
}
