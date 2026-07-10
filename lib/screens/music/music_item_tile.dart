import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store/settings_store.dart';
import '../../theme/koti_theme.dart';
import 'music_assistant_api.dart';

/// One row for a track/album/artist/playlist/radio result — used by the
/// Search, Browse, and Queue tabs so they all look and behave the same.
class MusicItemTile extends StatelessWidget {
  final MusicItem item;
  final VoidCallback onTap;
  final int? index;

  const MusicItemTile({super.key, required this.item, required this.onTap, this.index});

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    final settings = Provider.of<SettingsStore>(context, listen: false);
    final imageUrl = item.imageUrl;
    final resolvedUrl = imageUrl == null
        ? null
        : (imageUrl.startsWith('http') ? imageUrl : '${settings.activeUrl}$imageUrl');

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 44,
          height: 44,
          child: resolvedUrl != null
              ? Image.network(
                  resolvedUrl,
                  fit: BoxFit.cover,
                  headers: {'Authorization': 'Bearer ${settings.accessToken ?? ''}'},
                  errorBuilder: (_, __, ___) => _fallbackIcon(tokens),
                )
              : _fallbackIcon(tokens),
        ),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: item.subtitle != null
          ? Text(item.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: index != null
          ? Text('${index! + 1}', style: TextStyle(color: tokens.textSecondary))
          : Icon(Icons.play_arrow, color: tokens.textSecondary),
      onTap: onTap,
    );
  }

  Widget _fallbackIcon(dynamic tokens) => Container(
        color: tokens.iconCircleBackground,
        alignment: Alignment.center,
        child: Icon(
          switch (item.mediaType) {
            'artist' => Icons.person,
            'album' => Icons.album,
            'playlist' => Icons.queue_music,
            'radio' => Icons.radio,
            _ => Icons.music_note,
          },
          color: tokens.textSecondary,
          size: 20,
        ),
      );
}
