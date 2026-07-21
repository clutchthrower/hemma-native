import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Purely local, never-leaves-the-device usage counters, shown on the App
/// Info settings page. Explicitly NOT third-party telemetry — nothing here
/// is ever sent anywhere, so there's no account/SDK/privacy tradeoff to
/// make, unlike real analytics (which would need a third-party service and,
/// since this app is open source, would mean every person who builds it
/// reporting to whoever's API key ships in the repo). Always on, no
/// enable/disable toggle — it's just counters, not a decision worth a
/// setting.
class LocalStatsStore extends ChangeNotifier {
  static const _kLaunchCount = 'koti_stats_launch_count';
  static const _kFirstLaunch = 'koti_stats_first_launch';

  int launchCount = 0;
  DateTime? firstLaunch;

  int get daysSinceInstall =>
      firstLaunch == null ? 0 : DateTime.now().difference(firstLaunch!).inDays;

  /// Loads existing counters and records this launch — call once per cold
  /// start.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    launchCount = (prefs.getInt(_kLaunchCount) ?? 0) + 1;
    await prefs.setInt(_kLaunchCount, launchCount);

    final firstLaunchMillis = prefs.getInt(_kFirstLaunch);
    if (firstLaunchMillis == null) {
      firstLaunch = DateTime.now();
      await prefs.setInt(_kFirstLaunch, firstLaunch!.millisecondsSinceEpoch);
    } else {
      firstLaunch = DateTime.fromMillisecondsSinceEpoch(firstLaunchMillis);
    }
    notifyListeners();
  }
}
