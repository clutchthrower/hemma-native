import 'package:flutter/material.dart';

import 'koti_icon_glyphs.dart';

/// Renders a bundled icon with a solid tint, replicating the original
/// `-webkit-mask-image` technique used to dynamically color SVGs in the web
/// dashboard — the icon set itself (and this app's whole visual identity)
/// traces back to Google's Material Symbols, per the upstream
/// willsanderson/Hemma web dashboard this project is based on.
///
/// Renders as a font glyph (`assets/fonts/MaterialSymbolsRounded.ttf`,
/// looked up via [kKotiIconGlyphs]) rather than an SVG or a pre-rasterized
/// PNG image, after both of those were tried and both hit real,
/// device-specific rendering bugs on one of this app's real test tablets (a
/// budget Samsung Galaxy Tab A, SM-T387V — not reproducible on an LG tablet
/// with the same reported resolution/density, so a GPU-driver-specific
/// quirk, not something wrong in this app's own code):
/// - Live `flutter_svg`/`vector_graphics` SVG rendering showed rough,
///   under-anti-aliased edges at these icon sizes, not fixable via the
///   Impeller/Skia renderer choice or supersampling the SVG's own render
///   resolution (both tested, zero visual change).
/// - Switching to pre-rasterized PNGs (`Image.asset` + `FilterQuality.high`
///   — the same approach already working for room background photos) fixed
///   that, but surfaced a second, separate bug: any icon whose source `.svg`
///   carried the invisible `<rect opacity="0">` background element that
///   Apple-CoreSVG-exported icons (i.e. most of the original icon set)
///   happened to have rendered as a solid tinted block instead of its
///   actual shape. Confirmed via isolation testing this was a
///   `BlendMode.srcIn` compositing bug on that specific device — not the
///   PNG/alpha data (same bytes render fine via ImageMagick and via a
///   plain untinted `Image.asset`), and not specific to `Image`'s
///   `color`/`colorBlendMode` vs a `ColorFiltered` wrapper (identical bug
///   either way).
///
/// Text/glyph painting is a completely different, far more heavily-used
/// Skia code path than either of those image-compositing routes, so it
/// sidesteps both bugs entirely — confirmed by direct on-device testing.
/// It's also simpler: one ~1.8MB font (already instanced at a fixed
/// FILL=1/GRAD=0/opsz=24/wght=400 — no runtime variable-font-axis
/// dependency) covering every icon this app could ever want, instead of a
/// PNG (or SVG) per icon per icon set.
class KotiIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;

  const KotiIcon(
    this.name, {
    super.key,
    this.size = 26,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final codepoint = kKotiIconGlyphs[name];
    assert(codepoint != null, 'No Material Symbols glyph mapped for icon "$name"');
    if (codepoint == null) return SizedBox(width: size, height: size);
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          String.fromCharCode(codepoint),
          style: TextStyle(
            fontFamily: 'Material Symbols Rounded',
            fontSize: size,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Circular icon container matching `#img-cell` from `hemma_entity.yaml`:
/// 44px on desktop/tablet, 38px on mobile portrait. Either [iconName] (a
/// bundled SVG) or [child] (e.g. a Material [Icon], for concepts the
/// bundled icon set has no asset for — Wi-Fi, developer tools, exit) must
/// be given.
class KotiIconCircle extends StatelessWidget {
  final String? iconName;
  final Widget? child;
  final Color iconColor;
  final Color backgroundColor;
  final double diameter;
  final double? iconSize;

  const KotiIconCircle({
    super.key,
    this.iconName,
    this.child,
    required this.iconColor,
    required this.backgroundColor,
    this.diameter = 44,
    this.iconSize,
  }) : assert(iconName != null || child != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child ??
          KotiIcon(
            iconName!,
            size: iconSize ?? diameter * 0.59,
            color: iconColor,
          ),
    );
  }
}
