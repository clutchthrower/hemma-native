import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Replicates HA's own frontend login flow so this app can turn a
/// username/password into a stored Long-Lived Access Token without a
/// WebView (per CLAUDE.md's no-WebView constraint):
///
/// 1. POST /auth/login_flow           -> flow_id
/// 2. POST /auth/login_flow/{flow_id} -> short-lived authorization code
/// 3. POST /auth/token                -> short-lived access_token
/// 4. WS   auth/long_lived_access_token -> a token this app can store forever
///
/// `client_id`/`redirect_uri` are set to the HA instance's own URL: HA's
/// IndieAuth check only requires fetching the client_id document when the
/// redirect_uri's origin differs from client_id's, so same-origin URLs
/// (exactly what HA's own frontend uses) pass without any extra hosting.
class HaAuthFlow {
  final String baseUrl;
  HaAuthFlow(this.baseUrl);

  String get _clientId => '$baseUrl/';
  String get _redirectUri => '$baseUrl/';

  Future<LoginFlowStep> startLoginFlow() async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login_flow'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_id': _clientId,
        'handler': ['homeassistant', null],
        'redirect_uri': _redirectUri,
      }),
    );
    if (response.statusCode != 200) {
      throw HaAuthFlowException('Could not start login (HTTP ${response.statusCode})');
    }
    return LoginFlowStep.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoginFlowStep> submitCredentials({
    required String flowId,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login_flow/$flowId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_id': _clientId,
        'username': username,
        'password': password,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final errors = body['errors'] as Map<String, dynamic>?;
      throw HaAuthFlowException(
          errors?.values.join(', ') ?? 'Invalid username or password');
    }
    return LoginFlowStep.fromJson(body);
  }

  /// Exchanges the login flow's authorization code for a short-lived
  /// access_token, then immediately upgrades it to a Long-Lived Access
  /// Token via the WebSocket API (the only place HA exposes that call).
  Future<String> completeWithLongLivedToken({
    required String authorizationCode,
    required String clientName,
  }) async {
    final shortLivedToken = await exchangeAuthorizationCode(authorizationCode);
    return createLongLivedToken(shortLivedToken, clientName);
  }

  /// The authorization code is single-use, so this step can't be retried —
  /// callers that need to retry [createLongLivedToken] with a different
  /// `client_name` (e.g. after an "already exists" collision) must reuse the
  /// short-lived token this returns instead of re-exchanging the code.
  Future<String> exchangeAuthorizationCode(String authorizationCode) async {
    final tokenResponse = await http.post(
      Uri.parse('$baseUrl/auth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': authorizationCode,
        'client_id': _clientId,
      },
    );
    if (tokenResponse.statusCode != 200) {
      throw HaAuthFlowException('Could not exchange authorization code for a token');
    }
    final tokenBody = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    return tokenBody['access_token'] as String;
  }

  Future<String> createLongLivedToken(String accessToken, String clientName) =>
      _createLongLivedToken(accessToken, clientName);

  Future<String> _createLongLivedToken(String accessToken, String clientName) async {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final channel = WebSocketChannel.connect(Uri.parse('$scheme://${uri.authority}/api/websocket'));
    await channel.ready;

    final completer = Completer<String>();
    late StreamSubscription sub;
    var authenticated = false;

    sub = channel.stream.listen((raw) {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'auth_required':
          channel.sink.add(jsonEncode({'type': 'auth', 'access_token': accessToken}));
          break;
        case 'auth_ok':
          authenticated = true;
          channel.sink.add(jsonEncode({
            'id': 1,
            'type': 'auth/long_lived_access_token',
            'client_name': clientName,
            'lifespan': 3650,
          }));
          break;
        case 'auth_invalid':
          completer.completeError(HaAuthFlowException('Session token was rejected'));
          break;
        case 'result':
          if (msg['success'] == true) {
            completer.complete(msg['result'] as String);
          } else {
            final error = msg['error'] as Map<String, dynamic>?;
            final message = error?['message'] as String?;
            completer.completeError(HaAuthFlowException(
                message ?? 'Could not create a long-lived token',
                alreadyExists: message?.contains('already exists') ?? false));
          }
          break;
      }
    }, onError: (e) {
      if (!completer.isCompleted) completer.completeError(HaAuthFlowException('$e'));
    });

    try {
      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw HaAuthFlowException(
            authenticated ? 'Timed out creating token' : 'Timed out authenticating'),
      );
      return result;
    } finally {
      await sub.cancel();
      await channel.sink.close();
    }
  }
}

class LoginFlowStep {
  final String flowId;
  final String type; // "form" | "create_entry"
  final String? result; // authorization code, present when type == create_entry

  LoginFlowStep({required this.flowId, required this.type, this.result});

  bool get isComplete => type == 'create_entry';

  factory LoginFlowStep.fromJson(Map<String, dynamic> json) => LoginFlowStep(
        flowId: json['flow_id'] as String,
        type: json['type'] as String,
        result: json['result'] as String?,
      );
}

class HaAuthFlowException implements Exception {
  final String message;
  final bool alreadyExists;
  HaAuthFlowException(this.message, {this.alreadyExists = false});
  @override
  String toString() => message;
}
