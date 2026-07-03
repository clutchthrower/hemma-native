import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

/// One Home Assistant instance found on the LAN via mDNS/zeroconf.
///
/// HA's TXT record can carry `internal_url`, `external_url`, and the
/// legacy `base_url` — the latter two usually point at the public reverse
/// proxy. The local connection must NEVER use those: [url] is the
/// advertised internal URL if any, otherwise the LAN IP we just resolved.
/// The external one is kept separately so it can pre-fill the optional
/// Remote URL setting.
class DiscoveredInstance {
  final String name;
  final String host;
  final int port;
  final String? internalUrl;
  final String? externalUrl;
  final bool requiresApiPassword;

  DiscoveredInstance({
    required this.name,
    required this.host,
    required this.port,
    this.internalUrl,
    this.externalUrl,
    this.requiresApiPassword = false,
  });

  String get url {
    // Trust the advertised internal URL only when it's IP-based —
    // `.local` hostnames don't resolve through Android's plain DNS.
    final iu = internalUrl;
    if (iu != null) {
      final iuHost = Uri.tryParse(iu)?.host ?? '';
      if (InternetAddress.tryParse(iuHost) != null) return iu;
    }
    return 'http://$host:$port';
  }
}

/// Scans the local network for `_home-assistant._tcp.local` services.
/// Per CLAUDE.md this replaces manual IP entry during onboarding — no
/// address is ever fetched over the internet, only broadcast on the LAN.
class HaDiscoveryService {
  static const _serviceType = '_home-assistant._tcp.local';

  Future<List<DiscoveredInstance>> scan({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final client = MDnsClient();
    final found = <String, DiscoveredInstance>{};

    try {
      await client.start();

      await for (final ptr in client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(_serviceType))
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final srv in client
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
            .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
          String? internalUrl;
          String? externalUrl;
          var requiresPassword = false;
          await for (final txt in client
              .lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))
              .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
            for (final line in txt.text.split('\n')) {
              if (line.startsWith('internal_url=')) {
                final v = line.substring('internal_url='.length);
                if (v.startsWith('http')) internalUrl = v;
              } else if (line.startsWith('external_url=')) {
                final v = line.substring('external_url='.length);
                if (v.startsWith('http')) externalUrl = v;
              } else if (line.startsWith('base_url=')) {
                // Legacy field; in practice the public/proxy address.
                final v = line.substring('base_url='.length);
                if (v.startsWith('http')) externalUrl ??= v;
              } else if (line.startsWith('requires_api_password=')) {
                requiresPassword = line.endsWith('true');
              }
            }
          }

          String? address;
          await for (final ip in client
              .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))
              .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
            address = ip.address.address;
            break;
          }
          address ??= srv.target;

          final instance = DiscoveredInstance(
            name: ptr.domainName.replaceAll('.$_serviceType', ''),
            host: address,
            port: srv.port,
            internalUrl: internalUrl,
            externalUrl: externalUrl,
            requiresApiPassword: requiresPassword,
          );
          found[instance.url] = instance;
        }
      }
    } finally {
      client.stop();
    }

    return found.values.toList();
  }
}
