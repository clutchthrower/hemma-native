import 'package:flutter/material.dart';

import '../../theme/koti_theme.dart';
import 'music_assistant_api.dart';
import 'music_item_tile.dart';

const _mediaTypes = ['artist', 'album', 'playlist', 'radio', 'track'];
const _mediaTypeLabels = {
  'artist': 'Artists',
  'album': 'Albums',
  'playlist': 'Playlists',
  'radio': 'Radio',
  'track': 'Tracks',
};

class MusicBrowseTab extends StatefulWidget {
  final String entityId;
  final MusicAssistantApi api;

  const MusicBrowseTab({super.key, required this.entityId, required this.api});

  @override
  State<MusicBrowseTab> createState() => _MusicBrowseTabState();
}

class _MusicBrowseTabState extends State<MusicBrowseTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _typeController =
      TabController(length: _mediaTypes.length, vsync: this)
        ..addListener(() {
          if (!_typeController.indexIsChanging) _load();
        });

  final Map<String, List<MusicItem>> _cache = {};
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _typeController.dispose();
    super.dispose();
  }

  String get _currentType => _mediaTypes[_typeController.index];

  Future<void> _load() async {
    if (_cache.containsKey(_currentType)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.getLibrary(mediaType: _currentType);
      if (!mounted) return;
      setState(() {
        _cache[_currentType] = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tokens = KotiTheme.of(context);
    final items = _cache[_currentType];

    return Column(
      children: [
        TabBar(
          controller: _typeController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final t in _mediaTypes) Tab(text: _mediaTypeLabels[t])],
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Couldn\'t load: $_error',
                style: const TextStyle(color: Colors.redAccent)),
          ),
        Expanded(
          child: items == null || items.isEmpty
              ? Center(
                  child: Text(
                    _loading ? 'Loading…' : 'Nothing here',
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => MusicItemTile(
                    item: items[i],
                    onTap: () => widget.api.playItem(widget.entityId, items[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
