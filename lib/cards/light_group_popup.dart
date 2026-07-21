import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../theme/koti_theme.dart';
import '../widgets/entity_watcher.dart';
import '../widgets/koti_icon.dart';
import '../widgets/koti_switch.dart';
import '../popups/popup_base.dart';
import 'light_color_popup.dart';

/// Light-group popup: brightness/color/temperature controls for the group
/// as a whole (when it reports supporting any of them — HA's `light` group
/// platform fans a `turn_on` call on the group's own entity_id out to every
/// member) on top, then one row per member below, per `hemma_light.yaml`'s
/// hold-action popup.
void showLightGroupPopup(BuildContext context, String groupId, List<String> members) {
  showKotiPopup(
    context,
    title: 'Lights',
    builder: (context) => EntityWatcher(
      entityIds: [groupId, ...members],
      builder: (context, states) {
        final tokens = KotiTheme.of(context);
        final store = Provider.of<StateStore>(context, listen: false);
        final groupModes =
            (states[groupId]?.attributes['supported_color_modes'] as List?)?.cast<String>() ??
                const [];
        final groupHasControls = groupModes.any((m) => m != 'onoff');

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (groupHasControls) ...[
              LightModeControls(entityId: groupId),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1),
              ),
            ],
            ...members.map((id) {
              final entity = states[id];
              final isOn = entity?.state == 'on';
              final name = entity?.attr<String>('friendly_name', id) ?? id;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: KotiIconCircle(
                  iconName: 'light',
                  iconColor: isOn ? tokens.activeColor : tokens.textSecondary,
                  backgroundColor: isOn
                      ? tokens.activeColor.withValues(alpha: 0.16)
                      : tokens.iconCircleBackground,
                  diameter: 38,
                ),
                title: Text(name, style: TextStyle(color: tokens.textPrimary)),
                trailing: KotiSwitch(
                  value: isOn,
                  onChanged: (v) => store.callService(
                    'light',
                    v ? 'turn_on' : 'turn_off',
                    entityId: id,
                    data: const {'transition': 2},
                  ),
                  activeColor: tokens.activeColor,
                  inactiveColor: tokens.textSecondary,
                ),
              );
            }),
          ],
        );
      },
    ),
  );
}
