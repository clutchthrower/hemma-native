// Smoke test for the Connection settings screen. KotiApp's full cold-launch
// bootstrap (SharedPreferences + flutter_secure_storage plugin channels) has
// no platform implementation under `flutter test`, so this exercises the
// screen directly rather than booting the whole app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:koti/screens/settings/connection_settings_page.dart';
import 'package:koti/store/settings_store.dart';

void main() {
  testWidgets('Connection settings screen renders its fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsStore>(
        create: (_) => SettingsStore(),
        child: const MaterialApp(home: ConnectionSettingsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Local URL'), findsOneWidget);
    expect(find.text('Test Connection'), findsOneWidget);
  });
}
