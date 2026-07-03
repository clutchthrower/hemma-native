// Dev-only sanity check: runs RoomAutoProvisioner against the HA instance
// in the local .env and prints what rooms it would create. Run from the
// project root with:  dart run tool/provision_check.dart
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:hemma_native/api/ha_registry.dart';

Future<void> main() async {
  final env = <String, String>{};
  for (final line in File('.env').readAsLinesSync()) {
    final i = line.indexOf('=');
    if (i > 0 && !line.trimLeft().startsWith('#')) {
      env[line.substring(0, i).trim()] = line.substring(i + 1).trim();
    }
  }
  final url = env['HA_URL'];
  final token = env['HA_ACCESS_TOKEN'];
  if (url == null || token == null) {
    stderr.writeln('Missing HA_URL / HA_ACCESS_TOKEN in .env');
    exit(1);
  }

  print('Provisioning against $url ...');
  final result = await RoomAutoProvisioner(baseUrl: url, accessToken: token).provision();
  print('adminAccess: ${result.adminAccess}');
  print('weatherEntityId: ${result.weatherEntityId}');
  print('rooms: ${result.rooms.length}');
  for (final r in result.rooms) {
    print('  - ${r.name} (${r.id}): '
        '${r.lightEntities.length} lights, ${r.mediaPlayers.length} media, '
        'climate=${r.climateEntity}, temp=${r.temperatureSensor}, '
        'humidity=${r.humiditySensor}, motion=${r.motionSensor}, '
        '${r.cards.length} cards');
  }
  exit(0);
}
