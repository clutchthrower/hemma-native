import 'package:flutter/material.dart';

import 'koti_icon.dart';

/// A toggle switch rendered as `toggle_on`/`toggle_off` Material Symbols
/// glyphs (via [KotiIcon]) instead of Flutter's built-in [Switch].
///
/// [Switch] paints its pill/thumb via plain Canvas shape ops
/// (RRect + circle) — on at least one real Android tablet tested (a budget
/// Samsung Galaxy Tab A, SM-T387V), those showed real, confirmed
/// device-specific pixelation in portrait orientation specifically (not
/// reproduced in landscape on the same device, nor on an LG tablet in
/// either orientation) — most likely because that tablet's panel has no
/// native landscape hardware mode, so landscape is a rotated composite
/// that happens to blur the same underlying AA coarseness portrait shows
/// unfiltered. Confirmed not fixable via the Impeller/Skia renderer choice
/// (pixel-identical either way). Font glyphs sidestep it entirely, same
/// reasoning as [KotiIcon] itself — see that file's doc comment for the
/// full investigation.
class KotiSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const KotiSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 40,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = value
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : (inactiveColor ?? Theme.of(context).unselectedWidgetColor);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Opacity(
        opacity: onChanged == null ? 0.5 : 1,
        child: KotiIcon(
          value ? 'toggle_on' : 'toggle_off',
          size: size,
          color: color,
        ),
      ),
    );
  }
}

/// [ListTile] with a trailing [KotiSwitch] — a drop-in for Flutter's
/// [SwitchListTile] covering the params this app's settings pages actually
/// use (title/subtitle/secondary/contentPadding/dense), for the same
/// pixelation reason documented on [KotiSwitch] above. Tapping anywhere in
/// the row toggles, matching [SwitchListTile]'s own behavior.
class KotiSwitchListTile extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;
  final bool dense;

  const KotiSwitchListTile({
    super.key,
    this.title,
    this.subtitle,
    this.secondary,
    required this.value,
    required this.onChanged,
    this.contentPadding,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: contentPadding,
      dense: dense,
      leading: secondary,
      title: title,
      subtitle: subtitle,
      trailing: KotiSwitch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}
