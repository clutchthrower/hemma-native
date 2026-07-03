import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/helper_store.dart';
import '../utils/color_utils.dart';
import '../widgets/entity_watcher.dart';
import 'group_badge.dart';

class ClimateGroupBadge extends StatelessWidget {
  final String? tempSensorEntityId;
  final String? humiditySensorEntityId;

  const ClimateGroupBadge({super.key, this.tempSensorEntityId, this.humiditySensorEntityId});

  @override
  Widget build(BuildContext context) {
    final helpers = Provider.of<HelperStore>(context, listen: false);
    final ids = [
      if (tempSensorEntityId != null) tempSensorEntityId!,
      if (humiditySensorEntityId != null) humiditySensorEntityId!,
    ];
    return EntityWatcher(
      entityIds: ids,
      builder: (context, states) {
        final temp = tempSensorEntityId != null
            ? double.tryParse(states[tempSensorEntityId]?.state ?? '')
            : null;
        // Bold "Climate" + temperature sub-line, icon tinted by temp tier —
        // matches the original's "Climate / 74-75°" badge.
        return GroupBadge(
          iconName: 'thermostat',
          label: 'Climate',
          subLabel: temp != null ? '${temp.toStringAsFixed(0)}°' : null,
          accent: temp != null ? colorForTempF(temp) : null,
          onTap: () => helpers.toggleExpandedRow(ExpandedRow.climate),
        );
      },
    );
  }
}
