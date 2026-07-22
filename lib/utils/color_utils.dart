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

/// A single good→critical color ramp, shared by every value-to-color popup
/// that isn't temperature/humidity (AQI, wattage, network restart state) —
/// these used to each declare their own copy of the same four hex values
/// independently; each caller still owns its own thresholds, only the
/// colors themselves are shared here. Values are the real ones resolved
/// from `hemma-popup-green/yellow/orange/red-color` in `hemma_glass.yaml`
/// (its `var(--x, fallback)` fallback hexes are vestigial — `--x` is always
/// defined, so the fallback never actually renders; these are what's
/// really on screen), not the placeholder hexes an earlier pass here
/// invented without checking the original theme source.
enum SeverityTier { good, warning, elevated, critical }

const Map<SeverityTier, Color> kSeverityColors = {
  SeverityTier.good: Color(0xFF67F5A0), // hemma-color-green-soft
  SeverityTier.warning: Color(0xFFFFCC00), // hemma-color-yellow
  SeverityTier.elevated: Color(0xFFFF9230), // hemma-color-orange
  SeverityTier.critical: Color(0xFFFF4245), // hemma-color-red
};

/// Battery specifically uses a different, more saturated green for "good"
/// than the general severity ramp above (`hemma_popup_battery.yaml` hardcodes
/// `#44e371` directly rather than referencing `hemma-popup-green-color`),
/// at its own thresholds (≤10% critical, ≤20% low) — distinct enough from
/// the general ramp to need its own small map rather than borrowing
/// [kSeverityColors].
enum BatteryTier { critical, low, good }

BatteryTier batteryTier(double percent) {
  if (percent <= 10) return BatteryTier.critical;
  if (percent <= 20) return BatteryTier.low;
  return BatteryTier.good;
}

const Map<BatteryTier, Color> kBatteryColors = {
  BatteryTier.critical: Color(0xFFFF4245), // hemma-color-red
  BatteryTier.low: Color(0xFFFF9230), // hemma-color-orange
  BatteryTier.good: Color(0xFF44E371), // hemma-color-green
};

Color colorForBattery(double percent) => kBatteryColors[batteryTier(percent)]!;
