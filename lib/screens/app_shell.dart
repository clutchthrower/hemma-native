import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../edit/background_sheet.dart';
import '../edit/edit_mode.dart';
import '../models/room_config.dart';
import '../navigation/top_nav.dart';
import '../popups/scenes_popup.dart';
import '../store/settings_store.dart';
import '../store/state_store.dart';
import '../theme/koti_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/clock_widget.dart';
import 'home_overview_screen.dart';
import 'room_screen.dart';
import 'screensaver_screen.dart';

/// Top-level shell mirroring the original dashboard chrome: hamburger
/// top-left, the Home/rooms/Scenes text-tab nav top-center, clock
/// top-right, with the full-screen [HomeView]/[RoomView] behind it.
/// Also owns the sidebar drawer and the idle-timeout screensaver.
class AppShell extends StatefulWidget {
  final SettingsStore settings;
  const AppShell({super.key, required this.settings});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _editMode = EditModeController();

  /// Selected room id; null means the Home tab.
  String? _roomId;
  Timer? _idleTimer;
  bool _showScreensaver = false;

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _editMode.dispose();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final minutes =
        Provider.of<ThemeController>(context, listen: false).screensaverTimeoutMinutes;
    if (_showScreensaver) setState(() => _showScreensaver = false);
    if (minutes <= 0) return;
    _idleTimer = Timer(Duration(minutes: minutes), () {
      // Never black out mid-edit.
      if (mounted && !_editMode.editing) setState(() => _showScreensaver = true);
    });
  }

  /// Swipe left/right anywhere on the background steps through
  /// Home → room1 → room2 … (scrollable rows like the card strip keep
  /// their own gesture and are unaffected).
  void _onHorizontalSwipe(DragEndDetails details) {
    if (_editMode.editing) return;
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 250) return;
    final rooms = widget.settings.rooms;
    // Position in the sequence: -1 = Home, otherwise the room index.
    var index = _roomId == null ? -1 : rooms.indexWhere((r) => r.id == _roomId);
    index += v < 0 ? 1 : -1; // swipe left = forward
    if (index < -1 || index >= rooms.length) return;
    setState(() => _roomId = index == -1 ? null : rooms[index].id);
  }

  Future<void> _editBackground(RoomConfig? currentRoom) async {
    final settings = widget.settings;
    final room = currentRoom ??
        effectiveHomeConfig(
          rooms: settings.rooms,
          store: Provider.of<StateStore>(context, listen: false),
          saved: settings.homeRoom,
        );
    final updated = await showBackgroundSheet(context, room);
    if (updated == null) return;
    if (currentRoom != null) {
      final rooms = List.of(settings.rooms);
      final i = rooms.indexWhere((r) => r.id == currentRoom.id);
      if (i != -1) {
        rooms[i] = updated;
        await settings.setRooms(rooms);
      }
    } else {
      await settings.setHomeRoom(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.settings.rooms;
    RoomConfig? currentRoom;
    for (final r in rooms) {
      if (r.id == _roomId) currentRoom = r;
    }
    final theme = context.watch<ThemeController>();

    return ChangeNotifierProvider<EditModeController>.value(
      value: _editMode,
      child: Listener(
        onPointerDown: (_) => _resetIdleTimer(),
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(currentRoom: currentRoom),
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: _onHorizontalSwipe,
                  child: currentRoom != null
                      ? RoomView(room: currentRoom)
                      : const HomeView(),
                ),
              ),
              // Top chrome: hamburger / nav tabs / clock, like the
              // original — or the edit-mode banner while editing.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: AnimatedBuilder(
                      animation: _editMode,
                      builder: (context, _) => _editMode.editing
                          ? _EditModeBar(
                              roomName: currentRoom?.name ?? 'Home',
                              onDone: _editMode.exit,
                              onBackground: () => _editBackground(currentRoom),
                            )
                          : Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.menu, color: Colors.white70),
                                  onPressed: () =>
                                      _scaffoldKey.currentState?.openDrawer(),
                                ),
                                Expanded(
                                  child: Center(
                                    child: KotiTopNav(
                                      rooms: rooms,
                                      selectedRoomId: _roomId,
                                      onSelect: (room) =>
                                          setState(() => _roomId = room?.id),
                                      onScenes: () => showScenesPopup(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const ClockWidget(
                                  style: TextStyle(
                                    fontFamily: 'Hanken Grotesk',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              if (_showScreensaver && theme.screensaverTimeoutMinutes > 0)
                Positioned.fill(
                  child: ScreensaverScreen(
                      onDismiss: () => setState(() => _showScreensaver = false)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Replaces the nav bar while editing: what's being edited, a hint, a
/// background picker, and Done.
class _EditModeBar extends StatelessWidget {
  final String roomName;
  final VoidCallback onDone;
  final VoidCallback onBackground;

  const _EditModeBar({
    required this.roomName,
    required this.onDone,
    required this.onBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 0, 0, 0.45),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit, size: 18, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Editing $roomName — tap a card or badge to change it',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Background',
                  icon: const Icon(Icons.wallpaper, color: Colors.white),
                  onPressed: onBackground,
                ),
                FilledButton(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
