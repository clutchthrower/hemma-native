import 'package:flutter/material.dart';

import '../theme/hemma_theme.dart';
import '../widgets/entity_watcher.dart';
import 'popup_base.dart';

void showPlantPopup(BuildContext context, String plantEntityId) {
  showHemmaPopup(
    context,
    title: 'Plant',
    builder: (context) => EntityWatcher(
      entityIds: [plantEntityId],
      builder: (context, states) {
        final tokens = HemmaTheme.of(context);
        final entity = states[plantEntityId];
        final sensors = {
          'Moisture': entity?.attributes['moisture'],
          'Illuminance': entity?.attributes['illuminance'],
          'Temperature': entity?.attributes['temperature'],
          'Conductivity': entity?.attributes['conductivity'],
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sensors.entries
              .where((e) => e.value != null)
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${e.key}: ${e.value}',
                        style: TextStyle(color: tokens.textPrimary)),
                  ))
              .toList(),
        );
      },
    ),
  );
}
