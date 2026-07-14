import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store/settings_store.dart';
import '../../store/state_store.dart';
import '../../theme/koti_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/album_color.dart';
import '../../widgets/entity_watcher.dart';
import '../../widgets/glass_tab_strip.dart';
import 'music_assistant_api.dart';
import 'music_browse_tab.dart';
import 'music_now_playing_tab.dart';
import 'music_queue_tab.dart';
import 'music_search_tab.dart';

/// The Music tab's content: pick a speaker/group at the top, then Now
/// Playing / Search / Browse / Queue underneath. Styled after HOMEii Flow's
/// Music Assistant dashboard (github.com/r11a/homeii-music-flow) — most
/// visibly its "ambient" background, a soft gradient tinted toward the
/// current track's album art color (see [AlbumColorExtractor]; a one-off
/// average-color sample, not a live blur — CLAUDE.md bans BackdropFilter).
/// Lives inside [AppShell]'s own swipe-navigation Stack (to the left of
/// Home) rather than owning a Scaffold/AppBar of its own — so it paints its
/// own full-bleed background and leaves clearance for the shell's floating
/// top nav instead. Works against any `media_player` entity — MA-specific
/// actions (search, browse, queue, play_media) go through the
/// `music_assistant.*` HA services, so it needs Music Assistant installed,
/// but doesn't care how each player got there (native or this tablet's own
/// Koti speaker, if set up as one).
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

  Color? _ambientColor;
  String? _ambientForUrl;

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

  void _selectPlayer(String id) {
    setState(() {
      _selectedPlayer = id;
      // Clear the stale tint immediately rather than let the previous
      // player's color linger until the new one's art (if any) resolves.
      _ambientColor = null;
      _ambientForUrl = null;
    });
  }

  Future<void> _updateAmbientColor(String? pictureUrl, String? token) async {
    if (pictureUrl == _ambientForUrl) return;
    _ambientForUrl = pictureUrl;
    if (pictureUrl == null) {
      if (mounted) setState(() => _ambientColor = null);
      return;
    }
    final color = await AlbumColorExtractor.extract(
      pictureUrl,
      headers: {'Authorization': 'Bearer ${token ?? ''}'},
    );
    // Guard against a stale response landing after the track changed again.
    if (mounted && _ambientForUrl == pictureUrl) {
      setState(() => _ambientColor = color);
    }
  }

  Gradient _backgroundGradient(KotiTokens tokens) {
    final tint = _ambientColor;
    if (tint == null) {
      return LinearGradient(colors: [tokens.dialogBackground, tokens.dialogBackground]);
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.7],
      colors: [Color.lerp(tokens.dialogBackground, tint, 0.55)!, tokens.dialogBackground],
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;
    final tokens = KotiTheme.of(context);
    final settings = context.watch<SettingsStore>();
    final selected = _selectedPlayer;

    // Watching the selected player here (rather than only inside
    // MusicNowPlayingTab) is what lets the ambient tint follow the track
    // even while Search/Browse/Queue are the visible tab.
    final pictureWatcher = selected == null
        ? null
        : EntityWatcher(
            entityIds: [selected],
            builder: (context, states) {
              final picture = states[selected]?.attr<String>('entity_picture', '');
              final pictureUrl = (picture != null && picture.isNotEmpty)
                  ? (picture.startsWith('http') ? picture : '${settings.activeUrl}$picture')
                  : null;
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _updateAmbientColor(pictureUrl, settings.accessToken));
              return const SizedBox.shrink();
            },
          );

    return Container(
      decoration: BoxDecoration(gradient: _backgroundGradient(tokens)),
      child: Stack(
        children: [
          if (pictureWatcher != null) pictureWatcher,
          SafeArea(
            bottom: false,
            // Clears the shell's floating hamburger/nav-pill/clock row,
            // which floats on top of this content rather than reserving
            // space for it.
            child: Padding(
              padding: EdgeInsets.only(top: tokens.navHeight),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _PlayerStrip(selected: _selectedPlayer, onSelect: _selectPlayer),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GlassTabStrip(
                      controller: _tabController,
                      labels: const ['Now Playing', 'Search', 'Browse', 'Queue'],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: selected == null
                        ? const _EmptyState()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              MusicNowPlayingTab(entityId: selected, api: api),
                              MusicSearchTab(entityId: selected, api: api),
                              MusicBrowseTab(entityId: selected, api: api),
                              MusicQueueTab(entityId: selected, api: api),
                            ],
                          ),
                  ),
                ],
              ),
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

/// Horizontal strip of every `media_player` entity as a compact card (name,
/// what's playing, and its own live volume slider) — modeled on HOMEii
/// Flow's "Players" grid, adapted to a scrollable row since this sits
/// inline above the tabs rather than owning a dedicated full-screen panel.
class _PlayerStrip extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _PlayerStrip({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    final store = Provider.of<StateStore>(context, listen: false);
    final players = store.all.keys.where((id) => id.startsWith('media_player.')).toList()
      ..sort();

    if (players.isEmpty) {
      return SizedBox(
        height: 44,
        child: Center(
          child: Text('No media players found',
              style: TextStyle(color: tokens.textSecondary)),
        ),
      );
    }

    return SizedBox(
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: players.length,
        itemBuilder: (context, i) {
          final id = players[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _PlayerCard(
              entityId: id,
              selected: id == selected,
              onTap: () => onSelect(id),
            ),
          );
        },
      ),
    );
  }
}

class _PlayerCard extends StatefulWidget {
  final String entityId;
  final bool selected;
  final VoidCallback onTap;

  const _PlayerCard({required this.entityId, required this.selected, required this.onTap});

  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  double? _dragVolume;

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    final store = Provider.of<StateStore>(context, listen: false);

    return EntityWatcher(
      entityIds: [widget.entityId],
      builder: (context, states) {
        final entity = states[widget.entityId];
        final name = entity?.attr<String>('friendly_name', widget.entityId) ?? widget.entityId;
        final state = entity?.state ?? 'unavailable';
        final playing = state == 'playing' || state == 'buffering';
        final title = entity?.attr<String>('media_title', '');
        final subtitle = playing && (title?.isNotEmpty ?? false) ? title! : _stateLabel(state);
        final volume = entity?.attrDouble('volume_level');

        final card = Container(
          width: 200,
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: widget.selected ? tokens.borderGradient : null,
            color: widget.selected ? null : Colors.transparent,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              color: widget.selected
                  ? tokens.entityBackgroundActive.withValues(alpha: 0.18)
                  : tokens.iconCircleBackground,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(playing ? Icons.graphic_eq : Icons.speaker_outlined,
                        size: 16,
                        color: playing ? tokens.activeColor : tokens.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: tokens.entityName,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.entityState, fontSize: 11),
                ),
                if (volume != null)
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: tokens.activeColor,
                      inactiveTrackColor: tokens.iconCircleBackground,
                      thumbColor: tokens.activeColor,
                    ),
                    child: Slider(
                      value: (_dragVolume ?? volume).clamp(0.0, 1.0),
                      onChanged: (v) => setState(() => _dragVolume = v),
                      onChangeEnd: (v) {
                        store.callService('media_player', 'volume_set',
                            entityId: widget.entityId, data: {'volume_level': v});
                        setState(() => _dragVolume = null);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );

        return GestureDetector(onTap: widget.onTap, child: card);
      },
    );
  }

  String _stateLabel(String state) => switch (state) {
        'off' => 'Off',
        'idle' => 'Idle',
        'paused' => 'Paused',
        'standby' => 'Standby',
        'unavailable' => 'Unavailable',
        _ => state.isEmpty ? '' : state[0].toUpperCase() + state.substring(1),
      };
}
