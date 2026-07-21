import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../popups/popup_base.dart';
import '../store/state_store.dart';
import '../theme/koti_theme.dart';
import '../widgets/entity_watcher.dart';
import '../widgets/koti_switch.dart';

/// Warm-to-cool reference colors for the Kelvin bar's gradient — an
/// approximation for visual orientation (this app doesn't render blackbody
/// radiation curves), not a physically exact color-temperature mapping.
const _warmColor = Color(0xFFFF9A45);
const _coolColor = Color(0xFFFFF6E8);

enum _LightMode { brightness, color, temperature }

/// Color/brightness/color-temperature detail popup for a single light —
/// `light.turn_on`'s `hs_color`/`color_temp_kelvin`/`brightness_pct` fields
/// work the same whether the entity is a single bulb or an HA `light` group
/// (HA fans a group's own service call out to its members), so [LightModeControls]
/// (embedded here, and also inside `light_group_popup.dart`'s member list)
/// doesn't need to know or care which it's looking at.
void showLightColorPopup(BuildContext context, String entityId) {
  showKotiPopup(
    context,
    title: 'Light',
    builder: (context) => LightModeControls(entityId: entityId),
  );
}

/// One property edited at a time (Brightness / Color / Temperature),
/// switched via a row of icon buttons above a single active bar — rather
/// than showing three sliders/a color wheel simultaneously, matching a
/// reference the user liked. Self-contained (watches [entityId] itself) so
/// it drops into both the single-light popup and the group popup's member
/// list unchanged.
class LightModeControls extends StatefulWidget {
  final String entityId;
  const LightModeControls({super.key, required this.entityId});

  @override
  State<LightModeControls> createState() => _LightModeControlsState();
}

class _LightModeControlsState extends State<LightModeControls> {
  _LightMode? _mode;
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    final store = Provider.of<StateStore>(context, listen: false);

    void call(String service, [Map<String, dynamic>? data]) =>
        store.callService('light', service, entityId: widget.entityId, data: data);

    return EntityWatcher(
      entityIds: [widget.entityId],
      builder: (context, states) {
        final entity = states[widget.entityId];
        final on = entity?.state == 'on';
        final name = entity?.attr<String>('friendly_name', widget.entityId) ?? widget.entityId;
        final modes =
            (entity?.attributes['supported_color_modes'] as List?)?.cast<String>() ?? const [];
        final supportsColor = modes.any((m) => ['rgb', 'rgbw', 'rgbww', 'hs', 'xy'].contains(m));
        final supportsTemp = modes.contains('color_temp');
        final supportsBrightness = modes.any((m) => m != 'onoff');

        final available = [
          if (supportsBrightness) _LightMode.brightness,
          if (supportsColor) _LightMode.color,
          if (supportsTemp) _LightMode.temperature,
        ];
        if (available.isEmpty) {
          return _NameRow(name: name, on: on, onToggle: (v) => call(v ? 'turn_on' : 'turn_off'));
        }
        final mode = available.contains(_mode) ? _mode! : available.first;

        final brightness = (entity?.attributes['brightness'] as num?)?.toDouble();
        final brightnessPct = brightness != null ? (brightness / 255 * 100) : 100.0;
        final hs = (entity?.attributes['hs_color'] as List?)?.cast<num>();
        final hue = hs != null && hs.isNotEmpty ? hs[0].toDouble() : 0.0;
        final minKelvin =
            (entity?.attributes['min_color_temp_kelvin'] as num?)?.toDouble() ?? 2000;
        final maxKelvin =
            (entity?.attributes['max_color_temp_kelvin'] as num?)?.toDouble() ?? 6535;
        final curKelvin = (entity?.attributes['color_temp_kelvin'] as num?)?.toDouble();

        Widget bar;
        switch (mode) {
          case _LightMode.brightness:
            bar = _FillBar(
              value: (_dragValue ?? brightnessPct).clamp(1.0, 100.0) / 100,
              fillColor: tokens.activeColor,
              onChanged: (v) => setState(() => _dragValue = v * 100),
              onChangeEnd: (v) {
                call('turn_on', {'brightness_pct': (v * 100).round().clamp(1, 100)});
                setState(() => _dragValue = null);
              },
            );
          case _LightMode.color:
            bar = _GradientBar(
              gradient: const LinearGradient(colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ]),
              value: (_dragValue ?? hue) / 360,
              onChanged: (v) => setState(() => _dragValue = v * 360),
              onChangeEnd: (v) {
                call('turn_on', {'hs_color': [v * 360, 100]});
                setState(() => _dragValue = null);
              },
            );
          case _LightMode.temperature:
            final k = (_dragValue ?? curKelvin ?? minKelvin).clamp(minKelvin, maxKelvin);
            bar = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GradientBar(
                  gradient: const LinearGradient(colors: [_warmColor, _coolColor]),
                  value: (k - minKelvin) / (maxKelvin - minKelvin),
                  onChanged: (v) =>
                      setState(() => _dragValue = minKelvin + v * (maxKelvin - minKelvin)),
                  onChangeEnd: (v) {
                    call('turn_on',
                        {'color_temp_kelvin': (minKelvin + v * (maxKelvin - minKelvin)).round()});
                    setState(() => _dragValue = null);
                  },
                ),
                const SizedBox(height: 4),
                Text('${k.round()}K', style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
              ],
            );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NameRow(name: name, on: on, onToggle: (v) => call(v ? 'turn_on' : 'turn_off')),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final m in available) ...[
                  _ModeButton(
                    mode: m,
                    selected: m == mode,
                    onTap: () => setState(() {
                      _mode = m;
                      _dragValue = null;
                    }),
                  ),
                  if (m != available.last) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 14),
            bar,
          ],
        );
      },
    );
  }
}

class _NameRow extends StatelessWidget {
  final String name;
  final bool on;
  final ValueChanged<bool> onToggle;
  const _NameRow({required this.name, required this.on, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(name,
              style:
                  TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        KotiSwitch(
          value: on,
          onChanged: onToggle,
          activeColor: tokens.activeColor,
          inactiveColor: tokens.textSecondary,
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final _LightMode mode;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({required this.mode, required this.selected, required this.onTap});

  IconData get _icon => switch (mode) {
        _LightMode.brightness => Icons.wb_sunny_outlined,
        _LightMode.color => Icons.palette_outlined,
        _LightMode.temperature => Icons.thermostat_outlined,
      };

  String get _label => switch (mode) {
        _LightMode.brightness => 'Brightness',
        _LightMode.color => 'Color',
        _LightMode.temperature => 'Temperature',
      };

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return Expanded(
      child: Material(
        color: selected ? tokens.activeColor.withValues(alpha: 0.18) : tokens.iconCircleBackground,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(_icon, size: 20, color: selected ? tokens.activeColor : tokens.textSecondary),
                const SizedBox(height: 4),
                Text(_label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? tokens.activeColor : tokens.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A flat progress-style bar (no separate thumb) — the fill from the left
/// edge to [value] is the whole visual, matching the reference's solid
/// Brightness bar. Drag/tap anywhere along it to set the value directly.
class _FillBar extends StatelessWidget {
  final double value; // 0..1
  final Color fillColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _FillBar({
    required this.value,
    required this.fillColor,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset local) =>
            onChanged((local.dx / constraints.maxWidth).clamp(0.0, 1.0));
        return GestureDetector(
          onTapDown: (d) => update(d.localPosition),
          onPanStart: (d) => update(d.localPosition),
          onPanUpdate: (d) => update(d.localPosition),
          onPanEnd: (_) => onChangeEnd(value),
          onTapUp: (_) => onChangeEnd(value),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: tokens.iconCircleBackground,
              borderRadius: BorderRadius.circular(22),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A full-width gradient bar with a thin vertical position indicator —
/// used for Color (hue-only, saturation fixed at 100%) and Temperature.
class _GradientBar extends StatelessWidget {
  final Gradient gradient;
  final double value; // 0..1
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _GradientBar({
    required this.gradient,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset local) =>
            onChanged((local.dx / constraints.maxWidth).clamp(0.0, 1.0));
        return GestureDetector(
          onTapDown: (d) => update(d.localPosition),
          onPanStart: (d) => update(d.localPosition),
          onPanUpdate: (d) => update(d.localPosition),
          onPanEnd: (_) => onChangeEnd(value),
          onTapUp: (_) => onChangeEnd(value),
          child: Container(
            height: 44,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: gradient),
            child: Align(
              alignment: Alignment(value.clamp(0.0, 1.0) * 2 - 1, 0),
              child: Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 3),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
