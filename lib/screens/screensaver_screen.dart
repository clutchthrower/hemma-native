import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../store/settings_store.dart';
import '../theme/koti_theme.dart';
import '../widgets/clock_widget.dart';
import '../widgets/weather_widget.dart';

/// Full-screen dark idle state shown after the screensaver timeout —
/// dismissed by any tap. Shows a clock and/or weather (Display settings),
/// and always keeps the content moving so it can't burn into an always-on
/// panel: either hopping to a new spot each minute, or drifting DVD-logo
/// style, bouncing off the edges.
class ScreensaverScreen extends StatelessWidget {
  final VoidCallback onDismiss;
  const ScreensaverScreen({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final settings = Provider.of<SettingsStore>(context, listen: false);

    final content = RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (theme.screensaverShowClock)
            const ClockWidget(
              style: TextStyle(
                fontFamily: 'Hanken Grotesk',
                fontWeight: FontWeight.w300,
                fontSize: 64,
                color: Colors.white38,
              ),
            ),
          if (theme.screensaverShowWeather && settings.weatherEntityId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: WeatherWidget(
                weatherEntityId: settings.weatherEntityId!,
                iconSize: 26,
                style: const TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontWeight: FontWeight.w400,
                  fontSize: 24,
                  color: Colors.white30,
                ),
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black,
        child: theme.screensaverMotion == ScreensaverMotion.bounce
            ? _BounceLayer(child: content)
            : _HopLayer(child: content),
      ),
    );
  }
}

/// Glides the content to a new random position once a minute.
class _HopLayer extends StatefulWidget {
  final Widget child;
  const _HopLayer({required this.child});

  @override
  State<_HopLayer> createState() => _HopLayerState();
}

class _HopLayerState extends State<_HopLayer> {
  final _random = Random();
  Alignment _alignment = Alignment.center;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _alignment = Alignment(
            _random.nextDouble() * 1.6 - 0.8,
            _random.nextDouble() * 1.6 - 0.8,
          ));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      alignment: _alignment,
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      child: widget.child,
    );
  }
}

/// The DVD logo: drifts at constant speed, bouncing off the walls.
class _BounceLayer extends StatefulWidget {
  final Widget child;
  const _BounceLayer({required this.child});

  @override
  State<_BounceLayer> createState() => _BounceLayerState();
}

class _BounceLayerState extends State<_BounceLayer>
    with SingleTickerProviderStateMixin {
  final _contentKey = GlobalKey();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Offset _pos = const Offset(60, 60);
  Offset _vel = const Offset(42, 34); // px/second — a lazy glide

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 1) return; // first frame / resumed from pause

    final screen = context.size;
    final content = _contentKey.currentContext?.size;
    if (screen == null || content == null) return;

    var next = _pos + _vel * dt;
    var vx = _vel.dx;
    var vy = _vel.dy;
    final maxX = (screen.width - content.width).clamp(0.0, double.infinity);
    final maxY = (screen.height - content.height).clamp(0.0, double.infinity);
    if (next.dx <= 0 || next.dx >= maxX) {
      vx = -vx;
      next = Offset(next.dx.clamp(0.0, maxX), next.dy);
    }
    if (next.dy <= 0 || next.dy >= maxY) {
      vy = -vy;
      next = Offset(next.dx, next.dy.clamp(0.0, maxY));
    }
    setState(() {
      _pos = next;
      _vel = Offset(vx, vy);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _pos.dx,
          top: _pos.dy,
          child: KeyedSubtree(key: _contentKey, child: widget.child),
        ),
      ],
    );
  }
}
