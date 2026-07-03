import 'package:flutter/material.dart';

/// Replicates `sensor.hemma_temp_color` / `sensor.hemma_humidity_color` and
/// the literal color values from `hemma_badge_temp.yaml` /
/// `hemma_badge_humidity.yaml` / `themes/hemma/hemma.yaml`.
enum TempColorTier {
  veryCold,
  cool,
  comfortable,
  warm,
  hot,
  veryHot,
}

TempColorTier tempColorTier(double fahrenheit) {
  if (fahrenheit <= 65) return TempColorTier.veryCold;
  if (fahrenheit <= 70) return TempColorTier.cool;
  if (fahrenheit <= 76) return TempColorTier.comfortable;
  if (fahrenheit <= 81) return TempColorTier.warm;
  if (fahrenheit <= 85) return TempColorTier.hot;
  return TempColorTier.veryHot;
}

const Map<TempColorTier, Color> kTempColors = {
  TempColorTier.veryCold: Color(0xFF0091FF), // hemma-color-deep-blue
  TempColorTier.cool: Color(0xFF3CD3FE), // hemma-color-ice
  TempColorTier.comfortable: Color(0xFF67F5A0), // hemma-color-green-soft
  TempColorTier.warm: Color(0xFFFFCC00), // hemma-color-yellow
  TempColorTier.hot: Color(0xFFFF9230), // hemma-color-orange
  TempColorTier.veryHot: Color(0xFFFF4245), // hemma-color-red
};

Color colorForTempF(double fahrenheit) => kTempColors[tempColorTier(fahrenheit)]!;

enum HumidityColorTier { dry, normal, high }

HumidityColorTier humidityColorTier(double percent) {
  if (percent <= 29.99) return HumidityColorTier.dry;
  if (percent >= 61) return HumidityColorTier.high;
  return HumidityColorTier.normal;
}

const Map<HumidityColorTier, Color> kHumidityColors = {
  HumidityColorTier.dry: Color(0xFFFFB254), // hemma-color-amber
  HumidityColorTier.normal: Color(0xFF00C3D0), // hemma-color-teal
  HumidityColorTier.high: Color(0xFF3CD3FE), // hemma-color-ice
};

Color colorForHumidity(double percent) =>
    kHumidityColors[humidityColorTier(percent)]!;

/// Base Hemma color palette (`themes/hemma/hemma.yaml`), exposed for badges
/// and popups that reference a named accent rather than a threshold color.
class HemmaPalette {
  static const blue = Color(0xFF007AFF);
  static const teal = Color(0xFF00C3D0);
  static const yellow = Color(0xFFFFCC00);
  static const green = Color(0xFF44E371);
  static const greenSoft = Color(0xFF67F5A0);
  static const greenPlant = Color(0xFF34C759);
  static const orange = Color(0xFFFF9230);
  static const red = Color(0xFFFF4245);
  static const ice = Color(0xFF3CD3FE);
  static const amber = Color(0xFFFFB254);
  static const deepBlue = Color(0xFF0091FF);
  static const deepOrange = Color(0xFFFF6B30);
  static const pink = Color(0xFFFF4D70);
  static const neutral = Color(0xFFCDCDCF);
  static const purple = Color(0xFF9333EA);
  static const gold = Color(0xFFE5A00D);
  static const presenceHome = Color(0xD949F08C);
  static const presenceAway = Color(0xFFFFCC00);
}
