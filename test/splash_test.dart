import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:koti/screens/koti_splash_screen.dart';

/// Advances the fake clock in small steps rather than one big jump —
/// a single large `pump(duration)` can step clean over a `Future.delayed`
/// scheduled mid-flight (e.g. by an animation status listener) without
/// firing it. Chunked pumping is the reliable way to drive timer-based
/// callbacks in this widget's tests.
Future<void> _advance(WidgetTester tester, Duration total,
    {Duration step = const Duration(milliseconds: 100)}) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  Widget harness(bool ready, void Function() onFinished) => MaterialApp(
        home: KotiSplashScreen(ready: ready, onFinished: onFinished),
      );

  testWidgets(
      'builds house+title, loops as a loading cue, finishes once ready',
      (tester) async {
    var finished = false;

    await tester.pumpWidget(harness(false, () => finished = true));
    await tester.pump(); // ticker baseline frame

    // Mid house-draw, mid title-draw: painting must not throw.
    await _advance(tester, const Duration(milliseconds: 1200));

    // Past the intro (1800ms) and into the redraw loop.
    await _advance(tester, const Duration(milliseconds: 700));
    expect(find.text('Connecting to Home Assistant…'), findsOneWidget);

    // Several loop cycles (1500ms each) while still not ready: never
    // finishes, keeps looping without throwing.
    await _advance(tester, const Duration(milliseconds: 3000));
    expect(finished, isFalse);

    // Becomes ready mid-loop: must wait for the next hold window rather
    // than cutting the redraw off mid-erase, then finish shortly after.
    await tester.pumpWidget(harness(true, () => finished = true));
    await _advance(tester, const Duration(milliseconds: 2200));
    expect(finished, isTrue);
  });

  testWidgets('skips the redraw loop entirely when already ready',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(harness(true, () => finished = true));
    // Intro (1800ms) + finish delay (450ms), no loop cycle required.
    await _advance(tester, const Duration(milliseconds: 2500));
    expect(finished, isTrue);
  });

  testWidgets('tapping fast-forwards the build but not the redraw loop',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(harness(false, () => finished = true));
    await tester.pump();

    await tester.tap(find.byType(GestureDetector).first);
    await _advance(tester, const Duration(milliseconds: 700));
    expect(find.text('Connecting to Home Assistant…'), findsOneWidget);
    expect(finished, isFalse);
  });
}
