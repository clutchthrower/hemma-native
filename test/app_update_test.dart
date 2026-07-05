import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:koti/api/app_update.dart';

MockClient _github(Map<String, dynamic> release) => MockClient((request) async {
      expect(request.url.path, '/repos/owner/repo/releases/latest');
      return http.Response(jsonEncode(release), 200);
    });

Map<String, dynamic> _release(String tag, {bool withApk = true}) => {
      'tag_name': tag,
      'body': 'notes',
      'assets': [
        if (withApk)
          {
            'name': 'koti-$tag.apk',
            'browser_download_url': 'https://example.com/$tag.apk',
          },
        {
          'name': 'checksums.txt',
          'browser_download_url': 'https://example.com/sums',
        },
      ],
    };

void main() {
  test('compareVersions orders dotted versions numerically', () {
    expect(compareVersions('1.10.0', '1.9.2'), greaterThan(0));
    expect(compareVersions('v2.0.0', '2.0.0'), 0);
    expect(compareVersions('1.0.0+5', '1.0.0'), 0);
    expect(compareVersions('0.9.9', '1.0.0'), lessThan(0));
  });

  test('newer release with APK yields update info', () async {
    final checker =
        AppUpdateChecker(client: _github(_release('v1.1.0')), repo: 'owner/repo');
    final info = await checker.check(currentVersion: '1.0.0');
    expect(info, isNotNull);
    expect(info!.version, '1.1.0');
    expect(info.apkUrl, 'https://example.com/v1.1.0.apk');
  });

  test('same or older release yields null', () async {
    expect(
        await AppUpdateChecker(
                client: _github(_release('v1.0.0')), repo: 'owner/repo')
            .check(currentVersion: '1.0.0'),
        isNull);
    expect(
        await AppUpdateChecker(
                client: _github(_release('v0.9.0')), repo: 'owner/repo')
            .check(currentVersion: '1.0.0'),
        isNull);
  });

  test('release without an APK asset yields null', () async {
    final checker = AppUpdateChecker(
        client: _github(_release('v9.9.9', withApk: false)), repo: 'owner/repo');
    expect(await checker.check(currentVersion: '1.0.0'), isNull);
  });

  test('empty repo (checks disabled) yields null without network', () async {
    final checker = AppUpdateChecker(
        client: MockClient((_) async => throw StateError('no requests')),
        repo: '');
    expect(await checker.check(currentVersion: '1.0.0'), isNull);
  });
}
