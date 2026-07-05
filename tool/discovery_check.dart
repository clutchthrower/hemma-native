// Dev-only sanity check: runs the app's mDNS discovery on this machine and
// prints what onboarding would show/use. Run from the project root with:
//   dart run tool/discovery_check.dart
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:koti/api/ha_discovery.dart';

Future<void> main() async {
  print('Scanning for Home Assistant via mDNS…');
  final results = await HaDiscoveryService().scan();
  if (results.isEmpty) {
    print('Nothing found (mDNS may be blocked on this host).');
  }
  for (final r in results) {
    print('name:        ${r.name}');
    print('resolved:    ${r.host}:${r.port}');
    print('internalUrl: ${r.internalUrl}');
    print('externalUrl: ${r.externalUrl}');
    print('=> local url used: ${r.url}');
  }
  exit(0);
}
