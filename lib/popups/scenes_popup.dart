import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../theme/hemma_theme.dart';
import 'popup_base.dart';

/// Replicates the desktop navbar's Scenes dropdown / mobile Scenes sheet:
/// lists `scene.*` entities, hiding any whose entity_id carries the
/// `hemma_`-style internal prefix used for snapshot/restore scenes.
void showScenesPopup(BuildContext context, {String filterPrefix = 'hemma_'}) {
  final store = Provider.of<StateStore>(context, listen: false);
  showHemmaPopup(
    context,
    title: 'Scenes',
    builder: (context) {
      final tokens = HemmaTheme.of(context);
      final scenes = store.all.values.where((e) =>
          e.domain == 'scene' && !e.entityId.split('.').last.startsWith(filterPrefix));
      if (scenes.isEmpty) {
        return Text('No scenes available', style: TextStyle(color: tokens.textSecondary));
      }
      return Column(
        children: scenes.map((s) {
          return ListTile(
            title: Text(s.attr<String>('friendly_name', s.entityId),
                style: TextStyle(color: tokens.textPrimary)),
            onTap: () {
              store.callService('scene', 'turn_on', entityId: s.entityId);
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      );
    },
  );
}
