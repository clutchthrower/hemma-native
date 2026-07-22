import 'package:flutter/material.dart';

enum ColorModePref { system, light, dark }

/// Token architecture per SPECIFICATIONS.md Section 3, with literal values
/// pulled from the original `themes/hemma/hemma.yaml` / `hemma_glass.yaml`.
/// Per CLAUDE.md, no BackdropFilter/real-time blur is used — the original's
/// `backdrop-filter: blur()` surfaces are reproduced as solid low-opacity
/// colors at the same alpha the original used underneath its blur.
///
/// Always renders the Glass look (the original's Base variant is gone —
/// one considered default beats a user-facing toggle nobody needs).
class KotiTokens {
  final Brightness brightness;
  final Color accentColor;
  final double cardTransparency; // 0..1, alpha multiplier for surfaces

  const KotiTokens({
    required this.brightness,
    required this.accentColor,
    required this.cardTransparency,
  });

  bool get isDark => brightness == Brightness.dark;

  // --- Card surfaces (hemma-entity-background-mobile, the touch-tablet
  // variant — this app is always the "mobile" context the original theme
  // describes, never desktop-hover) ---
  Color get entityBackground => (isDark
          ? const Color.fromRGBO(0, 0, 0, 0.18)
          : const Color.fromRGBO(0, 0, 0, 0.25))
      .withValues(alpha: (isDark ? 0.18 : 0.25) * cardTransparency);

  Color get entityBackgroundActive => isDark
      ? const Color.fromRGBO(255, 255, 255, 0.25)
      : const Color.fromRGBO(200, 200, 200, 0.45);

  Color get cardBackground =>
      isDark ? const Color.fromRGBO(0, 0, 0, 0.4) : const Color.fromRGBO(100, 100, 100, 0.1);

  // hemma-dialog-bg: the "Glass" theme's dialog surface is a near-black
  // scrim in both modes (not a literal white light-mode), meant to sit atop
  // a room photo either way — paired with a real BackdropFilter blur now
  // that CLAUDE.md permits it (see popup_base.dart) instead of relying on
  // opacity alone for legibility.
  Color get dialogBackground =>
      isDark ? const Color.fromRGBO(0, 0, 0, 0.35) : const Color.fromRGBO(0, 0, 0, 0.3);

  // hemma-nav-bg: identical in both modes in the original.
  Color get navBackground => const Color.fromRGBO(0, 0, 0, 0.3);

  Color get badgeBackground =>
      isDark ? const Color.fromRGBO(0, 0, 0, 0.5) : const Color.fromRGBO(0, 0, 0, 0.35);

  Color get activeColor => accentColor;
  static const defaultAccent = Color(0xFF6EBAFF); // --primary-color / --accent-color

  // hemma-puck-cool-color / hemma-puck-heat-color — previously sourced from
  // kTempColors' cold/hot ends (0091FF/FF9230) since those two happened to
  // be byte-identical duplicates; turned out both were simply wrong. The
  // real theme's thermostat puck is teal for cool, yellow for heat — a
  // distinct concept from the temperature-severity tiers, not the same
  // value reused.
  Color get puckCoolColor => const Color(0xFF00C3D0);
  Color get puckHeatColor => const Color(0xFFFFCC00);

  Color get iconCircleBackground => const Color.fromRGBO(255, 255, 255, 0.10);

  // --- Shared "glass pill" language (top nav tabs, music tab strip) ---
  Color get pillBackground => const Color.fromRGBO(0, 0, 0, 0.28);
  Color get pillSelectedBackground => const Color.fromRGBO(255, 255, 255, 0.22);

  /// Secondary text on a raw dark background — the pre-theme screens
  /// (splash/onboarding/update) that render before a full `KotiTheme` is
  /// meaningful still want this exact treatment, so it's a plain static
  /// constant rather than an instance getter.
  static const secondaryOnDark = Color.fromRGBO(255, 255, 255, 0.75);

  // --- Text ---
  Color get textPrimary =>
      isDark ? const Color.fromRGBO(255, 255, 255, 0.98) : const Color.fromRGBO(255, 255, 255, 0.95);
  Color get textSecondary => const Color.fromRGBO(240, 240, 240, 0.9);

  Color get entityName =>
      isDark ? const Color.fromRGBO(255, 255, 255, 0.85) : const Color.fromRGBO(255, 255, 255, 0.95);
  Color get entityState =>
      isDark ? const Color.fromRGBO(255, 255, 255, 0.7) : const Color.fromRGBO(240, 240, 240, 0.85);
  Color get entityStateActive =>
      isDark ? const Color.fromRGBO(255, 255, 255, 0.8) : const Color.fromRGBO(245, 245, 245, 0.98);

  // --- Layout constants (hemma_entity_layout.yaml) ---
  double get navHeight => 64;
  double get cardRadius => 28;
  double get badgeRadius => 9999;
  double get pageGutterMobile => 11;
  double get tilesTopPortrait => 350;

  /// Fixed tile size per breakpoint, from `hemma_entity_layout.yaml`.
  static const tileSizeDesktop = Size(290, 200);
  static const tileSizeTablet = Size(220, 160);
  static const tileSizeMobilePortrait = Size(180, 116);
  static const tileSizeMobileLandscape = Size(160, 120);

  /// Specular 1px gradient border — the Glass look's glass-edge highlight.
  /// hemma-card-specular-start/mid/end: a 3-stop gradient, not symmetric.
  Gradient get borderGradient {
    final start = isDark
        ? const Color.fromRGBO(255, 255, 255, 0.20)
        : const Color.fromRGBO(255, 255, 255, 0.24);
    final mid = isDark
        ? const Color.fromRGBO(255, 255, 255, 0.13)
        : const Color.fromRGBO(255, 255, 255, 0.16);
    final end = isDark
        ? const Color.fromRGBO(255, 255, 255, 0.18)
        : const Color.fromRGBO(255, 255, 255, 0.20);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [start, mid, end],
    );
  }

  KotiTokens copyWith({
    Brightness? brightness,
    Color? accentColor,
    double? cardTransparency,
  }) {
    return KotiTokens(
      brightness: brightness ?? this.brightness,
      accentColor: accentColor ?? this.accentColor,
      cardTransparency: cardTransparency ?? this.cardTransparency,
    );
  }
}
