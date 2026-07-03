import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/entity_state.dart';
import '../widgets/entity_watcher.dart';

/// Maps a Home Assistant `weather.*` condition string to a bundled SVG in
/// `assets/weather/` (all 21 states from spec 15.2 collapse onto this
/// smaller, cleaner icon set).
String weatherAssetFor(String condition) {
  const map = {
    'clear-night': 'clear-night',
    'cloudy': 'cloudy',
    'exceptional': 'weather-mixed',
    'fog': 'fog',
    'hail': 'snow',
    'lightning': 'thunder',
    'lightning-rainy': 'lightning-rainy',
    'partlycloudy': 'partly-cloudy-day',
    'pouring': 'rain-heavy',
    'rainy': 'rain',
    'snowy': 'snow',
    'snowy-rainy': 'weather-mixed',
    'sunny': 'clear-day',
    'windy': 'wind',
    'windy-variant': 'wind',
  };
  return 'assets/weather/${map[condition] ?? 'cloudy'}.svg';
}

/// First `weather.*` entity's condition + temperature, per spec's weather
/// badge. [weatherEntityId] defaults to `weather.forecast_home` naming
/// conventions but any discovered weather entity id works.
class WeatherWidget extends StatelessWidget {
  final String weatherEntityId;
  final TextStyle? style;
  final double iconSize;

  const WeatherWidget({
    super.key,
    required this.weatherEntityId,
    this.style,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return EntityWatcher(
      entityIds: [weatherEntityId],
      builder: (context, states) {
        final EntityState? weather = states[weatherEntityId];
        if (weather == null) return const SizedBox.shrink();
        final temp = weather.attrDouble('temperature');
        // Temperature first, icon after — "72° ☀", as on the hero header.
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              temp != null ? '${temp.toStringAsFixed(0)}°' : weather.state,
              style: style ??
                  const TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(width: 6),
            SvgPicture.asset(
              weatherAssetFor(weather.state),
              width: iconSize,
              height: iconSize,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ],
        );
      },
    );
  }
}
