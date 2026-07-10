import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

/// Local HTTP server implementing the audio-relevant subset of Fully Kiosk
/// Browser's REST API (https://www.fully-kiosk.com/en/#rest) — the exact
/// wire protocol Music Assistant's built-in "Fully Kiosk" player provider
/// speaks (see music-assistant/server's fully_kiosk provider, and the
/// underlying python-fullykiosk client it uses). Exposing this API is
/// enough for MA to treat this tablet as a real player: no custom Home
/// Assistant integration required, just point MA's Fully Kiosk provider
/// at this device's IP, [port], and [password].
///
/// Music Assistant polls `deviceInfo` every ~10s and renames the player
/// entity to whatever `deviceName` it reports — see [deviceName].
class KioskAudioServer {
  static const defaultPort = 2323;

  /// Home Assistant "stream 3" is Android's STREAM_MUSIC — the only one
  /// Fully Kiosk (and therefore MA) cares about for playback volume.
  static const _musicStream = '3';

  // Mutable so a password/name change (Settings) can apply without
  // tearing down and rebinding the server.
  String password;
  String deviceName;
  final int port;

  KioskAudioServer({
    required this.password,
    required this.deviceName,
    this.port = defaultPort,
  });

  HttpServer? _server;
  final AudioPlayer _player = AudioPlayer();
  String? _currentUrl;
  int _volumePercent = 100;

  bool get running => _server != null;

  Future<void> start() async {
    if (running) return;
    await _player.setVolume(_volumePercent / 100);
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen(
      (request) => _handle(request).catchError((_) {
        // A single malformed/aborted request shouldn't take the server down.
      }),
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
    await _player.stop();
    _currentUrl = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final params = request.uri.queryParameters;
    if (params['password'] != password) {
      await _respondError(request, 'Invalid password');
      return;
    }
    switch (params['cmd']) {
      case 'deviceInfo':
        await _respondDeviceInfo(request);
      case 'playSound':
        await _handlePlaySound(request, params);
      case 'stopSound':
        await _handleStopSound(request);
      case 'setAudioVolume':
        await _handleSetVolume(request, params);
      default:
        await _respondError(request, 'Unknown command: ${params['cmd']}');
    }
  }

  Future<void> _respondDeviceInfo(HttpRequest request) async {
    final playing = _player.playing && _currentUrl != null;
    await _respondJson(request, {
      'deviceName': deviceName,
      'deviceModel': 'Koti Tablet',
      'deviceManufacturer': 'Koti',
      'audioVolumes': [
        {_musicStream: _volumePercent}
      ],
      if (playing) 'soundUrlPlaying': _currentUrl,
    });
  }

  Future<void> _handlePlaySound(HttpRequest request, Map<String, String> params) async {
    final url = params['url'];
    if (url == null || url.isEmpty) {
      await _respondError(request, 'Missing url');
      return;
    }
    try {
      await _player.setUrl(url);
      _currentUrl = url;
      // Deliberately not awaited: play() only completes once playback
      // finishes (or is paused), which would hang this HTTP response for
      // the whole track.
      unawaited(_player.play());
      await _respondJson(request, {'status': 'OK'});
    } catch (e) {
      _currentUrl = null;
      await _respondError(request, 'Playback failed: $e');
    }
  }

  Future<void> _handleStopSound(HttpRequest request) async {
    await _player.stop();
    _currentUrl = null;
    await _respondJson(request, {'status': 'OK'});
  }

  Future<void> _handleSetVolume(HttpRequest request, Map<String, String> params) async {
    final level = int.tryParse(params['level'] ?? '');
    if (level == null) {
      await _respondError(request, 'Missing level');
      return;
    }
    _volumePercent = level.clamp(0, 100);
    await _player.setVolume(_volumePercent / 100);
    await _respondJson(request, {'status': 'OK'});
  }

  Future<void> _respondJson(HttpRequest request, Map<String, dynamic> body) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  /// Fully Kiosk's own convention for a failed command: HTTP 200 with a
  /// `{"status": "Error", ...}` body (the python client checks the body,
  /// not the status code).
  Future<void> _respondError(HttpRequest request, String message) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'status': 'Error', 'statustext': message}));
    await request.response.close();
  }
}
