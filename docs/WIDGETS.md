# Home screen widgets

Three widgets, same data, two platforms: your rank and this week's
earnings (small), the top 3 (medium), and who you're catching / who's
catching you (medium). `lib/features/widgets/widget_sync.dart` is the one
place that decides what they show — it writes flat string keys into
platform-shared storage (`SharedPreferences` on Android, `UserDefaults`
in the `group.club.shiftai.app` App Group on iOS) via the `home_widget`
package, then tells each widget to redraw.

There is no periodic OS-driven refresh on either platform
(`updatePeriodMillis="0"` in each Android `*_widget_info.xml`; each iOS
`TimelineProvider` returns a single entry with `policy: .never`). A widget
updates when the app does — on load, on refresh, on sign-in — the same
moments `AppState` already reads the engine. There is no background sync;
building one is future work, not a gap in what shipped here.

## The rule that matters more than any of this

**`WidgetSync.push` refuses to run in seeded/demo mode**, even though
`AppState.you` is not null there — the seed catalogue has a "You" row at
rank 13, same as the in-app Leaderboard screen. On screen that is
caveated by the rest of the demo chrome around it. Pinned to a home
screen, unmoving, it would just look like somebody's real earnings — the
exact leak `CLAUDE.md`'s "the seeded catalogue must never stand in for an
account" rule exists to prevent, just on a surface that rule was written
before this feature existed to cover. If you touch this file, keep that
gate; `test/widget_sync_test.dart` fails if it goes missing.

## Android — done, nothing left to do

Three `AppWidgetProvider` subclasses
(`android/.../{Rank,Podium,Rivals}WidgetProvider.kt`), three layouts,
three `AppWidgetProviderInfo` XML files, three `<receiver>` entries in
`AndroidManifest.xml`. Colors are `android/app/src/main/res/values/colors.xml`'s
`widget_*` set — ShiftColors.retro's values, hand-copied, because a
native widget cannot follow an in-app theme switch. `home_widget`'s R8
keep rule lives in `android/app/proguard-rules.pro`; `tool/preflight.sh`
checks it stays there the same way it already checks for
flutter_secure_storage and file_picker.

## iOS — the extension needs one manual step in Xcode

Everything the extension needs is written and sitting in
`ios/ShiftLeaderboardWidgets/`: the three `Widget`s, the shared
`TimelineProvider`, `Info.plist`, and its own entitlements file. What is
**not** done, and cannot safely be done by hand-editing
`project.pbxproj`, is wiring that folder up as an actual Xcode target —
adding a whole new `PBXNativeTarget` with its build phases, product
reference, and embed-extension step by splicing raw text into that file
is exactly the kind of edit that can silently produce a project Xcode
refuses to open, with no way to check the result short of opening Xcode
itself. `ios/Runner.xcodeproj/project.pbxproj` already carries one
hand-added entry for this feature — `Runner.entitlements`, wired onto
the existing Runner target's three build configurations — because that
was adding one key to an object already known to be well-formed, a very
different risk than fabricating a new one from scratch.

So: open `ios/Runner.xcworkspace` (not the `.xcodeproj` — same rule as
everywhere else in this repo) and do this once.

1. **File → New → Target… → Widget Extension.**
2. Name it `ShiftLeaderboardWidgets`. Uncheck "Include Configuration
   Intent" (these are static, no user configuration). Uncheck "Include
   Live Activity".
3. Xcode generates a starter Swift file and its own `Info.plist` —
   **delete the generated `.swift` file and `Info.plist`**, then drag
   every file already in `ios/ShiftLeaderboardWidgets/` into the new
   target's group in the project navigator (make sure "Copy items if
   needed" is off — they are already in the right place — and that the
   new target's membership checkbox is on for each).
4. Select the `ShiftLeaderboardWidgets` target → **Signing & Capabilities**
   → **+ Capability → App Groups** → add `group.club.shiftai.app` (the
   same group Runner already has). This should write to the
   `ShiftLeaderboardWidgets.entitlements` file already sitting in that
   folder — if Xcode instead creates a second one, delete the duplicate
   and point the target at the one in the repo.
5. Still on that target's **Build Settings**: set **iOS Deployment
   Target** to at least 17.0 if you want the widgets themselves fully
   themed (`containerBackground` needs it — see `WidgetTheme.swift`'s
   `widgetBackground` for the iOS 14–16 fallback if you'd rather keep
   the target's minimum lower and accept the system's default widget
   chrome on older versions instead).
6. Build the `Runner` scheme once. Xcode should have added the new
   target as a dependency of Runner and an "Embed Foundation Extensions"
   build phase automatically as part of step 1 — if the widgets do not
   show up in the "Add Widget" picker on a device or simulator after a
   clean install, check that phase exists on the Runner target.
7. Commit the resulting `project.pbxproj` changes. From that point on
   they are ordinary, Xcode-generated, and safe for anyone (including a
   future session with no Xcode) to diff and reason about — the
   hand-editing concern above only applies to *creating* the target, not
   to maintaining it afterward.

## Testing without either platform

`tool/mock_engine.py` and `SeedRepository` do not need anything extra —
`WidgetSync` reads `AppState.you`/`podium`/`target`/`chaser`, which
already reflect whatever the engine (real or mock) answered. There is
nothing to click to "test" a widget outside of an actual device or
simulator home screen; `test/widget_sync_test.dart` is what stands in
for that here, checking the data that would reach one rather than its
rendering.
