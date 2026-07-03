import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../theme/hemma_theme.dart';
import '../widgets/entity_watcher.dart';
import '../widgets/hemma_icon.dart';
import '../popups/popup_base.dart';

/// Two-column light-group popup: the group itself plus one row per member,
/// per `hemma_light.yaml`'s hold-action popup.
void showLightGroupPopup(BuildContext context, String groupId, List<String> members) {
  showHemmaPopup(
    context,
    title: 'Lights',
    builder: (context) => EntityWatcher(
      entityIds: members,
      builder: (context, states) {
        final tokens = HemmaTheme.of(context);
        final store = Provider.of<StateStore>(context, listen: false);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: members.map((id) {
            final entity = states[id];
            final isOn = entity?.state == 'on';
            final name = entity?.attr<String>('friendly_name', id) ?? id;
            return ListTile(
              leading: HemmaIconCircle(
                iconName: 'light',
                iconColor: isOn ? tokens.activeColor : tokens.textSecondary,
                backgroundColor:
                    isOn ? tokens.activeColor.withValues(alpha: 0.16) : tokens.iconCircleBackground,
                diameter: 38,
              ),
              title: Text(name, style: TextStyle(color: tokens.textPrimary)),
              trailing: Switch(
                value: isOn,
                onChanged: (v) => store.callService(
                  'light',
                  v ? 'turn_on' : 'turn_off',
                  entityId: id,
                  data: const {'transition': 2},
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}
