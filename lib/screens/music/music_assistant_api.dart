import '../../store/state_store.dart';

/// Thin wrapper around Music Assistant's Home Assistant integration
/// services (domain `music_assistant`), matched against MA's actual
/// service schemas (home-assistant/core's
/// homeassistant/components/music_assistant/{services.py,schemas.py}) —
/// not guessed. `search`/`get_library` require a `config_entry_id`, which
/// is resolved once (via HA's admin `config_entries/get`) and cached.
class MusicAssistantApi {
  final StateStore store;
  MusicAssistantApi(this.store);

  String? _configEntryId;
  List<Map<String, dynamic>>? _entityRegistryCache;
  final Map<String, String?> _favoriteButtonCache = {};

  Future<String> _requireConfigEntryId() async {
    final cached = _configEntryId;
    if (cached != null) return cached;
    final entries = await store.getConfigEntries(domain: 'music_assistant');
    if (entries.isEmpty) {
      throw StateError('Music Assistant isn\'t set up in Home Assistant '
          '(no config entry found for domain "music_assistant")');
    }
    final id = entries.first['entry_id'] as String?;
    if (id == null) {
      throw StateError('Music Assistant config entry has no entry_id');
    }
    _configEntryId = id;
    return id;
  }

  /// Searches MA's library (and, per MA's default, unresolved/online
  /// sources too). Not player-specific — results are picked, then played
  /// on whichever player the user has selected.
  Future<List<MusicItem>> search(String query, {int limit = 25}) async {
    final configEntryId = await _requireConfigEntryId();
    final response = await store.callServiceForResponse(
      'music_assistant',
      'search',
      data: {
        'config_entry_id': configEntryId,
        'name': query,
        'limit': limit,
      },
    );
    return _parseResultBuckets(response);
  }

  /// Browses the library by media type (artist/album/playlist/radio/
  /// track — singular, matches MA's MediaType enum values).
  Future<List<MusicItem>> getLibrary({
    required String mediaType,
    bool favoritesOnly = false,
    int limit = 50,
  }) async {
    final configEntryId = await _requireConfigEntryId();
    final response = await store.callServiceForResponse(
      'music_assistant',
      'get_library',
      data: {
        'config_entry_id': configEntryId,
        'media_type': mediaType,
        if (favoritesOnly) 'favorite': true,
        'limit': limit,
      },
    );
    final items = response['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((m) => MusicItem.fromJson(m.cast<String, dynamic>(), mediaType))
        .toList();
  }

  /// Queue status for a player. MA's `get_queue` returns metadata (active,
  /// shuffle/repeat, item count) plus only the current and next item —
  /// not a full scrollable track list.
  Future<MusicQueueInfo> getQueue(String entityId) async {
    final response =
        await store.callServiceForResponse('music_assistant', 'get_queue', entityId: entityId);
    return MusicQueueInfo.fromJson(response);
  }

  Future<void> playItem(String entityId, MusicItem item, {String enqueue = 'play'}) {
    return store.callService(
      'music_assistant',
      'play_media',
      entityId: entityId,
      data: {
        'media_id': [item.uri],
        'media_type': item.mediaType,
        'enqueue': enqueue,
      },
    );
  }

  /// Groups [members] under [leaderEntityId] using HA's standard
  /// media_player grouping services (MA players support them).
  Future<void> join(String leaderEntityId, List<String> members) {
    return store.callService(
      'media_player',
      'join',
      entityId: leaderEntityId,
      data: {'group_members': members},
    );
  }

  Future<void> unjoin(String entityId) {
    return store.callService('media_player', 'unjoin', entityId: entityId);
  }

  /// Finds the `button.*` entity MA's HA integration auto-creates per
  /// player specifically to favorite whatever that player is currently
  /// playing (there's no `media_player`-domain service for this — HA's
  /// music_assistant integration only exposes it as a per-device button
  /// entity, confirmed against the actual integration source, not
  /// guessed). Resolved once via the entity registry (which entity_id HA
  /// slugifies it to isn't predictable from the player's own entity_id)
  /// and cached — including a null result, so a player without one (e.g.
  /// a non-admin account can't read the registry, or the button entity
  /// was disabled) isn't re-queried every rebuild.
  Future<String?> resolveFavoriteButton(String playerEntityId) async {
    if (_favoriteButtonCache.containsKey(playerEntityId)) {
      return _favoriteButtonCache[playerEntityId];
    }
    String? result;
    try {
      final registry = _entityRegistryCache ??= await store.getEntityRegistry();
      final playerEntry = registry.firstWhere(
        (e) => e['entity_id'] == playerEntityId,
        orElse: () => const {},
      );
      final deviceId = playerEntry['device_id'] as String?;
      if (deviceId != null) {
        final buttonEntry = registry.firstWhere(
          (e) =>
              e['device_id'] == deviceId &&
              (e['entity_id'] as String?)?.startsWith('button.') == true &&
              e['platform'] == 'music_assistant' &&
              (e['unique_id'] as String?)?.contains('favorite') == true,
          orElse: () => const {},
        );
        result = buttonEntry['entity_id'] as String?;
      }
    } catch (_) {
      // Registry access needs an admin account — leave result null so the
      // heart button just doesn't show, rather than throwing into the UI.
    }
    _favoriteButtonCache[playerEntityId] = result;
    return result;
  }

  Future<void> pressFavoriteButton(String buttonEntityId) {
    return store.callService('button', 'press', entityId: buttonEntityId);
  }

  List<MusicItem> _parseResultBuckets(Map<String, dynamic> response) {
    // search responds with one list per media type:
    // {"tracks": [...], "artists": [...], "albums": [...], "radio": [...], ...}
    final results = <MusicItem>[];
    for (final entry in response.entries) {
      final list = entry.value;
      if (list is! List) continue;
      final mediaType = entry.key.endsWith('s')
          ? entry.key.substring(0, entry.key.length - 1)
          : entry.key;
      results.addAll(list
          .whereType<Map>()
          .map((m) => MusicItem.fromJson(m.cast<String, dynamic>(), mediaType)));
    }
    return results;
  }
}

/// A track/album/artist/playlist/radio station, matching MA's
/// MEDIA_ITEM_SCHEMA (uri/name/image are always present; artists/album
/// are only on tracks and albums).
class MusicItem {
  final String uri;
  final String name;
  final String? subtitle; // artist, or album for a track
  final String? imageUrl;
  final String mediaType;

  const MusicItem({
    required this.uri,
    required this.name,
    required this.mediaType,
    this.subtitle,
    this.imageUrl,
  });

  factory MusicItem.fromJson(Map<String, dynamic> json, String mediaType) {
    final artists = json['artists'];
    final artistName = artists is List && artists.isNotEmpty
        ? (artists.first is Map ? artists.first['name'] as String? : null)
        : null;
    final album = json['album'];
    final albumName = album is Map ? album['name'] as String? : null;

    return MusicItem(
      uri: json['uri'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      subtitle: artistName ?? albumName,
      imageUrl: json['image'] as String?,
      mediaType: json['media_type'] as String? ?? mediaType,
    );
  }
}

/// MA's get_queue response: mostly metadata, plus only the current and
/// next item (not the full upcoming track list — MA's service doesn't
/// expose that).
class MusicQueueInfo {
  final bool active;
  final String name;
  final int itemCount;
  final bool shuffleEnabled;
  final String repeatMode;
  final MusicItem? currentItem;
  final MusicItem? nextItem;

  const MusicQueueInfo({
    required this.active,
    required this.name,
    required this.itemCount,
    required this.shuffleEnabled,
    required this.repeatMode,
    this.currentItem,
    this.nextItem,
  });

  factory MusicQueueInfo.fromJson(Map<String, dynamic> json) {
    MusicItem? parseQueueItem(dynamic raw) {
      if (raw is! Map) return null;
      final mediaItem = raw['media_item'];
      if (mediaItem is Map) {
        return MusicItem.fromJson(mediaItem.cast<String, dynamic>(), 'track');
      }
      // No underlying media item (e.g. a raw stream) — fall back to the
      // queue item's own name.
      final name = raw['name'] as String?;
      if (name == null) return null;
      return MusicItem(uri: '', name: name, mediaType: 'track');
    }

    return MusicQueueInfo(
      active: json['active'] as bool? ?? false,
      name: json['name'] as String? ?? '',
      itemCount: json['items'] as int? ?? 0,
      shuffleEnabled: json['shuffle_enabled'] as bool? ?? false,
      repeatMode: json['repeat_mode'] as String? ?? 'off',
      currentItem: parseQueueItem(json['current_item']),
      nextItem: parseQueueItem(json['next_item']),
    );
  }
}
