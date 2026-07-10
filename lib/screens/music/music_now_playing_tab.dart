import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store/settings_store.dart';
import '../../store/state_store.dart';
import '../../theme/koti_theme.dart';
import '../../widgets/entity_watcher.dart';
import 'music_assistant_api.dart';

class MusicNowPlayingTab extends StatefulWidget {
  final String entityId;
  final MusicAssistantApi api;

  const MusicNowPlayingTab({super.key, required this.entityId, required this.api});

  @override
  State<MusicNowPlayingTab> createState() => _MusicNowPlayingTabState();
}

class _MusicNowPlayingTabState extends State<MusicNowPlayingTab> {
  double? _dragVolume;
  Timer? _positionTicker;

  @override
  void initState() {
    super.initState();
    // Ticks the elapsed-time label between state updates so the progress
    // bar doesn't sit frozen between MA's periodic position reports.
    _positionTicker =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _positionTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    final store = Provider.of<StateStore>(context, listen: false);
    final settings = Provider.of<SettingsStore>(context, listen: false);

    void call(String service, [Map<String, dynamic>? data]) => store
        .callService('media_player', service, entityId: widget.entityId, data: data);

    return EntityWatcher(
      entityIds: [widget.entityId],
      builder: (context, states) {
        final entity = states[widget.entityId];
        final state = entity?.state ?? 'off';
        final playing = state == 'playing' || state == 'buffering';
        final off = state == 'off' || state == 'unavailable' || state == 'standby';
        final title = entity?.attr<String>('media_title', '');
        final artist = entity?.attr<String>('media_artist', '');
        final album = entity?.attr<String>('media_album_name', '');
        final volume = entity?.attrDouble('volume_level');
        final shuffle = entity?.attributes['shuffle'] as bool?;
        final repeat = entity?.attr<String>('repeat', 'off');
        final picture = entity?.attr<String>('entity_picture', '');
        final pictureUrl = (picture != null && picture.isNotEmpty)
            ? (picture.startsWith('http') ? picture : '${settings.activeUrl}$picture')
            : null;

        final position = entity?.attrDouble('media_position');
        final duration = entity?.attrDouble('media_duration');
        final updatedAt = entity?.attributes['media_position_updated_at'] as String?;
        double? elapsed = position;
        if (playing && position != null && updatedAt != null) {
          final updated = DateTime.tryParse(updatedAt);
          if (updated != null) {
            elapsed = position + DateTime.now().difference(updated).inSeconds;
          }
        }
        final progress = (elapsed != null && duration != null && duration > 0)
            ? (elapsed / duration).clamp(0.0, 1.0)
            : null;

        final supported = entity?.attributes['supported_features'] as int?;
        final shuffleOn = shuffle ?? false;
        final supportsShuffle = shuffle != null;
        final supportsGrouping = supported != null && (supported & 524288) != 0;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: pictureUrl != null
                    ? Image.network(
                        pictureUrl,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                        headers: {'Authorization': 'Bearer ${settings.accessToken ?? ''}'},
                        errorBuilder: (_, __, ___) => _artFallback(tokens),
                      )
                    : _artFallback(tokens),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              (title?.isNotEmpty ?? false) ? title! : _stateLabel(state),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: tokens.textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
            ),
            if (artist?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                [artist, if (album?.isNotEmpty ?? false) album].join(' — '),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.textSecondary, fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            if (progress != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: tokens.iconCircleBackground,
                  color: tokens.activeColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(elapsed),
                      style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                  Text(_formatDuration(duration),
                      style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (supportsShuffle)
                  IconButton(
                    icon: Icon(Icons.shuffle,
                        color: shuffleOn ? tokens.activeColor : tokens.textSecondary),
                    onPressed: () => call('shuffle_set', {'shuffle': !shuffleOn}),
                  ),
                IconButton(
                  iconSize: 32,
                  icon: Icon(Icons.skip_previous, color: tokens.textPrimary),
                  onPressed: () => call('media_previous_track'),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  iconSize: 40,
                  style: IconButton.styleFrom(
                    backgroundColor: tokens.activeColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  onPressed: () => call('media_play_pause'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  iconSize: 32,
                  icon: Icon(Icons.skip_next, color: tokens.textPrimary),
                  onPressed: () => call('media_next_track'),
                ),
                if (repeat != null)
                  IconButton(
                    icon: Icon(
                      repeat == 'one' ? Icons.repeat_one : Icons.repeat,
                      color: repeat != 'off' ? tokens.activeColor : tokens.textSecondary,
                    ),
                    onPressed: () => call('repeat_set', {
                      'repeat': switch (repeat) {
                        'off' => 'all',
                        'all' => 'one',
                        _ => 'off',
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (volume != null)
              Row(
                children: [
                  Icon(Icons.volume_down, color: tokens.textSecondary, size: 20),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: tokens.activeColor,
                        inactiveTrackColor: tokens.iconCircleBackground,
                        thumbColor: tokens.activeColor,
                        overlayColor: tokens.activeColor.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: (_dragVolume ?? volume).clamp(0.0, 1.0),
                        onChanged: (v) => setState(() => _dragVolume = v),
                        onChangeEnd: (v) {
                          call('volume_set', {'volume_level': v});
                          setState(() => _dragVolume = null);
                        },
                      ),
                    ),
                  ),
                  Icon(Icons.volume_up, color: tokens.textSecondary, size: 20),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: off ? tokens.textSecondary : tokens.activeColor,
                  ),
                  icon: Icon(Icons.power_settings_new,
                      color: off ? tokens.textSecondary : tokens.activeColor),
                  label: Text(off ? 'Turn on' : 'Turn off'),
                  onPressed: () => call(off ? 'turn_on' : 'turn_off'),
                ),
                if (supportsGrouping)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: tokens.textSecondary),
                    icon: Icon(Icons.speaker_group, color: tokens.textSecondary),
                    label: const Text('Group'),
                    onPressed: () => _showGroupSheet(context, store),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showGroupSheet(BuildContext context, StateStore store) {
    final tokens = KotiTheme.of(context);
    final others = store.all.values
        .where((e) => e.domain == 'media_player' && e.entityId != widget.entityId)
        .toList()
      ..sort((a, b) => a.attr<String>('friendly_name', a.entityId)
          .compareTo(b.attr<String>('friendly_name', b.entityId)));
    final current = store.get(widget.entityId);
    final currentGroup =
        (current?.attributes['group_members'] as List?)?.cast<String>() ?? const [];
    final selected = {...currentGroup}..remove(widget.entityId);

    return showModalBottomSheet(
      context: context,
      backgroundColor: tokens.dialogBackground,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Group with',
                    style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const SizedBox(height: 8),
                for (final other in others)
                  CheckboxListTile(
                    title: Text(other.attr<String>('friendly_name', other.entityId),
                        style: TextStyle(color: tokens.textPrimary)),
                    value: selected.contains(other.entityId),
                    onChanged: (v) => setSheetState(() {
                      if (v ?? false) {
                        selected.add(other.entityId);
                      } else {
                        selected.remove(other.entityId);
                      }
                    }),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        widget.api.unjoin(widget.entityId);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Ungroup'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        widget.api.join(widget.entityId, selected.toList());
                        Navigator.of(context).pop();
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _artFallback(dynamic tokens) => Container(
        width: 220,
        height: 220,
        color: tokens.iconCircleBackground,
        child: Icon(Icons.music_note, color: tokens.textSecondary, size: 64),
      );

  String _stateLabel(String state) => switch (state) {
        'off' => 'Off',
        'idle' => 'Idle',
        'paused' => 'Paused',
        'standby' => 'Standby',
        'unavailable' => 'Unavailable',
        _ => state.isEmpty ? '' : state[0].toUpperCase() + state.substring(1),
      };

  String _formatDuration(double? seconds) {
    if (seconds == null) return '--:--';
    final d = Duration(seconds: seconds.round());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}
