import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:koti/api/ha_rest_client.dart';
import 'package:koti/api/ha_websocket_client.dart';
import 'package:koti/cards/light_card.dart';
import 'package:koti/models/entity_state.dart';
import 'package:koti/store/state_store.dart';
import 'package:koti/theme/koti_theme.dart';
import 'package:koti/theme/tokens.dart';

EntityState _e(String id, String state, [Map<String, dynamic>? attrs]) =>
    EntityState(
      entityId: id,
      state: state,
      attributes: attrs ?? const {},
      lastChanged: DateTime.now(),
      lastUpdated: DateTime.now(),
    );

void main() {
  group('LightCard color/kelvin popup', () {
    late StateStore store;
    final calls = <String>[];

    Widget harness(EntityState light) {
      SharedPreferences.setMockInitialValues({});
      store = StateStore(
        ws: HaWebSocketClient(baseUrl: 'http://localhost:1', token: 't'),
        rest: HaRestClient(baseUrl: 'http://localhost:1', token: 't'),
      );
      store.debugServiceInterceptor = (domain, service, data, entityId) =>
          calls.add('$domain.$service $entityId ${data ?? ''}'.trim());
      store.debugSetStates([light]);
      calls.clear();

      return ChangeNotifierProvider<StateStore>.value(
        value: store,
        child: KotiTheme(
          tokens: KotiTokens(
            brightness: Brightness.dark,
            accentColor: KotiTokens.defaultAccent,
            cardTransparency: 1.0,
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  height: 160,
                  child: LightCard(entityId: light.entityId),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a plain on/off light just toggles, no popup', (tester) async {
      await tester.pumpWidget(harness(
        _e('light.hallway', 'off', {
          'friendly_name': 'Hallway',
          'supported_color_modes': ['onoff'],
        }),
      ));
      await tester.pump();

      await tester.tap(find.text('Hallway'));
      await tester.pump(const Duration(seconds: 1));

      expect(calls, ['light.turn_on light.hallway {transition: 1}']);
      expect(find.text('Color'), findsNothing);
    });

    testWidgets('an RGB light opens the popup defaulted to Brightness, with Color available',
        (tester) async {
      await tester.pumpWidget(harness(
        _e('light.lamp', 'on', {
          'friendly_name': 'Lamp',
          'supported_color_modes': ['rgb'],
          'hs_color': [200, 50],
          'brightness': 200,
        }),
      ));
      await tester.pump();

      await tester.tap(find.text('Lamp'));
      await tester.pump(const Duration(seconds: 1));

      // No toggle call should have fired — tapping a color-capable light
      // opens the popup instead of toggling it directly.
      expect(calls, isEmpty);
      expect(find.text('Brightness'), findsOneWidget);
      expect(find.text('Color'), findsOneWidget);
      expect(find.text('Temperature'), findsNothing);

      // Only one mode's bar is shown until another mode button is tapped.
      await tester.tap(find.text('Color'));
      await tester.pump();
      expect(find.text('Brightness'), findsOneWidget); // still a tab
      expect(find.text('Color'), findsOneWidget);
    });

    testWidgets('a tunable-white light shows a Temperature tab and Kelvin readout',
        (tester) async {
      await tester.pumpWidget(harness(
        _e('light.desk', 'on', {
          'friendly_name': 'Desk',
          'supported_color_modes': ['color_temp'],
          'color_temp_kelvin': 3000,
          'min_color_temp_kelvin': 2000,
          'max_color_temp_kelvin': 6500,
          'brightness': 180,
        }),
      ));
      await tester.pump();

      await tester.tap(find.text('Desk'));
      await tester.pump(const Duration(seconds: 1));

      expect(calls, isEmpty);
      expect(find.text('Color'), findsNothing);
      expect(find.text('Temperature'), findsOneWidget);

      await tester.tap(find.text('Temperature'));
      await tester.pump();
      expect(find.text('3000K'), findsOneWidget);
    });
  });
}
