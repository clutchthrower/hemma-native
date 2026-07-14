import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Produces a heavily blurred version of an album art URL for use as the
/// Music page's full-tab background. The blur happens exactly ONCE per
/// track (decode a small copy, blur it into a new bitmap via
/// [ui.ImageFilter.blur], cache the resulting bytes) rather than live —
/// CLAUDE.md bans [BackdropFilter] and other per-frame blur work, so this
/// deliberately produces a plain static image with zero ongoing blur cost,
/// not a filter left attached to the render tree.
class AlbumArtBlurCache {
  AlbumArtBlurCache._();

  static final Map<String, ImageProvider> _cache = {};

  /// Returns null if the image can't be loaded/decoded — callers should
  /// fall back to a solid background in that case.
  static Future<ImageProvider?> blurred(
    String url, {
    Map<String, String>? headers,
    double sigma = 40,
  }) async {
    final cached = _cache[url];
    if (cached != null) return cached;

    // Small decode target: it's about to be blurred into mush and stretched
    // full-screen, so detail beyond this is wasted decode/blur work.
    final provider = ResizeImage(NetworkImage(url, headers: headers), width: 240);
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

    final ui.Image source;
    try {
      source = await completer.future;
    } catch (_) {
      return null;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp);
    canvas.drawImage(source, Offset.zero, paint);
    final picture = recorder.endRecording();

    final ui.Image blurredImage;
    try {
      blurredImage = await picture.toImage(source.width, source.height);
    } finally {
      picture.dispose();
    }
    final byteData = await blurredImage.toByteData(format: ui.ImageByteFormat.png);
    blurredImage.dispose();
    if (byteData == null) return null;

    final result = MemoryImage(byteData.buffer.asUint8List());
    _cache[url] = result;
    return result;
  }
}
