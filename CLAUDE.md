# ShiftAi — orientation for whoever picks this up

A Flutter creator suite: chat, vault, agents, design, notes, a weekly
leaderboard and a trophy shelf.

**The web app is live at <https://natehale05-gif.github.io/ShiftAI/>**,
redeployed from `main` on every push by `.github/workflows/pages.yml`.

Both mobile binaries now compile. They had never been built at all — this
was written in an environment with no Xcode and no Android SDK — so
`.github/workflows/release.yml` builds them on GitHub's runners, which is
where the first `pod install` and the first Gradle run actually happened.
**Neither has been signed, and neither has ever run on a device**, so the
first install of each is still unknown territory. That is the job.

In particular, R8 completing is not proof the keep rules below are
sufficient: that failure is a release-only crash on first sign-in or on
"+", never a build error.

Target: both app stores. Neither has a build yet.

## Get it building

```bash
flutter clean && flutter pub get
bash tool/preflight.sh          # everything checkable without a toolchain
cd ios && pod install && cd ..  # first run only
flutter build ipa --release
flutter build appbundle --release
```

`ios/Runner.xcworkspace` is the file Xcode opens — **not** the
`.xcodeproj`. Opening the project file gives you a build that cannot find
the pods.

`flutter build appbundle` falls back to the debug signing key until
`android/key.properties` exists. It will run on a device and Play will
refuse it. `docs/RELEASE.md` has the `keytool` line.

## Please do not undo these

Each one was a real bug found by testing, and each is easy to "clean up"
back into existence.

**The seeded catalogue must never stand in for an account.** With a base
URL configured, a failed load yields empty screens plus an error — never
`Seed`. This used to fall back to the seeded data, which showed one
person another person's vault, trophy shelf and weekly earnings labelled
as their own. `AppState.load` gates this on whether a backend is set.
`test/server_mode_test.dart` fails if it comes back.

**Trophy progress is blanked before the server's is applied.**
`Decode.trophies` starts from `Trophy.unearned()`. It used to start from
the seeded trophy, so a new account inherited the seed's earned dates —
a brand new user opened on "55 points, 4 of 18 earned". Same for
`Decode.connectors`: the catalogue is the client's, liveness is the
server's.

**The local cache is keyed to an account.** The signed-in email is
written into the `shift.app.v1` blob and the blob is refused for a
different account. Sign-out empties it. Offline, the account to match is
the one in the Keychain / Keystore session, so you open on your own
last-seen copy (`showingCached`); a failed load with no session, or a
blob naming anyone else, still gets nothing.

**`state.you` is nullable.** It used to resolve to `standings.last`,
which threw on an empty board and pointed at a stranger's row when it
did not.

**The R8 keep rules in `android/app/proguard-rules.pro` are load-bearing.**
`isMinifyEnabled` is on. Without those rules R8 strips
flutter_secure_storage and file_picker — the build succeeds, debug works,
and release crashes the first time someone signs in or taps "+".

**`ios/Runner/PrivacyInfo.xcprivacy` is in `project.pbxproj`** — file
reference, Runner group, and the Resources build phase. A manifest that
is not in Copy Bundle Resources is one Apple never sees.

**Bundle ids are `club.shiftai.app` on both platforms** and cannot change
after the first upload.

## Shape of the code

- `lib/data/repository.dart` — the seam. Every screen reads and writes
  through `ShiftRepository` and nothing else.
- `lib/data/seed_repository.dart` — in-memory; what runs with no backend.
- `lib/data/api/` — `ApiClient` is the only file that touches the
  network. 401 refreshes once, then signs out. Never loops.
- `lib/data/auth/` — tokens live in the Keychain / Keystore via
  flutter_secure_storage, never in shared_preferences.
- `lib/state/app_state.dart` — `InheritedNotifier`, no state package.
  Mutations apply optimistically and roll back, returning `bool`; every
  caller reports a refusal to the person.
- `lib/theme/tokens.dart` — four themes. **No literal hex anywhere else.**

## The server

Rex builds it. A preview is live at
`https://app.shiftai.club/app-preview/api`, and it rebuilds the web app
from this repo's `main` within about five minutes of a push. Only the
three of the team can sign in with real accounts, so it spends real
credits. `docs/API.md` is the contract: every route, shape, error
semantic, the four auth routes, and (since 23 Sept 2026) the vault's
media fields, the Suite's boards at `/v1/boards`, and several AIs in one
conversation (`/v1/models`, and `model` + `history` on `/v1/messages`).
Every earlier reply goes back as the assistant's own turn, whichever
model wrote it; that is what lets them read each other as one model.

Not wired yet: `ANY /v1/studio/<path>`, which relays to the Suite's own
`/api/studio/<path>` (chat, image, video, voice, music, deck and the
rest). Its request and response shapes are in the Suite's route files
(`shiftai-suite/app/api/studio/`), which this repo cannot see. Still
read-only on the server: rename, publish and delete in the vault,
changing username, and deleting the account.

`python3 tool/mock_engine.py` serves that whole contract with everything
empty, on 127.0.0.1:8111. Point the app at it to see exactly what a brand
new account sees. It is also the fastest way to check a real server: any
screen that differs is a place the shapes diverge.

Avatars run on `/v1/avatars` (list, create with `consent: true`, make
personal, delete), and Rex's preview still answers that route empty. The
app side is done: consent before upload, a trainable photo, a still
`previewUrl` (a video there is moved to `clipUrl`), and the gallery
re-reading every 15 s while one trains. `docs/API.md` has the rest.

`DELETE /v1/me` is store-blocking — Apple rejects account creation
without in-app deletion (Guideline 5.1.1(v)). The button and the
confirmation exist; they need something to call.

## Working in this repo

Commit as you go, one commit per fixed thing, and say in the message what
the error was — not just what you changed. The first native builds are
expected to surface problems nobody has seen yet, and six months from now
"fixed the pod install failure" is worth far less than the error text that
caused it.

Run `flutter analyze && flutter test` before each commit. If a change is
exploratory, branch.

## Before you call anything done

```bash
flutter analyze && flutter test
```

246 tests. They have caught every regression listed above at least once,
including several of mine. If one fails, read it before changing it —
twice now the test was right and my expectation was wrong.
