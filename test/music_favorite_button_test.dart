import 'package:flutter_test/flutter_test.dart';

import 'package:koti/api/ha_rest_client.dart';
import 'package:koti/api/ha_websocket_client.dart';
import 'package:koti/screens/music/music_assistant_api.dart';
import 'package:koti/store/state_store.dart';

StateStore _store() => StateStore(
      ws: HaWebSocketClient(baseUrl: 'http://localhost:1', token: 't'),
      rest: HaRestClient(baseUrl: 'http://localhost:1', token: 't'),
    );

void main() {
  group('MusicAssistantApi.resolveFavoriteButton', () {
    test('finds the favorite button sharing a device with the player', () async {
      final store = _store();
      store.debugEntityRegistry = [
        {
          'entity_id': 'media_player.living_room',
          'device_id': 'dev-1',
          'platform': 'music_assistant',
        },
        {
          'entity_id': 'button.living_room_favorite_now_playing',
          'device_id': 'dev-1',
          'platform': 'music_assistant',
          'unique_id': 'living_room_favorite_now_playing',
        },
        // Noise: a button on a different device, and a non-button entity
        // on the same device — neither should match.
        {
          'entity_id': 'button.kitchen_favorite_now_playing',
          'device_id': 'dev-2',
          'platform': 'music_assistant',
          'unique_id': 'kitchen_favorite_now_playing',
        },
        {
          'entity_id': 'sensor.living_room_signal',
          'device_id': 'dev-1',
          'platform': 'music_assistant',
        },
      ];
      final api = MusicAssistantApi(store);

      final buttonId = await api.resolveFavoriteButton('media_player.living_room');

      expect(buttonId, 'button.living_room_favorite_now_playing');
    });

    test('returns null when the player has no matching favorite button', () async {
      final store = _store();
      store.debugEntityRegistry = [
        {
          'entity_id': 'media_player.living_room',
          'device_id': 'dev-1',
          'platform': 'music_assistant',
        },
      ];
      final api = MusicAssistantApi(store);

      expect(await api.resolveFavoriteButton('media_player.living_room'), isNull);
    });

    test('returns null and does not throw when the registry is unavailable', () async {
      final store = _store(); // no debugEntityRegistry, not connected either
      final api = MusicAssistantApi(store);

      expect(await api.resolveFavoriteButton('media_player.living_room'), isNull);
    });

    test('caches the result, including null, per player', () async {
      final store = _store();
      var calls = 0;
      store.debugEntityRegistry = [
        {
          'entity_id': 'media_player.living_room',
          'device_id': 'dev-1',
          'platform': 'music_assistant',
        },
        {
          'entity_id': 'button.living_room_favorite_now_playing',
          'device_id': 'dev-1',
          'platform': 'music_assistant',
          'unique_id': 'living_room_favorite_now_playing',
        },
      ];
      final api = MusicAssistantApi(store);

      final first = await api.resolveFavoriteButton('media_player.living_room');
      // Swap the registry out from under it — a cached call shouldn't see
      // this, proving the second call didn't re-fetch.
      store.debugEntityRegistry = [];
      calls++;
      final second = await api.resolveFavoriteButton('media_player.living_room');

      expect(first, 'button.living_room_favorite_now_playing');
      expect(second, first);
      expect(calls, 1);
    });

    test('pressFavoriteButton calls button.press on the resolved entity', () async {
      final store = _store();
      final calls = <String>[];
      store.debugServiceInterceptor = (domain, service, data, entityId) =>
          calls.add('$domain.$service $entityId');
      final api = MusicAssistantApi(store);

      await api.pressFavoriteButton('button.living_room_favorite_now_playing');

      expect(calls, ['button.press button.living_room_favorite_now_playing']);
    });
  });
}
