import 'package:flutter/material.dart';

/// The parts of the app that can be switched off in Settings.
///
/// Suite and Settings are deliberately absent. Suite is where everything
/// lands when the thing you were looking at is turned off, and Settings is
/// the only way back — switching either off would strand the person in an
/// app with no navigation.
enum ShiftFeature {
  agents('Agents', 'The agent rows, the composer and the run list.'),
  design('Design', 'The design surface and its artboards.'),
  notes('Notes', 'Notes and their inline answers.'),
  leaderboard(
    'Leaderboard',
    'The week clock, your card, the podium and the standings.',
  ),
  trophies('Trophies', 'The trophy shelf.'),
  vault('Vault', 'Everything you have made, and the Suite links into it.'),
  connectors('Connectors', 'The connections card in Settings.');

  const ShiftFeature(this.label, this.description);

  final String label;

  /// One line under the switch, so the toggle says what it takes away.
  final String description;

  static ShiftFeature? parse(String? value) {
    for (final ShiftFeature f in ShiftFeature.values) {
      if (f.name == value) return f;
    }
    // An unknown name is a feature this build does not have — a blob
    // written by a newer version, or one that was removed. Dropping it is
    // right either way; it must not disable something at random.
    return null;
  }
}

/// The four modes in the mode menu. Everything else — chat, code, stills,
/// documents, voice, music, avatars — is reachable through Suite rather than
/// getting a row of its own.
enum ShiftMode {
  suite(
    'Suite',
    Icons.auto_awesome_rounded,
    Surface.suite,
  ),
  agents(
    'Agents',
    Icons.bolt_outlined,
    Surface.agents,
    ShiftFeature.agents,
  ),
  design(
    'Design',
    Icons.draw_outlined,
    Surface.design,
    ShiftFeature.design,
  ),
  notes(
    'Notes',
    Icons.sticky_note_2_outlined,
    Surface.notes,
    ShiftFeature.notes,
  );

  const ShiftMode(this.label, this.icon, this.surface, [this.feature]);

  final String label;
  final IconData icon;

  /// Where picking this mode lands.
  final Surface surface;

  /// The switch in Settings that hides this mode, or null when it cannot
  /// be hidden.
  final ShiftFeature? feature;

  static ShiftMode parse(String? value) => ShiftMode.values.firstWhere(
        (ShiftMode m) => m.name == value,
        orElse: () => ShiftMode.suite,
      );
}

/// The top level surfaces.
enum Surface {
  suite('Create', Icons.auto_awesome_rounded),
  earnings('Leaderboard', Icons.bar_chart_rounded),
  trophies('Trophies', Icons.emoji_events_outlined),
  vault('Vault', Icons.grid_view_rounded),
  design('Design', Icons.draw_outlined),
  notes('Notes', Icons.sticky_note_2_outlined),
  agents('Agents', Icons.bolt_outlined),
  settings('Settings', Icons.settings_outlined);

  const Surface(this.label, this.icon);

  final String label;
  final IconData icon;

  /// The switch in Settings that hides this surface, or null when it is
  /// always reachable. Suite and Settings are always reachable.
  ShiftFeature? get feature => switch (this) {
        Surface.suite || Surface.settings => null,
        Surface.earnings => ShiftFeature.leaderboard,
        Surface.trophies => ShiftFeature.trophies,
        Surface.vault => ShiftFeature.vault,
        Surface.design => ShiftFeature.design,
        Surface.notes => ShiftFeature.notes,
        Surface.agents => ShiftFeature.agents,
      };

  /// What the app bar reads. Leaderboard and Trophies sit under Suite, so
  /// the bar keeps saying Suite while you are in them and the screen itself
  /// carries a back link to Create.
  String get chromeTitle => switch (this) {
        Surface.suite || Surface.earnings || Surface.trophies => 'Suite',
        _ => label,
      };

  static Surface parse(String? value) => Surface.values.firstWhere(
        (Surface s) => s.name == value,
        orElse: () => Surface.suite,
      );
}

/// The workspace group in the sidebar, in order. These three are not modes:
/// they are places the account keeps score.
const List<Surface> kWorkspaceSurfaces = <Surface>[
  Surface.earnings,
  Surface.trophies,
  Surface.vault,
];
