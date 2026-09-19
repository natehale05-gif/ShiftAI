import 'package:flutter/material.dart';

import '../features/agents/agents_surface.dart';
import '../features/chat/suite_surface.dart';
import '../features/design/design_surface.dart';
import '../features/earnings/leaderboard_surface.dart';
import '../features/notes/notes_surface.dart';
import '../features/settings/avatar.dart';
import '../features/settings/settings_surface.dart';
import '../features/trophies/trophies_surface.dart';
import '../features/vault/vault_surface.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';
import '../widgets/common.dart';
import 'modes.dart';

/// Below this the sidebar is a drawer; above it, a panel that the hamburger
/// slides in and out. Either way the hamburger is the only control, and the
/// content stays in one centred column.
const double kSidebarBreakpoint = 900;
const double kSidebarWidth = 260;

/// Every screen holds its content to this width and centres it.
const double kContentWidth = 950;

class ShiftShell extends StatelessWidget {
  const ShiftShell({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= kSidebarBreakpoint;
        final bool railOpen = wide && !state.sidebarCollapsed;

        return Scaffold(
          drawer: wide
              ? null
              : const Drawer(width: 306, child: SidebarNav(inDrawer: true)),
          // With the rail open the sidebar owns the left edge from the very
          // top of the window: one colour, top to bottom, with the hamburger
          // and the screen name sitting inside it.
          body: Row(
            children: <Widget>[
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: railOpen ? 1 : 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double t, Widget? child) {
                  if (t == 0) return const SizedBox.shrink();
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: t,
                      child: child,
                    ),
                  );
                },
                child: Row(
                  children: <Widget>[
                    const SizedBox(
                      width: kSidebarWidth,
                      child: SidebarNav(showChrome: true),
                    ),
                    VerticalDivider(width: 1, color: c.border),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    ShiftAppBar(showMenu: !railOpen),
                    if (state.updateBannerVisible) const _UpdateBanner(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder:
                            (Widget child, Animation<double> anim) {
                          return FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.012),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey<Surface>(state.surface),
                          child: _SurfaceBody(surface: state.surface),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The bar over the content. When the rail is open it carries only the
/// lockup and the ghost — the hamburger and the screen name live in the
/// sidebar, so the sidebar can run to the top of the window unbroken.
class ShiftAppBar extends StatelessWidget {
  const ShiftAppBar({this.showMenu = true, super.key});

  /// False while the rail is open, because the sidebar has the hamburger.
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool wide = screenWidth >= kSidebarBreakpoint;

    // The logo is centred, so the title only has the room left of it. Past
    // that it would run under the wordmark, which is worse than no title.
    const double logoHalfWidth = 82.4;
    final double roomForTitle = screenWidth / 2 - logoHalfWidth - Space.x4 - 52;
    final bool chatScreen = state.surface == Surface.suite ||
        state.surface == Surface.earnings ||
        state.surface == Surface.trophies;

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 60,
        child: Stack(
          children: <Widget>[
            const Center(child: ShiftLogo(height: 20)),
            Row(
              children: <Widget>[
                const SizedBox(width: Space.x2),
                if (showMenu)
                  Builder(
                    builder: (BuildContext context) => IconButton(
                      tooltip: wide ? 'Open the sidebar' : 'Open navigation',
                      onPressed: () {
                        if (wide) {
                          state.toggleSidebar();
                        } else {
                          Scaffold.of(context).openDrawer();
                        }
                      },
                      icon: Icon(Icons.menu_rounded, color: c.text, size: 22),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                  ),
                if (showMenu && roomForTitle >= 56)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: roomForTitle),
                    child: Text(
                      state.surface.chromeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShiftType.bodySm(c.text).copyWith(fontSize: 16),
                    ),
                  ),
                const Spacer(),
                if (chatScreen)
                  IconButton(
                    tooltip: state.privateChat
                        ? 'Turn off private chat'
                        : 'Turn on private chat',
                    onPressed: state.togglePrivateChat,
                    icon: GhostMark(
                      color: state.privateChat ? c.accent : c.textMuted,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                  ),
                const SizedBox(width: Space.x2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceBody extends StatelessWidget {
  const _SurfaceBody({required this.surface});

  final Surface surface;

  @override
  Widget build(BuildContext context) {
    return switch (surface) {
      Surface.suite => const SuiteSurface(),
      Surface.earnings => const LeaderboardSurface(),
      Surface.trophies => const TrophiesSurface(),
      Surface.vault => const VaultSurface(),
      Surface.design => const DesignSurface(),
      Surface.notes => const NotesSurface(),
      Surface.agents => const AgentsSurface(),
      Surface.settings => const SettingsSurface(),
    };
  }
}

/// The sidebar, and the same widget again inside the drawer on a phone.
class SidebarNav extends StatelessWidget {
  const SidebarNav({this.inDrawer = false, this.showChrome = false, super.key});

  final bool inDrawer;

  /// True when the sidebar runs to the top of the window and carries the
  /// hamburger and the screen name itself.
  final bool showChrome;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final double rowHeight = inDrawer ? 44 : 38;

    void go(VoidCallback action) {
      action();
      if (inDrawer) Navigator.of(context).maybePop();
    }

    return Container(
      // One flat colour, edge to edge and top to bottom: the rail is a
      // single panel, not a strip sitting under a bar.
      color: c.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showChrome)
              SizedBox(
                height: 60,
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: Space.x2),
                    IconButton(
                      tooltip: 'Close the sidebar',
                      onPressed: state.toggleSidebar,
                      icon: Icon(Icons.menu_rounded, color: c.text, size: 22),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        state.surface.chromeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShiftType.bodySm(c.text).copyWith(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: Space.x3),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                Space.x4,
                showChrome ? Space.x2 : Space.x5,
                Space.x4,
                Space.x4,
              ),
              child: FilledButton.icon(
                onPressed: () => go(() {
                  state.clearThread();
                  state.setMode(ShiftMode.suite);
                }),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('NEW CHAT'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                  minimumSize: const Size.fromHeight(46),
                  shape: const RoundedRectangleBorder(
                    borderRadius: Radii.pillAll,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.x3,
                  0,
                  Space.x3,
                  Space.x3,
                ),
                children: <Widget>[
                  const _GroupLabel('Modes'),
                  ...ShiftMode.values.map(
                    (ShiftMode mode) => _NavRow(
                      icon: mode.icon,
                      label: mode.label,
                      height: rowHeight,
                      active:
                          state.surface == mode.surface && state.mode == mode,
                      onTap: () => go(() => state.setMode(mode)),
                    ),
                  ),
                  const _GroupLabel('Workspace', spaced: true),
                  ...kWorkspaceSurfaces.map(
                    (Surface surface) => _NavRow(
                      icon: surface.icon,
                      label: surface.label,
                      height: rowHeight,
                      active: state.surface == surface,
                      trailing: surface == Surface.earnings && state.you != null
                          ? _RankBadge(rank: state.you!.rank)
                          : null,
                      onTap: () => go(() => state.setSurface(surface)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x4,
                Space.x3,
                Space.x4,
                Space.x4,
              ),
              child: _AccountRow(
                onTap: () => go(() => state.setSurface(Surface.settings)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "#13" as a quiet pill rather than loose text, so it sits on the row
/// instead of floating next to it.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 2),
      decoration: BoxDecoration(
        color: c.sky.withValues(alpha: 0.14),
        borderRadius: Radii.pillAll,
      ),
      child: Text('#$rank', style: ShiftType.mono(c.sky, size: 11)),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.spaced = false});

  final String text;

  /// A hairline above the second group, so Modes and Workspace read as two
  /// things rather than one long list with a gap in it.
  final bool spaced;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (spaced) ...<Widget>[
          const SizedBox(height: Space.x4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x3),
            child: Divider(height: 1, thickness: 1, color: c.border),
          ),
          const SizedBox(height: Space.x4),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.x3, 0, Space.x3, Space.x2),
          child: Eyebrow(text),
        ),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.height,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final Color fg = active ? c.accent : c.textMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Semantics(
        selected: active,
        button: true,
        child: InkWell(
          borderRadius: Radii.pillAll,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: height,
            padding: const EdgeInsets.only(right: Space.x3),
            decoration: BoxDecoration(
              color: active ? c.accentSoft : Colors.transparent,
              borderRadius: Radii.pillAll,
            ),
            child: Row(
              children: <Widget>[
                // The marker on the left is what tells you where you are at
                // a glance, before you read a single label.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 3,
                  height: active ? height - 14 : 0,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: Radii.pillAll,
                  ),
                ),
                const SizedBox(width: Space.x3 - 3),
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ShiftType.bodySm(fg).copyWith(
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    return InkWell(
      borderRadius: Radii.pillAll,
      onTap: onTap,
      child: Container(
        height: 60,
        padding: const EdgeInsets.fromLTRB(Space.x2, 0, Space.x3, 0),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: Radii.pillAll,
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: <Widget>[
            ShiftAvatar(
              photo: state.avatar,
              initials: state.creator.initials,
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    state.creator.name,
                    style: ShiftType.bodyStrong(c.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Membership',
                    style: ShiftType.caption(c.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x5,
        vertical: Space.x2,
      ),
      decoration: BoxDecoration(
        color: c.accentSoft,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: <Widget>[
          Text('UPDATE', style: ShiftType.labelSm(c.accent)),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Text(
              'Version 1.4 is ready. Restart to pick up the new voice models.',
              style: ShiftType.bodySm(c.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: state.dismissUpdateBanner,
            child: Text('Restart', style: ShiftType.bodySm(c.accent)),
          ),
          IconButton(
            tooltip: 'Dismiss update notice',
            onPressed: state.dismissUpdateBanner,
            icon: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
