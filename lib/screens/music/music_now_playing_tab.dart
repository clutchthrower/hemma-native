import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../store/settings_store.dart';
import '../../store/state_store.dart';
import '../../theme/koti_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/device_mode.dart';
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
    final store = Provider.of<StateStore>(context, listen: false);
    final settings = Provider.of<SettingsStore>(context, listen: false);
    // Landscape wall-tablet/desktop: art beside the track info, like HOMEii
    // Flow's desktop layout. Portrait/narrow: stacked, art on top.
    final sideBySide = !isPortrait(context) && deviceModeFor(context) != DeviceMode.mobile;

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

        final art = _AlbumArt(
          pictureUrl: pictureUrl,
          size: sideBySide ? 260 : 220,
          accessToken: settings.accessToken,
        );

        final titleBlock = _TitleBlock(
          title: (title?.isNotEmpty ?? false) ? title! : _stateLabel(state),
          subtitle: (artist?.isNotEmpty ?? false)
              ? [artist, if (album?.isNotEmpty ?? false) album].join(' — ')
              : null,
          centered: !sideBySide,
        );

        final iconRow = _ActionIconRow(
          off: off,
          supportsGrouping: supportsGrouping,
          onPower: () => call(off ? 'turn_on' : 'turn_off'),
          onGroup: supportsGrouping ? () => _showGroupSheet(context, store) : null,
          centered: !sideBySide,
        );

        final progressBlock = _ProgressBlock(
          progress: progress,
          elapsed: elapsed,
          duration: duration,
        );

        final transport = _TransportRow(
          playing: playing,
          shuffleOn: shuffleOn,
          supportsShuffle: supportsShuffle,
          repeat: repeat,
          onShuffle: () => call('shuffle_set', {'shuffle': !shuffleOn}),
          onPrevious: () => call('media_previous_track'),
          onPlayPause: () => call('media_play_pause'),
          onNext: () => call('media_next_track'),
          onRepeat: repeat == null
              ? null
              : () => call('repeat_set', {
                    'repeat': switch (repeat) {
                      'off' => 'all',
                      'all' => 'one',
                      _ => 'off',
                    }
                  }),
        );

        final volumeRow = volume == null
            ? null
            : _VolumeRow(
                volume: _dragVolume ?? volume,
                onChanged: (v) => setState(() => _dragVolume = v),
                onChangeEnd: (v) {
                  call('volume_set', {'volume_level': v});
                  setState(() => _dragVolume = null);
                },
              );

        if (sideBySide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    art,
                    const SizedBox(width: 28),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          titleBlock,
                          const SizedBox(height: 10),
                          iconRow,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              progressBlock,
              const SizedBox(height: 18),
              transport,
              if (volumeRow != null) ...[const SizedBox(height: 18), volumeRow],
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: art),
            const SizedBox(height: 20),
            titleBlock,
            const SizedBox(height: 10),
            iconRow,
            const SizedBox(height: 16),
            progressBlock,
            const SizedBox(height: 14),
            transport,
            if (volumeRow != null) ...[const SizedBox(height: 14), volumeRow],
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

  String _stateLabel(String state) => switch (state) {
        'off' => 'Off',
        'idle' => 'Idle',
        'paused' => 'Paused',
        'standby' => 'Standby',
        'unavailable' => 'Unavailable',
        _ => state.isEmpty ? '' : state[0].toUpperCase() + state.substring(1),
      };
}

/// Big rounded album-art tile — the hero of a HOMEii Flow-style now-playing
/// view. A soft shadow (not a blur filter, just a static drop-shadow) lifts
/// it off the ambient-tinted background behind it.
class _AlbumArt extends StatelessWidget {
  final String? pictureUrl;
  final double size;
  final String? accessToken;

  const _AlbumArt({required this.pictureUrl, required this.size, required this.accessToken});

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: pictureUrl != null
            ? Image.network(
                pictureUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                headers: {'Authorization': 'Bearer ${accessToken ?? ''}'},
                errorBuilder: (_, __, ___) => _fallback(tokens, size),
              )
            : _fallback(tokens, size),
      ),
    );
  }

  Widget _fallback(KotiTokens tokens, double size) => Container(
        width: size,
        height: size,
        color: tokens.iconCircleBackground,
        child: Icon(Icons.music_note, color: tokens.textSecondary, size: size * 0.3),
      );
}

class _TitleBlock extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool centered;

  const _TitleBlock({required this.title, required this.subtitle, required this.centered});

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: centered ? 20 : 28,
              height: 1.15),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textSecondary, fontSize: 15),
          ),
        ],
      ],
    );
  }
}

/// Small circular icon buttons under the title — HOMEii Flow's
/// favorite/playlist/share row, scoped to the actions this app actually
/// supports (power, group) rather than inventing unsupported ones.
class _ActionIconRow extends StatelessWidget {
  final bool off;
  final bool supportsGrouping;
  final VoidCallback onPower;
  final VoidCallback? onGroup;
  final bool centered;

  const _ActionIconRow({
    required this.off,
    required this.supportsGrouping,
    required this.onPower,
    required this.onGroup,
    required this.centered,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        _RoundIconButton(
          icon: Icons.power_settings_new,
          tooltip: off ? 'Turn on' : 'Turn off',
          active: !off,
          onTap: onPower,
        ),
        if (supportsGrouping) ...[
          const SizedBox(width: 10),
          _RoundIconButton(
            icon: Icons.speaker_group,
            tooltip: 'Group',
            active: false,
            onTap: onGroup,
          ),
        ],
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  static const _size = 36.0;

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback? onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? tokens.activeColor.withValues(alpha: 0.18)
            : tokens.iconCircleBackground,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(icon,
                size: _size * 0.5,
                color: active ? tokens.activeColor : tokens.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  final double? progress;
  final double? elapsed;
  final double? duration;

  const _ProgressBlock({required this.progress, required this.elapsed, required this.duration});

  @override
  Widget build(BuildContext context) {
    if (progress == null) return const SizedBox.shrink();
    final tokens = KotiTheme.of(context);
    return Column(
      children: [
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
      ],
    );
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) return '--:--';
    final d = Duration(seconds: seconds.round());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

/// The five-button transport row — every button gets the same circular
/// pill background (not just play/pause), matching HOMEii Flow's look.
class _TransportRow extends StatelessWidget {
  final bool playing;
  final bool shuffleOn;
  final bool supportsShuffle;
  final String? repeat;
  final VoidCallback onShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback? onRepeat;

  const _TransportRow({
    required this.playing,
    required this.shuffleOn,
    required this.supportsShuffle,
    required this.repeat,
    required this.onShuffle,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (supportsShuffle) ...[
          _RoundIconButton(
            icon: Icons.shuffle,
            tooltip: 'Shuffle',
            active: shuffleOn,
            onTap: onShuffle,
          ),
          const SizedBox(width: 10),
        ],
        _RoundIconButton(
            icon: Icons.skip_previous, tooltip: 'Previous', active: false, onTap: onPrevious),
        const SizedBox(width: 10),
        Material(
          color: tokens.activeColor,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPlayPause,
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(playing ? Icons.pause : Icons.play_arrow,
                  size: 30, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _RoundIconButton(icon: Icons.skip_next, tooltip: 'Next', active: false, onTap: onNext),
        if (repeat != null) ...[
          const SizedBox(width: 10),
          _RoundIconButton(
            icon: repeat == 'one' ? Icons.repeat_one : Icons.repeat,
            tooltip: 'Repeat',
            active: repeat != 'off',
            onTap: onRepeat,
          ),
        ],
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _VolumeRow({required this.volume, required this.onChanged, required this.onChangeEnd});

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    return Row(
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
              value: volume.clamp(0.0, 1.0),
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${(volume.clamp(0.0, 1.0) * 100).round()}%',
            textAlign: TextAlign.end,
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
