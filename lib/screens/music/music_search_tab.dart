import 'package:flutter/material.dart';

import '../../theme/koti_theme.dart';
import 'music_assistant_api.dart';
import 'music_item_tile.dart';

class MusicSearchTab extends StatefulWidget {
  final String entityId;
  final MusicAssistantApi api;

  const MusicSearchTab({super.key, required this.entityId, required this.api});

  @override
  State<MusicSearchTab> createState() => _MusicSearchTabState();
}

class _MusicSearchTabState extends State<MusicSearchTab>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  List<MusicItem>? _results;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.api.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search tracks, artists, albums…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _search,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Search failed: $_error',
                style: const TextStyle(color: Colors.redAccent)),
          ),
        Expanded(
          child: _results == null
              ? Center(
                  child: Text('Search Music Assistant\'s library',
                      style: TextStyle(color: tokens.textSecondary)))
              : _results!.isEmpty
                  ? Center(
                      child: Text('No results',
                          style: TextStyle(color: tokens.textSecondary)))
                  : ListView.builder(
                      itemCount: _results!.length,
                      itemBuilder: (context, i) => MusicItemTile(
                        item: _results![i],
                        onTap: () => widget.api.playItem(widget.entityId, _results![i]),
                      ),
                    ),
        ),
      ],
    );
  }
}
