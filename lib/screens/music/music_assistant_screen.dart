import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store/settings_store.dart';
import '../../store/state_store.dart';
import '../../theme/koti_theme.dart';
import '../../widgets/entity_watcher.dart';
import 'music_assistant_api.dart';
import 'music_browse_tab.dart';
import 'music_now_playing_tab.dart';
import 'music_queue_tab.dart';
import 'music_search_tab.dart';

/// Full-page Music Assistant control screen (Settings → Features → Music
/// Assistant): pick a speaker/group at the top, then Now Playing / Search /
/// Browse / Queue underneath. Works against any `media_player` entity —
/// MA-specific actions (search, browse, queue, play_media) go through the
/// `music_assistant.*` HA services, so it needs Music Assistant installed,
/// but doesn't care how each player got there (native or the Fully Kiosk
/// player provider, if this tablet is set up as a speaker too).
class MusicAssistantScreen extends StatefulWidget {
  const MusicAssistantScreen({super.key});

  @override
  State<MusicAssistantScreen> createState() => _MusicAssistantScreenState();
}

class _MusicAssistantScreenState extends State<MusicAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this);
  // Created once (not per build) so its config_entry_id cache actually
  // sticks instead of being rediscovered on every rebuild.
  late final MusicAssistantApi _api =
      MusicAssistantApi(Provider.of<StateStore>(context, listen: false));
  String? _selectedPlayer;

  @override
  void initState() {
    super.initState();
    // Defaults to this tablet's own speaker entity, if the Speaker feature
    // has been set up and the user confirmed which entity it became.
    final settings = Provider.of<SettingsStore>(context, listen: false);
    final selfEntity = settings.selfSpeakerEntityId;
    if (selfEntity != null && selfEntity.isNotEmpty) {
      _selectedPlayer = selfEntity;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Now Playing'),
            Tab(text: 'Search'),
            Tab(text: 'Browse'),
            Tab(text: 'Queue'),
          ],
        ),
      ),
      body: Column(
        children: [
          _PlayerSelector(
            selected: _selectedPlayer,
            onSelect: (id) => setState(() => _selectedPlayer = id),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedPlayer == null
                ? const _EmptyState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      MusicNowPlayingTab(
                          entityId: _selectedPlayer!, api: api),
                      MusicSearchTab(entityId: _selectedPlayer!, api: api),
                      MusicBrowseTab(entityId: _selectedPlayer!, api: api),
                      MusicQueueTab(entityId: _selectedPlayer!, api: api),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return Center(
      child: Text('Pick a speaker above to get started',
          style: TextStyle(color: tokens.textSecondary)),
    );
  }
}

/// Horizontal chip strip of every `media_player` entity — MA-backed or
/// not; MA-specific tabs simply won't do much for a non-MA player, but
/// picking one for the standard playback controls still works.
class _PlayerSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _PlayerSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    final store = Provider.of<StateStore>(context, listen: false);
    final players = store.all.keys.where((id) => id.startsWith('media_player.')).toList()
      ..sort();

    return EntityWatcher(
      entityIds: players,
      builder: (context, states) {
        return SizedBox(
          height: 56,
          child: players.isEmpty
              ? Center(
                  child: Text('No media players found',
                      style: TextStyle(color: tokens.textSecondary)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: players.length,
                  itemBuilder: (context, i) {
                    final id = players[i];
                    final entity = states[id];
                    final name = entity?.attr<String>('friendly_name', id) ?? id;
                    final playing =
                        entity?.state == 'playing' || entity?.state == 'buffering';
                    final isSelected = id == selected;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: isSelected,
                        avatar: playing
                            ? Icon(Icons.graphic_eq,
                                size: 18,
                                color: isSelected
                                    ? null
                                    : tokens.activeColor)
                            : null,
                        onSelected: (_) => onSelect(id),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
