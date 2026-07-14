import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store/settings_store.dart';
import '../../theme/koti_theme.dart';
import '../../theme/tokens.dart';
import 'music_assistant_api.dart';

/// Square-art tile for a track/album/artist/playlist/radio result — used by
/// the Browse tab's library grid, HOMEii Flow-style (art-forward tiles
/// rather than [MusicItemTile]'s list rows, which Search/Queue keep since
/// those are more scan-a-list contexts than browse-by-cover-art ones).
class MusicGridTile extends StatelessWidget {
  final MusicItem item;
  final VoidCallback onTap;

  const MusicGridTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    final settings = Provider.of<SettingsStore>(context, listen: false);
    final imageUrl = item.imageUrl;
    final resolvedUrl = imageUrl == null
        ? null
        : (imageUrl.startsWith('http') ? imageUrl : '${settings.activeUrl}$imageUrl');
    final round = item.mediaType == 'artist' ? 9999.0 : 14.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(round),
              child: resolvedUrl != null
                  ? Image.network(
                      resolvedUrl,
                      fit: BoxFit.cover,
                      headers: {'Authorization': 'Bearer ${settings.accessToken ?? ''}'},
                      errorBuilder: (_, __, ___) => _fallback(tokens, round),
                    )
                  : _fallback(tokens, round),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: tokens.entityName, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (item.subtitle != null)
            Text(
              item.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.entityState, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _fallback(KotiTokens tokens, double round) => Container(
        decoration: BoxDecoration(
          color: tokens.iconCircleBackground,
          borderRadius: BorderRadius.circular(round),
        ),
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
          size: 28,
        ),
      );
}
