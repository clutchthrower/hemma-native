import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum HaConnectionStatus { disconnected, connecting, connected, reconnecting }

/// Persistent WebSocket connection to Home Assistant's `/api/websocket`
/// endpoint. Implements the standard auth handshake, silent auto-reconnect
/// with exponential backoff, and a queue for outgoing service calls made
/// while disconnected so nothing is lost on a dropped Wi-Fi signal.
class HaWebSocketClient {
  final String baseUrl;
  final String token;
  final Duration reconnectInterval;
  final Duration requestTimeout;

  HaWebSocketClient({
    required this.baseUrl,
    required this.token,
    this.reconnectInterval = const Duration(seconds: 5),
    this.requestTimeout = const Duration(seconds: 15),
  });

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  int _messageId = 1;
  bool _authenticated = false;
  bool _closedByUser = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  final _statusController = StreamController<HaConnectionStatus>.broadcast();
  Stream<HaConnectionStatus> get statusStream => _statusController.stream;
  HaConnectionStatus _status = HaConnectionStatus.disconnected;
  HaConnectionStatus get status => _status;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final List<Map<String, dynamic>> _outgoingQueue = [];
  final List<Map<String, dynamic>> _resubscribeQueue = [];

  String get _wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.authority}/api/websocket';
  }

  void _setStatus(HaConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  Future<void> connect() async {
    _closedByUser = false;
    _setStatus(_reconnectAttempt == 0
        ? HaConnectionStatus.connecting
        : HaConnectionStatus.reconnecting);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      await _channel!.ready;
      _sub = _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'auth_required':
        _send({'type': 'auth', 'access_token': token});
        break;
      case 'auth_ok':
        _authenticated = true;
        _reconnectAttempt = 0;
        _setStatus(HaConnectionStatus.connected);
        _flushQueue();
        break;
      case 'auth_invalid':
        _authenticated = false;
        _setStatus(HaConnectionStatus.disconnected);
        _sub?.cancel();
        break;
      case 'event':
        _eventController.add(msg);
        break;
      case 'result':
        final id = msg['id'] as int?;
        final completer = _pending.remove(id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(msg);
        }
        break;
      case 'pong':
        break;
    }
  }

  void _onDisconnected() {
    _authenticated = false;
    if (_closedByUser) {
      _setStatus(HaConnectionStatus.disconnected);
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _setStatus(HaConnectionStatus.reconnecting);
    _reconnectAttempt++;
    final backoff = Duration(
      milliseconds: (reconnectInterval.inMilliseconds *
              (1 << (_reconnectAttempt.clamp(0, 5))))
          .clamp(reconnectInterval.inMilliseconds, 60000),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(backoff, connect);
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  int _nextId() => _messageId++;

  /// Sends a command and awaits its `result` response. Queues the command
  /// if the socket isn't authenticated yet, replaying it once reconnected.
  Future<Map<String, dynamic>> sendCommand(Map<String, dynamic> payload) {
    final id = _nextId();
    final message = {...payload, 'id': id};
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    if (_authenticated) {
      _send(message);
    } else {
      _outgoingQueue.add(message);
    }

    return completer.future.timeout(
      requestTimeout,
      onTimeout: () => {'success': false, 'error': 'timeout'},
    );
  }

  /// Subscriptions must be re-sent after every reconnect since HA has no
  /// memory of a previous connection's subscriptions.
  Future<void> subscribeEvents(String eventType) async {
    final payload = {'type': 'subscribe_events', 'event_type': eventType};
    _resubscribeQueue.add(payload);
    await sendCommand(payload);
  }

  Future<Map<String, dynamic>> getStates() =>
      sendCommand({'type': 'get_states'});

  Future<void> callService(
    String domain,
    String service, {
    Map<String, dynamic>? serviceData,
    Map<String, dynamic>? target,
  }) async {
    await sendCommand({
      'type': 'call_service',
      'domain': domain,
      'service': service,
      if (serviceData != null) 'service_data': serviceData,
      if (target != null) 'target': target,
    });
  }

  void _flushQueue() {
    for (final payload in _resubscribeQueue) {
      final id = _nextId();
      _send({...payload, 'id': id});
    }
    final queued = List<Map<String, dynamic>>.from(_outgoingQueue);
    _outgoingQueue.clear();
    for (final message in queued) {
      _send(message);
    }
  }

  void close() {
    _closedByUser = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _setStatus(HaConnectionStatus.disconnected);
  }

  void dispose() {
    close();
    _statusController.close();
    _eventController.close();
  }
}
