import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// GitHub repository ("owner/name") whose Releases feed drives the in-app
/// update flow. Leave empty to disable update checks entirely (e.g. while
/// developing, or for forks that sideload builds themselves).
///
/// To publish an update: tag a GitHub release like `v1.1.0` and attach the
/// built APK as a release asset. Tablets compare it against their own
/// version on launch and show a blocking update screen when it's newer.
// Renamed from 'clutchthrower/hemma-native' — GitHub redirects the old
// path, so tablets running pre-rename builds still find updates.
const String kUpdateRepo = 'clutchthrower/koti';

class AppUpdateInfo {
  final String version;
  final String apkUrl;
  final String notes;

  const AppUpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
  });
}

/// Compares dotted version strings numerically ("1.10.0" > "1.9.2").
/// Returns >0 if [a] is newer than [b]. Non-numeric segments compare as 0.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first
      .split('.')
      .map((s) => int.tryParse(s) ?? 0)
      .toList();
  final pa = parse(a);
  final pb = parse(b);
  for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}

class AppUpdateChecker {
  final http.Client client;
  final String repo;

  AppUpdateChecker({http.Client? client, this.repo = kUpdateRepo})
      : client = client ?? http.Client();

  /// Returns update info when the repo's latest release is newer than the
  /// running app and ships an APK asset; null otherwise (including any
  /// network error — a wall tablet must never block on a failed check).
  Future<AppUpdateInfo?> check({String? currentVersion}) async {
    if (repo.isEmpty) return null;
    try {
      final current =
          currentVersion ?? (await PackageInfo.fromPlatform()).version;
      final resp = await client.get(
        Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;

      final release = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = release['tag_name'] as String? ?? '';
      if (tag.isEmpty || compareVersions(tag, current) <= 0) return null;

      final assets = (release['assets'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      final apk = assets.where((a) =>
          (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'));
      if (apk.isEmpty) return null;

      return AppUpdateInfo(
        version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
        apkUrl: apk.first['browser_download_url'] as String,
        notes: release['body'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Downloads [apkUrl] to a temp file and hands it to Android's package
/// installer (a `FileProvider` on the native side). [onProgress] is called
/// with 0..1 while the download runs, then `null` once the installer intent
/// has been launched — that's a hand-off, not confirmation the install
/// itself finished, matching how Android's own installer UI takes over
/// from here. Throws on failure (bad status code, stream error); callers
/// are expected to show their own error state.
Future<void> downloadAndInstallApk(
  String apkUrl, {
  required void Function(double? progress) onProgress,
}) async {
  onProgress(0);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/koti-update.apk');

  final request = http.Request('GET', Uri.parse(apkUrl));
  final response = await http.Client().send(request);
  if (response.statusCode != 200) {
    throw Exception('download failed (HTTP ${response.statusCode})');
  }
  final total = response.contentLength ?? 0;
  var received = 0;
  final sink = file.openWrite();
  await response.stream.listen((chunk) {
    received += chunk.length;
    sink.add(chunk);
    if (total > 0) onProgress(received / total);
  }).asFuture<void>();
  await sink.close();

  await const MethodChannel('koti/native')
      .invokeMethod('installApk', {'path': file.path});
  onProgress(null);
}
