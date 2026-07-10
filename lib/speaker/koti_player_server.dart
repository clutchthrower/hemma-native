import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Koti's own local player protocol: a tiny, unauthenticated HTTP API (this
/// device is only reachable on the LAN, matching the same trust boundary
/// this app's Bluetooth proxy already uses) plus an mDNS advertisement
/// (`_koti._tcp`, registered natively — see MainActivity.kt) so the Koti
/// Home Assistant integration auto-discovers this tablet as a player with
/// no manual IP/port/password entry. Volume goes through Android's real
/// STREAM_MUSIC (a platform channel call, not the audio player's own
/// gain) — otherwise HA's volume slider silently multiplies against
/// whatever the device's physical volume happens to be set to.
class KotiPlayerServer {
  static const defaultPort = 8127;
  static const _channel = MethodChannel('koti/native');

  final String id;
  String name;
  final int port;

  KotiPlayerServer({required this.id, required this.name, this.port = defaultPort});

  HttpServer? _server;
  final AudioPlayer _player = AudioPlayer();
  String? _currentUrl;

  bool get running => _server != null;

  Future<void> start() async {
    if (running) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen(
      (request) => _handle(request).catchError((_) {
        // A single malformed/aborted request shouldn't take the server down.
      }),
      onError: (_) {},
      cancelOnError: false,
    );
    try {
      await _channel.invokeMethod('startKotiDiscovery', {
        'name': name,
        'id': id,
        'port': port,
      });
    } catch (_) {
      // Discovery is a convenience, not a hard requirement — the server
      // still works if someone adds it by IP.
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
    await _player.stop();
    _currentUrl = null;
    try {
      await _channel.invokeMethod('stopKotiDiscovery');
    } catch (_) {}
  }

  /// Re-announces under the new name without a full stop/start — used
  /// when the user renames the device in Settings while this is running.
  Future<void> updateName(String newName) async {
    name = newName;
    if (!running) return;
    try {
      await _channel.invokeMethod('startKotiDiscovery', {
        'name': name,
        'id': id,
        'port': port,
      });
    } catch (_) {}
  }

  Future<void> _handle(HttpRequest request) async {
    final params = request.uri.queryParameters;
    switch (params['cmd']) {
      case 'info':
        await _respondInfo(request);
      case 'play':
        await _handlePlay(request, params);
      case 'stop':
        await _handleStop(request);
      case 'volume':
        await _handleVolume(request, params);
      default:
        await _respondError(request, 'Unknown command: ${params['cmd']}');
    }
  }

  Future<void> _respondInfo(HttpRequest request) async {
    int volume = 100;
    try {
      volume = await _channel.invokeMethod<int>('getMusicVolume') ?? 100;
    } catch (_) {}
    await _respondJson(request, {
      'id': id,
      'name': name,
      'playing': _player.playing && _currentUrl != null,
      'volume': volume,
    });
  }

  Future<void> _handlePlay(HttpRequest request, Map<String, String> params) async {
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
      await _respondJson(request, {'ok': true});
    } catch (e) {
      _currentUrl = null;
      await _respondError(request, 'Playback failed: $e');
    }
  }

  Future<void> _handleStop(HttpRequest request) async {
    await _player.stop();
    _currentUrl = null;
    await _respondJson(request, {'ok': true});
  }

  Future<void> _handleVolume(HttpRequest request, Map<String, String> params) async {
    final level = int.tryParse(params['level'] ?? '');
    if (level == null) {
      await _respondError(request, 'Missing level');
      return;
    }
    try {
      await _channel.invokeMethod('setMusicVolume', {'percent': level.clamp(0, 100)});
      await _respondJson(request, {'ok': true});
    } catch (e) {
      await _respondError(request, 'Volume change failed: $e');
    }
  }

  Future<void> _respondJson(HttpRequest request, Map<String, dynamic> body) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> _respondError(HttpRequest request, String message) async {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': message}));
    await request.response.close();
  }
}
