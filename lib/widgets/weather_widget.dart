import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entity_state.dart';
import '../store/settings_store.dart';
import '../widgets/entity_watcher.dart';
import 'entity_picker.dart';
import 'koti_icon.dart';

/// Maps a Home Assistant `weather.*` condition string to a [KotiIcon] name
/// (all 21 states from spec 15.2 collapse onto this smaller, cleaner icon
/// set).
String weatherIconFor(String condition) {
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
  return map[condition] ?? 'cloudy';
}

/// Long-press-to-edit for the Home hero's weather display — the same
/// pattern `badge_edit_sheet.dart` uses for badges, but a single field, so
/// it's just a picker rather than a whole sheet. Also editable from Rooms
/// settings (`rooms_settings_page.dart`), since it's a whole-home setting,
/// not per-room.
void showWeatherEntityPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Consumer<SettingsStore>(
        builder: (context, settings, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weather', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            EntityPickerField(
              label: 'Weather entity',
              value: settings.weatherEntityId,
              domains: const ['weather'],
              onChanged: settings.setWeatherEntityId,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
            KotiIcon(
              weatherIconFor(weather.state),
              size: iconSize,
              color: Colors.white,
            ),
          ],
        );
      },
    );
  }
}
