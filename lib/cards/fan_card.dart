import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../popups/popup_base.dart';
import '../store/state_store.dart';
import '../theme/koti_theme.dart';
import '../widgets/entity_watcher.dart';
import '../widgets/koti_switch.dart';
import 'base_entity_card.dart';

class FanCard extends StatelessWidget {
  final String entityId;
  final int position;
  /// Optional display-name override from the card config.
  final String? label;

  const FanCard(
      {super.key, required this.entityId, this.label, this.position = 0});

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StateStore>(context, listen: false);
    return EntityWatcher(
      entityIds: [entityId],
      builder: (context, states) {
        final entity = states[entityId];
        final active = entity?.state == 'on';
        final pct = entity?.attrDouble('percentage');
        final name =
            label ?? entity?.attr<String>('friendly_name', entityId) ?? entityId;
        return KotiEntityCard(
          iconName: 'fan',
          label: name,
          stateText: active
              ? (pct != null ? '${pct.toStringAsFixed(0)}%' : 'On')
              : 'Off',
          active: active,
          position: position,
          onTap: () => showKotiPopup(
            context,
            title: name,
            builder: (context) => _FanControls(entityId: entityId),
          ),
          trailing: KotiSwitch(
            value: active,
            onChanged: (_) =>
                store.callService('fan', 'toggle', entityId: entityId),
            size: 28,
            activeColor: Colors.white,
            inactiveColor: Colors.white70,
          ),
        );
      },
    );
  }
}

class _FanControls extends StatefulWidget {
  final String entityId;
  const _FanControls({required this.entityId});

  @override
  State<_FanControls> createState() => _FanControlsState();
}

class _FanControlsState extends State<_FanControls> {
  double? _dragPct;

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    final store = Provider.of<StateStore>(context, listen: false);

    return EntityWatcher(
      entityIds: [widget.entityId],
      builder: (context, states) {
        final entity = states[widget.entityId];
        final active = entity?.state == 'on';
        final pct = entity?.attrDouble('percentage');

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KotiSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(active ? 'On' : 'Off',
                  style: TextStyle(color: tokens.textPrimary)),
              value: active,
              onChanged: (_) =>
                  store.callService('fan', 'toggle', entityId: widget.entityId),
            ),
            if (pct != null) ...[
              Text('Speed', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
              Slider(
                value: (_dragPct ?? pct).clamp(0.0, 100.0),
                max: 100,
                divisions: 10,
                label: '${(_dragPct ?? pct).toStringAsFixed(0)}%',
                onChanged: (v) => setState(() => _dragPct = v),
                onChangeEnd: (v) {
                  store.callService('fan', 'set_percentage',
                      entityId: widget.entityId, data: {'percentage': v.round()});
                  setState(() => _dragPct = null);
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
