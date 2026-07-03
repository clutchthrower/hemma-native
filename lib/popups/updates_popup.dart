import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../theme/hemma_theme.dart';
import 'popup_base.dart';

void showUpdatesPopup(BuildContext context) {
  final store = Provider.of<StateStore>(context, listen: false);
  showHemmaPopup(
    context,
    title: 'Updates',
    builder: (context) {
      final tokens = HemmaTheme.of(context);
      final updates =
          store.all.values.where((e) => e.domain == 'update' && e.state == 'on').toList();
      if (updates.isEmpty) {
        return Text('Everything is up to date', style: TextStyle(color: tokens.textSecondary));
      }
      return Column(
        children: updates.map((e) {
          final current = e.attr<String>('installed_version', '?');
          final available = e.attr<String>('latest_version', '?');
          return ListTile(
            title: Text(e.attr<String>('friendly_name', e.entityId),
                style: TextStyle(color: tokens.textPrimary)),
            subtitle: Text('$current → $available', style: TextStyle(color: tokens.textSecondary)),
          );
        }).toList(),
      );
    },
  );
}
