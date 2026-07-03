import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a bundled icon with a solid tint, replicating the original
/// `-webkit-mask-image` technique used to dynamically color SVGs in the web
/// dashboard. Icons never load over the network — all 74 assets ship in
/// `assets/icons/`.
class HemmaIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;

  const HemmaIcon(
    this.name, {
    super.key,
    this.size = 26,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// Circular icon container matching `#img-cell` from `hemma_entity.yaml`:
/// 44px on desktop/tablet, 38px on mobile portrait.
class HemmaIconCircle extends StatelessWidget {
  final String iconName;
  final Color iconColor;
  final Color backgroundColor;
  final double diameter;
  final double? iconSize;

  const HemmaIconCircle({
    super.key,
    required this.iconName,
    required this.iconColor,
    required this.backgroundColor,
    this.diameter = 44,
    this.iconSize,
  });

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
      child: HemmaIcon(
        iconName,
        size: iconSize ?? diameter * 0.59,
        color: iconColor,
      ),
    );
  }
}
