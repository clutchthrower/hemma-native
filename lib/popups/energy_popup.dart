import 'package:flutter/material.dart';

import '../theme/koti_theme.dart';
import '../widgets/entity_watcher.dart';
import 'popup_base.dart';

Color _wattageColor(double watts) {
  if (watts < 200) return const Color(0xFF63C58B);
  if (watts < 1000) return const Color(0xFFE8C34F);
  if (watts < 3000) return const Color(0xFFE8934F);
  return const Color(0xFFE85D4F);
}

void showEnergyPopup(BuildContext context, String powerEntityId) {
  showKotiPopup(
    context,
    title: 'Energy',
    builder: (context) => EntityWatcher(
      entityIds: [powerEntityId],
      builder: (context, states) {
        final tokens = KotiTheme.of(context);
        final watts = double.tryParse(states[powerEntityId]?.state ?? '') ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${watts.toStringAsFixed(0)} W',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: _wattageColor(watts),
              ),
            ),
            const SizedBox(height: 8),
            Text('Real-time power draw', style: TextStyle(color: tokens.textSecondary)),
          ],
        );
      },
    ),
  );
}
