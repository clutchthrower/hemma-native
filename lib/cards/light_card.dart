import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../widgets/entity_watcher.dart';
import 'base_entity_card.dart';
import 'light_color_popup.dart';
import 'light_group_popup.dart';

/// Light tile with recursive group expansion for the on-count. Toggling is
/// a plain `light.turn_on`/`turn_off` — the original's scene-snapshot
/// "smart toggle" could capture a light mid-fade-off and then "restore" it
/// to off, leaving the light impossible to turn back on from the card.
/// Bulbs restore their own last brightness in HA anyway.
class LightCard extends StatelessWidget {
  final String entityId;
  final String? label;
  final int position;

  const LightCard({super.key, required this.entityId, this.label, this.position = 0});

  List<String> _expandGroupMembers(StateStore store, String rootId) {
    final visited = <String>{};
    final result = <String>[];
    void expand(String id) {
      if (visited.contains(id)) return;
      visited.add(id);
      final entity = store.get(id);
      final members = entity?.attributes['entity_id'];
      if (members is List && members.isNotEmpty) {
        for (final m in members) {
          expand(m as String);
        }
      } else if (id.startsWith('light.')) {
        result.add(id);
      }
    }

    expand(rootId);
    return result.isEmpty ? [rootId] : result;
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StateStore>(context, listen: false);
    final members = _expandGroupMembers(store, entityId);

    return EntityWatcher(
      entityIds: [entityId, ...members],
      builder: (context, states) {
        final root = states[entityId];
        final onCount = members.where((m) => states[m]?.state == 'on').length;
        final active = onCount > 0 || root?.state == 'on';
        // HA reports bulbs cut off at the wall switch as 'unavailable' —
        // show that honestly instead of a tappable "Off" that ignores taps.
        final reachableMembers = members
            .where((m) =>
                states[m] != null &&
                states[m]!.state != 'unavailable' &&
                states[m]!.state != 'unknown')
            .toList();
        final unavailable = !active && reachableMembers.isEmpty;
        final stateText =
            unavailable ? 'Unavailable' : (active ? '$onCount On' : 'Off');

        // RGB/RGBW/RGBWW bulbs report one of these color-family modes;
        // tunable-white bulbs report 'color_temp'. A single light with
        // either gets the color/kelvin popup instead of a plain toggle —
        // groups keep their existing per-member toggle list, since HA
        // doesn't guarantee a group's members share one current color.
        final colorModes =
            (root?.attributes['supported_color_modes'] as List?)?.cast<String>() ?? const [];
        final supportsColorControl = colorModes
            .any((m) => ['rgb', 'rgbw', 'rgbww', 'hs', 'xy', 'color_temp'].contains(m));

        void toggle() {
          store.callService('light', active ? 'turn_off' : 'turn_on',
              entityId: entityId, data: const {'transition': 1});
        }

        return KotiEntityCard(
          iconName: 'light',
          label: label ?? root?.attr<String>('friendly_name', entityId) ?? entityId,
          stateText: stateText,
          active: active,
          position: position,
          // Group: tap opens the per-member toggle list. Single color/CCT
          // light: tap opens the color/kelvin popup. Plain on-off light:
          // tap toggles. The trailing switch always toggles in place
          // regardless. Long-press is reserved for entering edit mode.
          onTap: unavailable
              ? null
              : (members.length > 1
                  ? () => showLightGroupPopup(context, entityId, members)
                  : (supportsColorControl
                      ? () => showLightColorPopup(context, entityId)
                      : toggle)),
          // Top-right switch like the original's toggleable cards.
          trailing: Transform.scale(
            scale: 0.8,
            alignment: Alignment.topRight,
            child: Switch(
              value: active,
              onChanged: unavailable ? null : (_) => toggle(),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color.fromRGBO(255, 255, 255, 0.45),
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: const Color.fromRGBO(255, 255, 255, 0.18),
            ),
          ),
        );
      },
    );
  }
}
