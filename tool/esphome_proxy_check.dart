// Dev-only end-to-end check of the ESPHome Bluetooth-proxy server: starts
// the server on this machine, adds it to the real HA instance from .env
// via the config-flow REST API, watches the handshake, streams a few fake
// BLE advertisements, then removes the test entry again.
// Run from the project root:  dart run tool/esphome_proxy_check.dart
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:hemma_native/api/esphome_server.dart';

Future<void> main() async {
  final env = <String, String>{};
  for (final line in File('.env').readAsLinesSync()) {
    final i = line.indexOf('=');
    if (i > 0) env[line.substring(0, i).trim()] = line.substring(i + 1).trim();
  }
  final base = env['HA_URL']!;
  final headers = {
    'Authorization': 'Bearer ${env['HA_ACCESS_TOKEN']}',
    'Content-Type': 'application/json',
  };

  final server = EsphomeServer(
    name: 'hemma-proxy-test',
    friendlyName: 'Hemma Proxy Test',
    macAddress: '02:11:22:33:44:55',
    bluetoothMacAddress: '02:11:22:33:44:56',
    log: (m) => print('[server] $m'),
  );
  await server.start();
  print('server listening on ${EsphomeServer.port}');

  // This machine's LAN IP (as seen from HA).
  final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  final ip = ifaces
      .expand((i) => i.addresses)
      .firstWhere((a) => a.address.startsWith('10.0.0.'))
      .address;
  print('local ip: $ip');

  // Feed fake advertisements (iBeacon-style payload) every 300ms.
  final adTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
    if (!server.hasSubscribers) return;
    server.sendAdvertisements([
      BleAdvertisement(
        address: 0xC0FFEE123456,
        rssi: -61,
        addressType: 1,
        data: Uint8List.fromList([
          0x02, 0x01, 0x06, // flags
          0x1a, 0xff, 0x4c, 0x00, 0x02, 0x15, // Apple iBeacon header
          ...List.generate(16, (i) => i), // proximity uuid
          0x00, 0x01, 0x00, 0x02, 0xc5, // major/minor/tx
        ]),
      ),
    ]);
  });

  print('starting HA config flow for domain esphome…');
  final startResp = await http.post(
    Uri.parse('$base/api/config/config_entries/flow'),
    headers: headers,
    body: jsonEncode({'handler': 'esphome', 'show_advanced_options': false}),
  );
  print('flow start: ${startResp.statusCode}');
  var flow = jsonDecode(startResp.body) as Map<String, dynamic>;
  print('step: ${flow['step_id']} (${flow['type']})');

  final stepResp = await http.post(
    Uri.parse('$base/api/config/config_entries/flow/${flow['flow_id']}'),
    headers: headers,
    body: jsonEncode({'host': ip, 'port': EsphomeServer.port}),
  );
  print('user step: ${stepResp.statusCode}');
  flow = jsonDecode(stepResp.body) as Map<String, dynamic>;
  print('result type: ${flow['type']}  step: ${flow['step_id']}');
  if (flow['type'] == 'form') {
    print('form errors: ${flow['errors']}');
    print('description_placeholders: ${flow['description_placeholders']}');
  }

  String? entryId;
  if (flow['type'] == 'create_entry') {
    entryId = (flow['result'] as Map?)?['entry_id'] as String?;
    print('ENTRY CREATED: $entryId  title=${flow['title']}');
    // Give HA a moment to connect + subscribe, then check state.
    await Future.delayed(const Duration(seconds: 6));
    final entries = jsonDecode((await http.get(
            Uri.parse('$base/api/config/config_entries/entry'),
            headers: headers))
        .body) as List;
    for (final e in entries.cast<Map<String, dynamic>>()) {
      if (e['entry_id'] == entryId) {
        print('entry state after 6s: ${e['state']} (${e['title']})');
      }
    }
  }

  // Clean up the test entry so the real tablet can register later.
  if (entryId != null) {
    final del = await http.delete(
        Uri.parse('$base/api/config/config_entries/entry/$entryId'),
        headers: headers);
    print('cleanup delete: ${del.statusCode}');
  }

  adTimer.cancel();
  await server.stop();
  exit(0);
}
