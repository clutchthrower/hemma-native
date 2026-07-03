import 'dart:convert';
import 'package:http/http.dart' as http;

/// REST fallback client used when the WebSocket is disconnected, and for
/// one-off calls (history, camera stills, template evaluation) that don't
/// need a persistent connection.
class HaRestClient {
  final String baseUrl;
  final String token;

  HaRestClient({required this.baseUrl, required this.token});

  Uri _uri(String path) => Uri.parse('$baseUrl/api$path');

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> config() async {
    final r = await _get('/config');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> states() async {
    final r = await _get('/states');
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<void> callService(
    String domain,
    String service, {
    Map<String, dynamic>? data,
  }) async {
    await _retrying(() => http.post(
          _uri('/services/$domain/$service'),
          headers: _headers,
          body: jsonEncode(data ?? {}),
        ));
  }

  Future<List<dynamic>> historyPeriod(String startIso, String entityId) async {
    final r = await _get(
        '/history/period/$startIso?filter_entity_id=$entityId&minimal_response');
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<http.Response> _get(String path) => _retrying(
        () => http.get(_uri(path), headers: _headers),
      );

  /// Retries transient 5xx failures with exponential backoff; surfaces
  /// 401/403 immediately since retrying won't help an expired token.
  Future<http.Response> _retrying(
    Future<http.Response> Function() request, {
    int attempt = 0,
  }) async {
    final response = await request();
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw HaAuthException(response.statusCode);
    }
    if (response.statusCode >= 500 && attempt < 3) {
      await Future.delayed(Duration(milliseconds: 300 * (1 << attempt)));
      return _retrying(request, attempt: attempt + 1);
    }
    return response;
  }
}

class HaAuthException implements Exception {
  final int statusCode;
  HaAuthException(this.statusCode);
  @override
  String toString() => 'HaAuthException($statusCode)';
}
