import 'package:flutter/material.dart';

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
  ),
  design(
    'Design',
    Icons.draw_outlined,
    Surface.design,
  ),
  notes(
    'Notes',
    Icons.sticky_note_2_outlined,
    Surface.notes,
  );

  const ShiftMode(this.label, this.icon, this.surface);

  final String label;
  final IconData icon;

  /// Where picking this mode lands.
  final Surface surface;

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
