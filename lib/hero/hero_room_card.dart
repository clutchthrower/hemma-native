import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../badges/climate_group_badge.dart';
import '../badges/light_group_badge.dart';
import '../badges/media_group_badge.dart';
import '../badges/presence_group_badge.dart';
import '../edit/badge_edit_sheet.dart';
import '../edit/edit_mode.dart';
import '../models/room_config.dart';
import '../popups/climate_popup.dart';
import '../store/settings_store.dart';
import '../theme/koti_theme.dart';
import '../utils/device_mode.dart';
import '../widgets/entity_watcher.dart';
import '../widgets/media_pill.dart';
import '../widgets/weather_widget.dart';

double _clamp(double min, double preferred, double max) =>
    preferred.clamp(min, max);

/// Replicates `hemma_room.yaml` + `hemma_shared.yaml`: full-screen hero
/// background with the room name + badge rows positioned near the top
/// (`padding-top: var(--hero-top)`, left-aligned within the page gutter),
/// leaving the bottom of the screen for the entity grid + navbar.
class HeroRoomCard extends StatefulWidget {
  final RoomConfig room;

  /// When set, long-pressing the title or a badge enters edit mode, where
  /// badges can be added/removed/reconfigured and the room renamed.
  final ValueChanged<RoomConfig>? onRoomChanged;

  const HeroRoomCard({super.key, required this.room, this.onRoomChanged});

  @override
  State<HeroRoomCard> createState() => _HeroRoomCardState();
}

class _HeroRoomCardState extends State<HeroRoomCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _parallaxController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _parallaxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = Tween<double>(begin: 1.08, end: 1.0).animate(
      CurvedAnimation(parent: _parallaxController, curve: const Cubic(0.25, 0.46, 0.45, 0.94)),
    );
    _parallaxController.forward();
  }

  @override
  void dispose() {
    _parallaxController.dispose();
    super.dispose();
  }

  double _heroTop(DeviceMode mode, bool portrait, Size size) {
    // Landscape: title block sits roughly a third of the way down,
    // center-left (see reference screenshots). Portrait: near the top.
    if (mode == DeviceMode.desktop) return _clamp(240, size.height * 0.30, 380);
    if (mode == DeviceMode.tablet) {
      return portrait
          ? _clamp(90, size.height * 0.10, 150)
          : _clamp(150, size.height * 0.30, 330);
    }
    return _clamp(60, size.height * 0.10, 110);
  }

  double _gutter(DeviceMode mode, Size size) {
    if (mode == DeviceMode.desktop) return size.width * 0.08;
    if (mode == DeviceMode.tablet) return size.width * 0.04;
    return 11;
  }

  double _nameFontSize(Size size) => _clamp(48, size.width * 0.06 + 12, 100);

  Future<void> _rename() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameRoomDialog(initialName: widget.room.name),
    );
    if (name != null && name.trim().isNotEmpty) {
      widget.onRoomChanged?.call(widget.room.copyWith(name: name.trim()));
    }
  }

  Future<void> _editBadge(BadgeKind kind) async {
    final updated =
        await showBadgeEditSheet(context, kind: kind, room: widget.room);
    if (updated != null) widget.onRoomChanged?.call(updated);
  }

  /// The badge widget for [kind], or null if the room doesn't show it.
  /// [forEditing] keeps normally-hidden badges (idle media) visible so the
  /// edit chrome has something to attach to.
  Widget? _badgeFor(BadgeKind kind, {bool forEditing = false}) {
    final room = widget.room;
    if (!roomHasBadge(room, kind)) return null;
    switch (kind) {
      case BadgeKind.climate:
        // Builder gives the popup a badge-sized context to anchor to.
        return Builder(
          builder: (badgeContext) => GestureDetector(
            onTap: () => showClimatePopup(
              badgeContext,
              roomName: room.name,
              tempSensorEntityId: room.temperatureSensor,
              humiditySensorEntityId: room.humiditySensor,
              aqiSensorEntityId: room.aqiSensor,
            ),
            child: AbsorbPointer(
              child: ClimateGroupBadge(
                tempSensorEntityId: room.temperatureSensor,
                humiditySensorEntityId: room.humiditySensor,
              ),
            ),
          ),
        );
      case BadgeKind.lights:
        return LightGroupBadge(lightEntityIds: [
          if (room.lightGroupEntity != null) room.lightGroupEntity!,
          ...room.lightEntities,
        ]);
      case BadgeKind.people:
        return PresenceGroupBadge(personEntityIds: room.presenceEntities);
      case BadgeKind.media:
        return MediaGroupBadge(
          mediaPlayerEntityIds: room.mediaPlayers,
          showWhenIdle: forEditing,
        );
    }
  }

  /// Edit-mode chrome for one badge slot: existing badges get a ✕ and
  /// tap-to-edit; missing ones show as a dashed "+ Lights" style chip.
  Widget _editableBadge(EditModeController edit, BadgeKind kind) {
    final badge = _badgeFor(kind, forEditing: true);
    if (badge == null) {
      return GestureDetector(
        onTap: () => _editBadge(kind),
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 18, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                badgeKindLabel(kind),
                style: const TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(child: badge),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _editBadge(kind),
          ),
        ),
        Positioned(
          top: -6,
          right: 2,
          child: GestureDetector(
            onTap: () async {
              final cleared = await _clearBadge(kind);
              widget.onRoomChanged?.call(cleared);
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(0, 0, 0, 0.7),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<RoomConfig> _clearBadge(BadgeKind kind) async {
    final room = widget.room;
    return switch (kind) {
      BadgeKind.climate => room.copyWith(
          climateEntity: null, temperatureSensor: null, humiditySensor: null),
      BadgeKind.lights =>
        room.copyWith(lightEntities: const [], lightGroupEntity: null),
      BadgeKind.people => room.copyWith(presenceEntities: const []),
      BadgeKind.media => room.copyWith(mediaPlayers: const []),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KotiTheme.of(context);
    final settings = Provider.of<SettingsStore>(context, listen: false);
    final mode = deviceModeFor(context);
    final portrait = isPortrait(context);
    final themeController = context.watch<ThemeController>();
    final parallaxEnabled = themeController.parallaxEnabled;
    final size = MediaQuery.sizeOf(context);
    final edit = context.watch<EditModeController>();
    final canEdit = widget.onRoomChanged != null;
    final editing = edit.editing && canEdit;
    const tintColor = Color.fromRGBO(55, 55, 55, 0.50);

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(
            scale: parallaxEnabled ? _scale.value : 1.0,
            child: child,
          ),
          child: EntityWatcher(
            entityIds: const ['sun.sun'],
            builder: (context, states) {
              final sun = states['sun.sun'];
              final belowHorizon = sun?.state == 'below_horizon';
              // Always the blurred room photo — portrait included — so
              // both orientations share the original's look. Absolute
              // paths are user-picked photos stored in app documents.
              final bg = widget.room.backgroundFor(night: belowHorizon);
              return bg.startsWith('/')
                  ? Image.file(
                      File(bg),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black),
                    )
                  : Image.asset(
                      bg,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black),
                    );
            },
          ),
        ),
        Container(color: tintColor),
        Positioned(
          top: _heroTop(mode, portrait, size),
          left: _gutter(mode, size),
          right: _gutter(mode, size),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Landscape: small "72° ☀" line above the title, like the
              // desktop/tablet originals. Portrait: title left, weather
              // top-right on the same line, like the mobile original. The
              // clock lives in the app shell's top-right corner, not here.
              if (!portrait && settings.weatherEntityId != null)
                GestureDetector(
                  onLongPress: canEdit && !editing ? edit.enter : null,
                  onTap: editing ? () => showWeatherEntityPicker(context) : null,
                  child: WeatherWidget(
                    weatherEntityId: settings.weatherEntityId!,
                    iconSize: 26,
                    style: const TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontWeight: FontWeight.w600,
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPress: canEdit && !editing ? edit.enter : null,
                      onTap: editing ? _rename : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.room.name,
                              style: TextStyle(
                                fontFamily: 'Hanken Grotesk',
                                fontWeight: FontWeight.w700,
                                fontSize: _nameFontSize(size),
                                height: 1.15,
                                letterSpacing: -2,
                                color: tokens.textPrimary.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                          if (editing)
                            const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child:
                                  Icon(Icons.edit, size: 26, color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (portrait && settings.weatherEntityId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GestureDetector(
                        onLongPress: canEdit && !editing ? edit.enter : null,
                        onTap: editing ? () => showWeatherEntityPicker(context) : null,
                        child: WeatherWidget(
                          weatherEntityId: settings.weatherEntityId!,
                          iconSize: 24,
                          style: const TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Badge order matches the original: Climate, Lights, People,
              // Media. In edit mode every slot shows — present badges get
              // ✕/tap-to-edit, absent ones a dashed "+" chip.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (final kind in BadgeKind.values)
                      if (editing)
                        _editableBadge(edit, kind)
                      else if (_badgeFor(kind) != null)
                        GestureDetector(
                          onLongPress: canEdit ? edit.enter : null,
                          child: _badgeFor(kind),
                        ),
                  ],
                ),
              ),
              if (!editing && widget.room.mediaPlayers.isNotEmpty) ...[
                const SizedBox(height: 12),
                MediaPill(mediaPlayerEntityIds: widget.room.mediaPlayers),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Owning the controller here (not in `_rename` above, disposed right after
/// the dialog's Future resolves) matters: the dialog is still mid-close
/// animation, not yet unmounted, when that Future completes, so an
/// immediate `controller.dispose()` there rips it out from under a
/// still-live `TextField` and corrupts the element tree — the real cause
/// behind a `_dependents.isEmpty`/`defunct` assertion crash reproduced live
/// on the equivalent Device Name rename dialog.
class _RenameRoomDialog extends StatefulWidget {
  final String initialName;
  const _RenameRoomDialog({required this.initialName});

  @override
  State<_RenameRoomDialog> createState() => _RenameRoomDialogState();
}

class _RenameRoomDialogState extends State<_RenameRoomDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Room Name'),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('Save')),
      ],
    );
  }
}
