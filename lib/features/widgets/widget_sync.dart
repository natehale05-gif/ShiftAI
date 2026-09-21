import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';

/// Keeps the home screen widgets in sync with the leaderboard.
///
/// [AppState.you]/[AppState.podium]/[AppState.target]/[AppState.chaser]
/// are already empty or null in every case where showing them would be
/// wrong — no backend configured, signed out, or a board that has not
/// scored yet — so this writes them straight through with no gating of
/// its own. The same invariant that keeps the seeded catalogue off the
/// Leaderboard screen keeps it off the widgets.
///
/// Every call is best-effort: there is no web implementation (home screen
/// widgets are not a web concept), and a widget that fails to refresh is
/// a worse day than a crash would be, but not by much either way — this
/// must never take the data refresh it rides on down with it.
abstract final class WidgetSync {
  // Android looks up a widget by its provider class name; iOS by the
  // `kind` string the Widget itself declares. WidgetCenter.reloadTimelines
  // only reloads the one kind it is given, so these have to be the three
  // distinct identifiers, not one shared bundle name.
  static const String _rankWidget = 'RankWidgetProvider';
  static const String _rankKind = 'RankWidget';
  static const String _podiumWidget = 'PodiumWidgetProvider';
  static const String _podiumKind = 'PodiumWidget';
  static const String _rivalsWidget = 'RivalsWidgetProvider';
  static const String _rivalsKind = 'RivalsWidget';

  static const String _appGroupId = 'group.club.shiftai.app';

  static const List<String> _keys = <String>[
    'you_rank',
    'you_earnings',
    'you_movement',
    'podium_1_name',
    'podium_1_earnings',
    'podium_2_name',
    'podium_2_earnings',
    'podium_3_name',
    'podium_3_earnings',
    'target_name',
    'target_gap',
    'chaser_name',
    'chaser_gap',
  ];

  /// Call once at startup. iOS needs the App Group id to share data with
  /// the widget extension at all; Android ignores it.
  static Future<void> configure() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } on Object {
      // No widget extension wired up yet, or an unsupported platform.
    }
  }

  static Future<void> push(AppState state) async {
    if (kIsWeb) return;
    try {
      // The seeded catalogue's "You" row is not null — it is fake, but it
      // is there, same as it is on the in-app Leaderboard screen. On
      // screen that is caveated by the rest of the demo chrome around it;
      // pinned to a home screen it would just look like somebody's real
      // earnings. Never let it out.
      if (state.seededDemo) {
        await clear();
        return;
      }
      final StandingRow? you = state.you;
      if (you == null) {
        await clear();
        return;
      }

      await _set('you_rank', '${you.rank}');
      await _set('you_earnings', you.earnings.toStringAsFixed(2));
      await _set('you_movement', '${you.movement}');

      final List<StandingRow> podium = state.podium;
      for (int i = 0; i < 3; i++) {
        final StandingRow? row = i < podium.length ? podium[i] : null;
        await _set('podium_${i + 1}_name', row?.name);
        await _set(
          'podium_${i + 1}_earnings',
          row?.earnings.toStringAsFixed(2),
        );
      }

      await _setRival('target', state.target, you.earnings, ahead: true);
      await _setRival('chaser', state.chaser, you.earnings, ahead: false);

      await _refreshWidgets();
    } on Object {
      // Best-effort, per the class doc — a stale widget is not worth
      // surfacing to the person as an error.
    }
  }

  static Future<void> clear() async {
    if (kIsWeb) return;
    try {
      for (final String key in _keys) {
        await _set(key, null);
      }
      await _refreshWidgets();
    } on Object {
      // As above.
    }
  }

  static Future<void> _setRival(
    String prefix,
    StandingRow? rival,
    double yourEarnings, {
    required bool ahead,
  }) async {
    if (rival == null) {
      await _set('${prefix}_name', null);
      await _set('${prefix}_gap', null);
      return;
    }
    final double gap = ahead
        ? rival.earnings - yourEarnings
        : yourEarnings - rival.earnings;
    await _set('${prefix}_name', rival.name);
    await _set('${prefix}_gap', gap.toStringAsFixed(2));
  }

  static Future<void> _set(String key, String? value) =>
      HomeWidget.saveWidgetData<String>(key, value);

  static Future<void> _refreshWidgets() async {
    await HomeWidget.updateWidget(iOSName: _rankKind, androidName: _rankWidget);
    await HomeWidget.updateWidget(
      iOSName: _podiumKind,
      androidName: _podiumWidget,
    );
    await HomeWidget.updateWidget(
      iOSName: _rivalsKind,
      androidName: _rivalsWidget,
    );
  }
}
