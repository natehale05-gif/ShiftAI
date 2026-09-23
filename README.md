# ShiftAi — Flutter client

### ▶ Live app: <https://natehale05-gif.github.io/ShiftAI/>

Deployed from `main` on every push by `.github/workflows/pages.yml`.

---

The ShiftAi product as a Flutter app: one shell, four modes, seven surfaces,
four themes, responsive from a 390px phone to a 1440px desktop.

The mode menu is **Suite, Agents, Design, Notes**. Everything else — chat,
code, stills, documents, voice, music, avatars — is reachable through Suite
rather than getting a row of its own. **Earnings, Trophies and Vault** are
not modes; they sit in the workspace group below, where the account keeps
score.

This is the demo client. Server patches `0013` and `0014` are not deployed,
so nothing here waits on a backend — every surface stands up on seeded rows
and on-device state.

## Run it

```bash
flutter pub get
flutter run -d chrome     # or macos, windows, linux, ios, android
flutter test              # 101 tests
flutter analyze           # clean
```

Built and checked against Flutter 3.35.1 / Dart 3.9.

## The layout rule

One breakpoint, at **900px** (`kSidebarBreakpoint` in `lib/app/shell.dart`).

- **Above it** the sidebar is persistent and surfaces go multi-column.
- **Below it** the same `SidebarNav` widget is served inside a `Drawer`, and
  every surface drops to one column.

Nothing else changes across the two — same widgets, same tokens, same copy.
Surfaces read their own `LayoutBuilder` constraints rather than the window,
so a panel inside a split view reflows on its own width.

## Where things are

```
lib/
  main.dart                  loads the store, then runs the app
  app/
    app.dart                 MaterialApp, theme selection, sign-in gate
    shell.dart               responsive shell, sidebar, drawer, top bar, update banner
    modes.dart               the four modes, the seven surfaces, and which
                             surface each mode lands on
  theme/
    tokens.dart              every SHIFT colour token, x3 themes, as a ThemeExtension
    type.dart                the type scale (Outfit / Manrope)
    app_theme.dart           ThemeData built from the tokens
  state/
    app_state.dart           the single store, persistence, AppScope
  models/models.dart         Creator, StandingRow, Trophy, VaultItem, Note, AgentDef, ChatMessage
  data/seed.dart             the seeded demo account
  providers/registry.dart    provider routes and key status
  features/
    chat/                    suite surface, composer, artifact card, failure card
    earnings/                clock, your card, target and chaser, podium, standings
    trophies/                the 40-trophy grid
    vault/                   scope toggle, masonry, detail panel
    notes/                   list, editor, inline answers
    agents/                  agent rows, composer, run-list placeholder
    settings/                appearance, provider keys, connections, account
    auth/                    the sign-in gate
  util/                      money and date formatting, the week clock
assets/brand/                the lockup, on dark and on light
```

## Design system

Colours, type, spacing and radii come from the ShiftAi design system and
are carried on `ThemeData` as a `ShiftColors` extension — no widget holds a
literal hex. Four themes (`dark`, `light`, `retro`, `retroLight`) define every token, so
any screen built on them switches over with no new code.

Fonts (Outfit and Manrope, both variable) are bundled in `assets/fonts/`
and declared in `pubspec.yaml`, so the app draws its own type with no
network call.

Icons are Material's rounded set rather than Material Symbols Rounded — the
shapes match closely and it avoids a font dependency. Swap in
`material_symbols_icons` if the exact axes matter.

## Persistence

| Key | Contents |
|---|---|
| `shift.app.v1` | theme, active surface and mode, earnings ledger, trophies, vault, notes |
| `shift.photoAvatar` | chosen avatar image |
| `shift-pick-image` | image picker scratch |
| `shift-backend` | backend base URL override |

Read once on mount, written back debounced at 400ms, and a key this app did
not write is never cleared. **Private chat content is never persisted** —
there is a test for it.

## What is deliberate

- **Earnings is plain.** Clock, your card, target and chaser, podium, then a
  bare list. No charts in the rows, no badges, and no 48-hour sprint pool —
  that was removed and should not come back.
- **The failure card** says a 503 is `shift.within_ceiling` being unreachable
  (migration 0011), not a verdict on the plan, and offers Settings.
- **The Agents run list is a placeholder**, clearly labelled. Nothing is
  stubbed in behind it.
- **Media tiles and connector logos are labelled placeholders.** No invented
  artwork.
- **Copy is plain and short**, no exclamation marks, no emoji.

## Next

- Wire the surfaces to `conversations` (0012), `suite_credits` (0013) and
  `weeks_and_earnings` (0015) once they are deployed.
- The agents run list.
- Keyboard shortcuts: ⌘K palette, Esc to close panels.
- True photo → video still needs the two-file edge change in
  `server-patch/README.md` (multipart passthrough plus `/v1/images/edits`).
