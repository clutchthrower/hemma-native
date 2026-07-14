import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Extracts a single "mood" color from an album art URL, for the ambient
/// now-playing background tint (Settings → Music page's HOMEii Flow-style
/// look). This is deliberately NOT a real-time blur of the artwork — that's
/// banned on this hardware (CLAUDE.md) — it's a one-off average-color
/// sample, decoded at a tiny size via [ResizeImage] so it costs almost
/// nothing, then reused as a static gradient stop until the track changes.
class AlbumColorExtractor {
  AlbumColorExtractor._();

  static final Map<String, Color> _cache = {};

  /// Returns null if the image can't be loaded/decoded — callers should
  /// fall back to a neutral background in that case.
  static Future<Color?> extract(String url, {Map<String, String>? headers}) async {
    final cached = _cache[url];
    if (cached != null) return cached;

    final provider = ResizeImage(NetworkImage(url, headers: headers), width: 24);
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);

    final ui.Image image;
    try {
      image = await completer.future;
    } catch (_) {
      return null;
    }

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();

    int r = 0, g = 0, b = 0, count = 0;
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      if (bytes[i + 3] < 32) continue; // skip near-transparent pixels
      r += bytes[i];
      g += bytes[i + 1];
      b += bytes[i + 2];
      count++;
    }
    if (count == 0) return null;

    final color = _mooded(Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count));
    _cache[url] = color;
    return color;
  }

  /// Clamps lightness/saturation so the tint always reads as a moody dark
  /// tone against this app's dark theme, regardless of how bright or washed
  /// out the source artwork's average color is (a pale album cover
  /// shouldn't wash the background out to near-white).
  static Color _mooded(Color raw) {
    final hsl = HSLColor.fromColor(raw);
    return hsl
        .withLightness(hsl.lightness.clamp(0.12, 0.34))
        .withSaturation(hsl.saturation.clamp(0.25, 0.75))
        .toColor();
  }
}
