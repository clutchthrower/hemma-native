// Dev-only sanity check: mirrors HomeView._homeCards' filters against the
// real HA instance in .env and prints which whole-home cards would appear.
// Run from the project root with:  dart run tool/home_cards_check.dart
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:koti/models/entity_state.dart';

Future<void> main() async {
  final env = <String, String>{};
  for (final line in File('.env').readAsLinesSync()) {
    final i = line.indexOf('=');
    if (i > 0 && !line.trimLeft().startsWith('#')) {
      env[line.substring(0, i).trim()] = line.substring(i + 1).trim();
    }
  }
  final uri = Uri.parse(env['HA_URL']!);
  final channel =
      WebSocketChannel.connect(Uri.parse('ws://${uri.authority}/api/websocket'));
  await channel.ready;

  final states = Completer<List<EntityState>>();
  channel.stream.listen((raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    if (msg['type'] == 'auth_required') {
      channel.sink.add(jsonEncode(
          {'type': 'auth', 'access_token': env['HA_ACCESS_TOKEN']}));
    } else if (msg['type'] == 'auth_ok') {
      channel.sink.add(jsonEncode({'type': 'get_states', 'id': 1}));
    } else if (msg['type'] == 'result') {
      states.complete(((msg['result'] as List?) ?? [])
          .map((e) => EntityState.fromJson((e as Map).cast<String, dynamic>()))
          .toList());
    }
  });

  final all = await states.future.timeout(const Duration(seconds: 15));
  print('total entities: ${all.length}');
  print('climate: ${all.where((e) => e.domain == 'climate').map((e) => e.entityId).toList()}');
  print('lock: ${all.where((e) => e.domain == 'lock').map((e) => e.entityId).toList()}');
  print('doorbell binary_sensors: ${all.where((e) => e.domain == 'binary_sensor' && e.entityId.contains('doorbell')).map((e) => e.entityId).toList()}');
  print('vacuum: ${all.where((e) => e.domain == 'vacuum').map((e) => e.entityId).toList()}');
  print('cover: ${all.where((e) => e.domain == 'cover').map((e) => e.entityId).toList()}');
  print('fan: ${all.where((e) => e.domain == 'fan').map((e) => e.entityId).toList()}');
  print('updates on: ${all.where((e) => e.domain == 'update' && e.state == 'on').map((e) => e.entityId).toList()}');
  print('battery sensors: ${all.where((e) => e.domain == 'sensor' && e.attr<String>('device_class', '') == 'battery').map((e) => e.entityId).take(6).toList()}');
  exit(0);
}
