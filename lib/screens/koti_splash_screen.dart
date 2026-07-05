import 'package:flutter/material.dart';

/// Animated splash: a line-art house draws itself like a technical pen,
/// then "KOTI" draws in below it the same way. Once built, the house
/// keeps redrawing itself — draw, hold, erase, repeat — as a loading
/// indicator in its own right, for as long as the app is still connecting.
/// The moment it's ready, the house is allowed to finish its current
/// redraw and settle before the dashboard takes over.
///
/// Single painter, plain [Path]/[PathMetric] reveals, no third-party
/// packages — cheap enough for the old wall tablet.
class KotiSplashScreen extends StatefulWidget {
  /// Whether the app behind the splash is ready to be shown.
  final bool ready;
  final VoidCallback onFinished;

  const KotiSplashScreen({
    super.key,
    required this.ready,
    required this.onFinished,
  });

  static const background = Color(0xFFB8A18F);

  @override
  State<KotiSplashScreen> createState() => _KotiSplashScreenState();
}

enum _Phase { intro, looping, finishing }

class _KotiSplashScreenState extends State<KotiSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  _Phase _phase = _Phase.intro;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) _onIntroComplete();
    });
    _loop.addListener(_onLoopTick);
    _intro.forward();
  }

  void _onIntroComplete() {
    if (widget.ready) {
      _finish();
    } else {
      setState(() => _phase = _Phase.looping);
      _loop.repeat();
    }
  }

  /// Only settle once the house is fully (re)drawn and briefly held — never
  /// cut the redraw off mid-erase.
  void _onLoopTick() {
    if (_phase != _Phase.looping || !widget.ready) return;
    final v = _loop.value;
    if (v >= 0.55 && v < 0.68) {
      _loop.stop();
      _finish();
    }
  }

  void _finish() {
    setState(() => _phase = _Phase.finishing);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  double _interval(double value, double begin, double end,
      [Curve curve = Curves.linear]) {
    final t = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  /// Draw 0→1, hold at 1, erase 1→0, then the loop repeats — the house
  /// redrawing itself doubles as the loading cue.
  double _loopCycle(double v) {
    if (v < 0.55) return Curves.easeInOut.transform(v / 0.55);
    if (v < 0.68) return 1.0;
    return 1.0 - Curves.easeIn.transform((v - 0.68) / 0.32);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KotiSplashScreen.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tap fast-forwards the one-time build; the redraw loop itself is
        // a genuine "still connecting" state and isn't skippable.
        onTap: () {
          if (_phase == _Phase.intro && _intro.isAnimating) {
            _intro.value = 1.0;
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_intro, _loop]),
                  builder: (context, _) {
                    final double houseReveal;
                    final double titleReveal;
                    if (_phase == _Phase.intro) {
                      houseReveal =
                          _interval(_intro.value, 0.0, 0.62, Curves.easeInOut);
                      titleReveal =
                          _interval(_intro.value, 0.62, 1.0, Curves.easeOut);
                    } else {
                      houseReveal = _loopCycle(_loop.value);
                      titleReveal = 1.0;
                    }
                    return CustomPaint(
                      painter: _KotiSplashPainter(
                        houseReveal: houseReveal,
                        titleReveal: titleReveal,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: AnimatedOpacity(
                opacity: _phase == _Phase.looping ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: const Text(
                  'Connecting to Home Assistant…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 14,
                    color: Color.fromRGBO(255, 255, 255, 0.85),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reveals [source] up to arc-length fraction [t] (0..1), walking its
/// contours in the order they were added — the "pen" drawing the path.
/// Reusing this with a shrinking [t] traces the same path backward,
/// which is what makes the erase phase read as an eraser retracing the
/// pen's steps rather than a fade.
Path _revealPath(Path source, double t) {
  final result = Path();
  if (t <= 0) return result;
  final metrics = source.computeMetrics().toList();
  final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
  final target = total * t.clamp(0.0, 1.0);

  var consumed = 0.0;
  for (final metric in metrics) {
    if (consumed >= target) break;
    final remaining = target - consumed;
    if (remaining >= metric.length) {
      result.addPath(metric.extractPath(0, metric.length), Offset.zero);
    } else {
      result.addPath(metric.extractPath(0, remaining), Offset.zero);
      break;
    }
    consumed += metric.length;
  }
  return result;
}

class _KotiSplashPainter extends CustomPainter {
  final double houseReveal;
  final double titleReveal;

  _KotiSplashPainter({required this.houseReveal, required this.titleReveal});

  static final Paint _stroke = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.square;

  /// Minimalist house in unit coordinates (roughly centered on its own
  /// origin), contours added in pen order: floor, left wall, roof, right
  /// wall, door — reads as one continuous line drawing a house silhouette.
  Path _housePath(Offset center, double scale) {
    final path = Path();
    void line(Offset a, Offset b) {
      path.moveTo(center.dx + a.dx * scale, center.dy + a.dy * scale);
      path.lineTo(center.dx + b.dx * scale, center.dy + b.dy * scale);
    }

    line(const Offset(-0.50, 0.50), const Offset(0.50, 0.50)); // floor
    line(const Offset(-0.50, 0.50), const Offset(-0.50, -0.10)); // left wall
    line(const Offset(-0.50, -0.10), const Offset(0.00, -0.55)); // roof left
    line(const Offset(0.00, -0.55), const Offset(0.50, -0.10)); // roof right
    line(const Offset(0.50, -0.10), const Offset(0.50, 0.50)); // right wall
    line(const Offset(-0.09, 0.50), const Offset(-0.09, 0.16)); // door left
    line(const Offset(-0.09, 0.16), const Offset(0.09, 0.16)); // door top
    line(const Offset(0.09, 0.16), const Offset(0.09, 0.50)); // door right
    return path;
  }

  static const List<double> _letterWidths = [0.66, 0.78, 0.70, 0.16];
  static const double _letterGap = 0.26;

  double get _titleUnits =>
      _letterWidths.reduce((a, b) => a + b) +
      _letterGap * (_letterWidths.length - 1);

  /// KOTI as monoline geometric letterforms in the same pen stroke as the
  /// house — turning type into paths needs a third-party font-parsing
  /// package, and matching the house's technical-pen style reads more
  /// intentional than a rendered font would here anyway.
  Path _titlePath(Offset topLeft, double capHeight) {
    final path = Path();
    var x = 0.0;
    void line(double x1, double y1, double x2, double y2) {
      path.moveTo(topLeft.dx + (x + x1) * capHeight, topLeft.dy + y1 * capHeight);
      path.lineTo(topLeft.dx + (x + x2) * capHeight, topLeft.dy + y2 * capHeight);
    }

    // K
    line(0, 0, 0, 1);
    line(0, 0.52, 0.66, 0);
    line(0.22, 0.35, 0.66, 1);
    x += _letterWidths[0] + _letterGap;
    // O
    path.addOval(Rect.fromLTWH(
        topLeft.dx + x * capHeight, topLeft.dy, 0.78 * capHeight, capHeight));
    x += _letterWidths[1] + _letterGap;
    // T
    line(0, 0, 0.70, 0);
    line(0.35, 0, 0.35, 1);
    x += _letterWidths[2] + _letterGap;
    // I
    line(0.06, 0, 0.06, 1);
    line(0.0, 0, 0.12, 0);
    line(0.0, 1, 0.12, 1);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final houseScale = size.shortestSide * 0.30;
    final titleCapHeight = size.shortestSide * 0.11;
    final gap = size.shortestSide * 0.09;

    final houseHeight = 1.05 * houseScale;
    final groupHeight = houseHeight + gap + titleCapHeight;
    final top = size.height / 2 - groupHeight / 2;

    final houseCenter = Offset(size.width / 2, top + houseHeight / 2 - 0.025 * houseScale);
    final titleWidth = _titleUnits * titleCapHeight;
    final titleTopLeft =
        Offset(size.width / 2 - titleWidth / 2, top + houseHeight + gap);

    if (houseReveal > 0) {
      canvas.drawPath(
        _revealPath(_housePath(houseCenter, houseScale), houseReveal),
        _stroke,
      );
    }
    if (titleReveal > 0) {
      canvas.drawPath(
        _revealPath(_titlePath(titleTopLeft, titleCapHeight), titleReveal),
        _stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KotiSplashPainter oldDelegate) =>
      oldDelegate.houseReveal != houseReveal ||
      oldDelegate.titleReveal != titleReveal;
}
