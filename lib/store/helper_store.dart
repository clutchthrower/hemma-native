import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state_store.dart';
import '../utils/sun_phase.dart';

enum ExpandedRow { none, climate, presence, media, lights }

enum ThermostatMode { cool, heat }

/// Local replacement for `packages/hemma_helpers.yaml`. Every `input_*`
/// helper entity and its automations from the original HA package is
/// reimplemented here as plain app state, since this app has no HA backend
/// of its own to host them.
class HelperStore extends ChangeNotifier {
  final StateStore stateStore;
  static const _prefsPrefix = 'koti_helper_';

  HelperStore({required this.stateStore}) {
    stateStore.addListener(_onStateStoreChanged);
  }

  bool thermostatOverlay = false;
  bool mobileNavigation = false;
  bool lockOverlay = false;
  bool motionBadges = true;
  bool restartConfirm1 = false;
  bool restartConfirm2 = false;
  bool restartDone1 = false;
  bool restartDone2 = false;

  ExpandedRow expandedRow = ExpandedRow.none;
  double thermostatTargetTemp = 72;
  ThermostatMode thermostatMode = ThermostatMode.cool;
  Map<String, String> motionSensors = {};

  String dynamicBackgroundFile = 'mobile-day.jpg';

  DateTime? _lastThermostatToggle;
  Timer? _restartDone1Timer;
  Timer? _restartDone2Timer;

  Future<void> init() async {
    await _load();
    _recomputeDynamicBackground();
  }

  void _onStateStoreChanged() {
    _recomputeDynamicBackground();
    _maybeAutoExpandMedia();
  }

  void _recomputeDynamicBackground() {
    final sun = stateStore.get('sun.sun');
    if (sun == null) return;
    final elevation = sun.attrDouble('elevation') ?? 0;
    final rising = sun.attr<bool>('rising', true);
    final belowHorizon = sun.state == 'below_horizon';
    final file = computeDynamicBackgroundFile(
      elevation: elevation,
      rising: rising,
      belowHorizon: belowHorizon,
    );
    if (file != dynamicBackgroundFile) {
      dynamicBackgroundFile = file;
      notifyListeners();
    }
  }

  void _maybeAutoExpandMedia() {
    if (expandedRow != ExpandedRow.none) return;
    final playing = stateStore.all.values.any((e) =>
        e.domain == 'media_player' &&
        (e.state == 'playing' || e.state == 'buffering'));
    if (playing) {
      expandedRow = ExpandedRow.media;
      notifyListeners();
    }
  }

  void toggleExpandedRow(ExpandedRow row) {
    expandedRow = expandedRow == row ? ExpandedRow.none : row;
    notifyListeners();
  }

  /// Debounced 400ms/single-mode toggle, matching the original
  /// `hemma_thermostat_overlay_toggle` script's cooldown.
  void toggleThermostatOverlay() {
    final now = DateTime.now();
    if (_lastThermostatToggle != null &&
        now.difference(_lastThermostatToggle!) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastThermostatToggle = now;
    thermostatOverlay = !thermostatOverlay;
    notifyListeners();
  }

  void toggleLockOverlay() {
    lockOverlay = !lockOverlay;
    notifyListeners();
  }

  void toggleMobileNavigation() {
    mobileNavigation = !mobileNavigation;
    notifyListeners();
  }

  void setMotionBadges(bool value) {
    motionBadges = value;
    notifyListeners();
    _save();
  }

  void setThermostatTargetTemp(double value) {
    thermostatTargetTemp = value;
    notifyListeners();
    _save();
  }

  void setThermostatMode(ThermostatMode mode) {
    thermostatMode = mode;
    notifyListeners();
    _save();
  }

  /// Replicates the network-restart 3-state machine per device:
  /// idle -> confirm -> done(3s) -> idle. Never allows a restart service
  /// call outside of the confirm step.
  Future<void> handleRestartTap(
    int slot,
    Future<void> Function() restartAction,
  ) async {
    final confirmed = slot == 1 ? restartConfirm1 : restartConfirm2;
    if (!confirmed) {
      if (slot == 1) {
        restartConfirm1 = true;
      } else {
        restartConfirm2 = true;
      }
      notifyListeners();
      return;
    }

    if (slot == 1) {
      restartConfirm1 = false;
      restartDone1 = true;
    } else {
      restartConfirm2 = false;
      restartDone2 = true;
    }
    notifyListeners();
    await restartAction();

    if (slot == 1) {
      _restartDone1Timer?.cancel();
      _restartDone1Timer = Timer(const Duration(seconds: 3), () {
        restartDone1 = false;
        notifyListeners();
      });
    } else {
      _restartDone2Timer?.cancel();
      _restartDone2Timer = Timer(const Duration(seconds: 3), () {
        restartDone2 = false;
        notifyListeners();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefsPrefix}motionBadges', motionBadges);
    await prefs.setDouble('${_prefsPrefix}thermostatTargetTemp', thermostatTargetTemp);
    await prefs.setString('${_prefsPrefix}thermostatMode', thermostatMode.name);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    motionBadges = prefs.getBool('${_prefsPrefix}motionBadges') ?? true;
    thermostatTargetTemp =
        prefs.getDouble('${_prefsPrefix}thermostatTargetTemp') ?? 72;
    final modeStr = prefs.getString('${_prefsPrefix}thermostatMode');
    thermostatMode = ThermostatMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => ThermostatMode.cool,
    );
  }

  @override
  void dispose() {
    _restartDone1Timer?.cancel();
    _restartDone2Timer?.cancel();
    stateStore.removeListener(_onStateStoreChanged);
    super.dispose();
  }
}
