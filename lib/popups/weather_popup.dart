import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/state_store.dart';
import '../theme/koti_theme.dart';
import '../theme/tokens.dart';
import '../widgets/entity_watcher.dart';
import '../widgets/koti_icon.dart';
import '../widgets/weather_widget.dart';
import 'popup_base.dart';

/// Readable label for a HA `weather.*` condition string — same 15-state set
/// [weatherIconFor] maps to icons for.
String _conditionLabel(String condition) {
  const map = {
    'clear-night': 'Clear',
    'cloudy': 'Cloudy',
    'exceptional': 'Exceptional',
    'fog': 'Fog',
    'hail': 'Hail',
    'lightning': 'Thunderstorm',
    'lightning-rainy': 'Thunderstorms',
    'partlycloudy': 'Partly Cloudy',
    'pouring': 'Heavy Rain',
    'rainy': 'Rain',
    'snowy': 'Snow',
    'snowy-rainy': 'Snow/Rain',
    'sunny': 'Sunny',
    'windy': 'Windy',
    'windy-variant': 'Windy',
  };
  return map[condition] ?? condition;
}

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _hourLabel(DateTime local) {
  final h = local.hour;
  final period = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12$period';
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _ForecastItem {
  final DateTime time;
  final String condition;
  final double? temp;
  final double? tempLow;

  _ForecastItem({
    required this.time,
    required this.condition,
    this.temp,
    this.tempLow,
  });

  factory _ForecastItem.fromJson(Map<String, dynamic> json) {
    final parsed = DateTime.tryParse(json['datetime'] as String? ?? '');
    return _ForecastItem(
      time: (parsed ?? DateTime.now()).toLocal(),
      condition: json['condition'] as String? ?? 'cloudy',
      temp: (json['temperature'] as num?)?.toDouble(),
      tempLow: (json['templow'] as num?)?.toDouble(),
    );
  }
}

/// Fetches both forecast granularities in parallel via HA's
/// `weather.get_forecasts` response-service (not every weather integration
/// supports every `type`, so each request fails independently rather than
/// one missing type blanking the whole popup).
Future<List<_ForecastItem>> _fetchForecast(
  StateStore store,
  String weatherEntityId,
  String type,
) async {
  try {
    final response = await store.callServiceForResponse(
      'weather',
      'get_forecasts',
      data: {'type': type},
      entityId: weatherEntityId,
    );
    final entry = response[weatherEntityId];
    final list = entry is Map ? entry['forecast'] : null;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => _ForecastItem.fromJson(m.cast<String, dynamic>()))
        .toList();
  } catch (_) {
    return const [];
  }
}

/// Tapping the Home hero's weather display (outside edit mode) opens this —
/// the current condition plus HA's own hourly/daily forecast, fetched live
/// via `weather.get_forecasts` rather than any bundled forecast data.
void showWeatherForecastPopup(BuildContext context, String weatherEntityId) {
  final store = Provider.of<StateStore>(context, listen: false);
  showKotiPopup(
    context,
    title: 'Weather',
    builder: (context) => _WeatherForecastContent(
      store: store,
      weatherEntityId: weatherEntityId,
    ),
  );
}

class _WeatherForecastContent extends StatefulWidget {
  final StateStore store;
  final String weatherEntityId;

  const _WeatherForecastContent({
    required this.store,
    required this.weatherEntityId,
  });

  @override
  State<_WeatherForecastContent> createState() => _WeatherForecastContentState();
}

class _WeatherForecastContentState extends State<_WeatherForecastContent> {
  // Computed once per popup open — HA's own forecast data doesn't need
  // refetching on every entity-state tick while this is on screen.
  late final Future<(List<_ForecastItem>, List<_ForecastItem>)> _forecasts =
      Future.wait([
    _fetchForecast(widget.store, widget.weatherEntityId, 'hourly'),
    _fetchForecast(widget.store, widget.weatherEntityId, 'daily'),
  ]).then((r) => (r[0], r[1]));

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return EntityWatcher(
      entityIds: [widget.weatherEntityId],
      builder: (context, states) {
        final weather = states[widget.weatherEntityId];
        return FutureBuilder<(List<_ForecastItem>, List<_ForecastItem>)>(
          future: _forecasts,
          builder: (context, snapshot) {
            final (hourly, daily) = snapshot.data ?? (const [], const []);
            final loading = snapshot.connectionState != ConnectionState.done;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (weather != null)
                  Row(
                    children: [
                      KotiIcon(weatherIconFor(weather.state), size: 36, color: tokens.textPrimary),
                      const SizedBox(width: 12),
                      Text(
                        weather.attrDouble('temperature') != null
                            ? '${weather.attrDouble('temperature')!.toStringAsFixed(0)}°'
                            : weather.state,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(_conditionLabel(weather.state),
                          style: TextStyle(fontSize: 14, color: tokens.textSecondary)),
                    ],
                  ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (hourly.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('Hourly',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: hourly.length.clamp(0, 24),
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, i) => _HourColumn(item: hourly[i], tokens: tokens),
                      ),
                    ),
                  ],
                  if (daily.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('7-Day',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary)),
                    const SizedBox(height: 4),
                    for (final day in daily.take(7))
                      _DayRow(item: day, isToday: _isSameDay(day.time, DateTime.now()), tokens: tokens),
                  ],
                  if (hourly.isEmpty && daily.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('Forecast unavailable for this weather entity',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _HourColumn extends StatelessWidget {
  final _ForecastItem item;
  final KotiTokens tokens;
  const _HourColumn({required this.item, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_hourLabel(item.time), style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
          const SizedBox(height: 6),
          KotiIcon(weatherIconFor(item.condition), size: 22, color: tokens.textPrimary),
          const SizedBox(height: 6),
          if (item.temp != null)
            Text('${item.temp!.toStringAsFixed(0)}°',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final _ForecastItem item;
  final bool isToday;
  final KotiTokens tokens;
  const _DayRow({required this.item, required this.isToday, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              isToday ? 'Today' : _weekdayNames[item.time.weekday - 1],
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
            ),
          ),
          KotiIcon(weatherIconFor(item.condition), size: 20, color: tokens.textSecondary),
          const Spacer(),
          if (item.tempLow != null)
            Text('${item.tempLow!.toStringAsFixed(0)}°',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary)),
          const SizedBox(width: 10),
          if (item.temp != null)
            SizedBox(
              width: 32,
              child: Text('${item.temp!.toStringAsFixed(0)}°',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
            ),
        ],
      ),
    );
  }
}
