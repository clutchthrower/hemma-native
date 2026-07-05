import 'package:flutter/material.dart';

import '../widgets/entity_watcher.dart';
import '../popups/network_popup.dart';
import 'base_entity_card.dart';

class NetworkCard extends StatelessWidget {
  final String downloadSensorEntityId;
  final String? uploadSensorEntityId;
  final String? pingSensorEntityId;
  final double idleThreshold;
  final double lightThreshold;
  final double heavyThreshold;
  final String? device1Name;
  final String? device1RestartEntityId;
  final String? device2Name;
  final String? device2RestartEntityId;
  final int position;

  const NetworkCard({
    super.key,
    required this.downloadSensorEntityId,
    this.uploadSensorEntityId,
    this.pingSensorEntityId,
    this.idleThreshold = 1,
    this.lightThreshold = 10,
    this.heavyThreshold = 50,
    this.device1Name,
    this.device1RestartEntityId,
    this.device2Name,
    this.device2RestartEntityId,
    this.position = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ids = [downloadSensorEntityId, if (uploadSensorEntityId != null) uploadSensorEntityId!];
    return EntityWatcher(
      entityIds: ids,
      builder: (context, states) {
        final down = double.tryParse(states[downloadSensorEntityId]?.state ?? '') ?? 0;
        final up = uploadSensorEntityId != null
            ? double.tryParse(states[uploadSensorEntityId]?.state ?? '') ?? 0
            : 0;
        final maxSpeed = down > up ? down : up;
        final label = down >= up ? 'Download' : 'Upload';

        return KotiEntityCard(
          iconName: 'wifi',
          label: 'Network',
          stateText: '$label ${maxSpeed.toStringAsFixed(1)} Mbps',
          active: maxSpeed >= lightThreshold,
          position: position,
          onTap: () => showNetworkPopup(
            context,
            downloadSensorEntityId: downloadSensorEntityId,
            uploadSensorEntityId: uploadSensorEntityId,
            pingSensorEntityId: pingSensorEntityId,
            device1Name: device1Name,
            device1RestartEntityId: device1RestartEntityId,
            device2Name: device2Name,
            device2RestartEntityId: device2RestartEntityId,
          ),
        );
      },
    );
  }
}
