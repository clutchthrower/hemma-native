import 'package:flutter/material.dart';

enum DeviceMode { mobile, tablet, desktop }

/// Mirrors the original CSS breakpoints from `hemma_entity_layout.yaml` /
/// the navbar templates: width alone decides mobile vs tablet vs desktop.
DeviceMode deviceModeFor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 768) return DeviceMode.mobile;
  if (width <= 1024) return DeviceMode.tablet;
  return DeviceMode.desktop;
}

bool isPortrait(BuildContext context) =>
    MediaQuery.orientationOf(context) == Orientation.portrait;
